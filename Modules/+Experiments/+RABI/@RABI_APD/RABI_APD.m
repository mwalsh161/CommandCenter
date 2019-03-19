classdef RABI_APD <  Experiments.RABI.RABI_invisible
    
    properties (SetObservable)
        APD_PB_line = 3; %indexed from 1
        disp_mode = {'verbose','fast'};
    end
    
    properties
        f  %data figure that you stream to
        prefs = {'CW_freq','RF_power','nAverages','Integration_time'...
            ,'laser_read_time','start_time','stop_time','number_points'...
            'time_step_size','APD_PB_line','disp_mode','reInitializationTime','padding'}
    end
    
    methods(Access=private)
        function obj = RABI_APD
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.RABI.RABI_APD();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
        
        function [s,n_MW_on] = setup_PB_sequence(obj)
            
            Integration_time = obj.Integration_time*1e6;
            laser_read_time = obj.laser_read_time; %in ns
            MW_on_time = obj.MW_on_time;
            deadTime = 1*100;
            
            if strcmp(obj.disp_mode,'verbose')
                nSamples = round(Integration_time/laser_read_time);
            elseif strcmp(obj.disp_mode,'fast')
                nSamples = round(obj.nAverages*Integration_time/laser_read_time);
            else
                error('Unrecognized display mode type.')
            end
            
            % get hw lines for different pieces of equipment(indexed from
            % 0)
            
            [laser_hw,APD_hw,MW_switch_hw] = obj.determine_PB_hardware_handles(); %get the pulsblaster hardware handles
            
            % Make some chanels
            cLaser = channel('laser','color','g','hardware',laser_hw);
            cAPDgate = channel('APDgate','color','b','hardware',APD_hw,'counter','APD1');
            cMWswitch = channel('MWswitch','color','k','hardware',MW_switch_hw');
            
            %% check offsets are smaller than padding, errors could result otherwise
            
            assert(cLaser.offset(1) < obj.padding,'Laser offset is smaller than padding');
            assert(cAPDgate.offset(1) < obj.padding,'cAPDgate offset is smaller than padding')
            assert(cMWswitch.offset(1) < obj.padding,'cMWswitch offset is smaller than padding')

            %% 
            
            
            % Make sequence
            s = sequence('RABI_sequence');
            s.channelOrder = [cLaser,cAPDgate,cMWswitch];
            
            % make outer loop to compensate for limit on sequence.repeat
            out_loop = 'out_loop';
            out_val = 1; %temporary placeholder
            n_init_out_loop = node(s.StartNode,out_loop,'type','start');
            
            % MW gate duration
            n_MW = node(s.StartNode,cMWswitch,'delta',deadTime,'units','ns');
            n_MW_on = node(n_MW,cMWswitch,'delta',MW_on_time,'units','ns');
            
            % Laser duration:data
            n_Laser = node(n_MW_on,cLaser,'delta',obj.padding,'units','ns');
            n_Laser = node(n_Laser,cLaser,'delta',obj.reInitializationTime,'units','ns');
            
            % APD gate duration:data
            n_APD = node(n_MW_on,cAPDgate,'delta',obj.padding,'units','ns');
            n_APD = node(n_APD,cAPDgate,'delta',laser_read_time,'units','ns');
            
           
            % APD gate duration:norm
            n_APD = node(n_Laser,cAPDgate,'delta',obj.padding,'units','ns');
            n_APD = node(n_APD,cAPDgate,'delta',laser_read_time,'units','ns');
            
            % Laser duration:norm
            n_Laser = node(n_Laser,cLaser,'delta',obj.padding,'units','ns');
            n_Laser = node(n_Laser,cLaser,'delta',obj.reInitializationTime,'units','ns');
            
            % End outer loop and calculate repetitions
            n_end_out_loop = node(n_Laser,out_val,'delta',deadTime,'type','end');
            max_reps = 2^20-1;
            if nSamples > max_reps
                % loop to find nearest divisor
                while mod(nSamples,max_reps) > 0
                    max_reps = max_reps - 1;
                end
                n_end_out_loop.data = nSamples/max_reps;
                s.repeat = max_reps;
            else
                s.repeat = nSamples;
            end
        end
        
        function [laser_hw,APD_hw,MW_switch_hw] = determine_PB_hardware_handles(obj)
            laser_hw = obj.Laser.PBline-1;
            
            APD_hw = obj.APD_PB_line-1;
            
            MW_switch_hw = obj.RF.MW_switch_PB_line-1;
        end
        
        function initialize_data_acquisition_device(obj,~)
            obj.Ni = Drivers.NIDAQ.dev.instance('Dev1');
            obj.Ni.ClearAllTasks;
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
        end
        
    end
    methods
        
        function plot_data(obj)
            time_list = obj.determine_time_list();
            errorbar(time_list,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax);
            xlim(obj.ax,time_list([1,end]));
            xlabel(obj.ax,'Microwave on Time (ns)')
            ylabel(obj.ax,'Normalized Fluorescence')
        end
        
        function start_experiment(obj,statusH,managers,ax)
            nAverages = obj.nAverages;
            if strcmp(obj.disp_mode,'fast')
                nAverages = 1; %if in fast mode, averages already included in pulse sequence
            end
            
            time_list = obj.determine_time_list;
            obj.data.time_list = time_list;
            obj.data.raw_data = nan(obj.number_points,nAverages);
            obj.data.raw_var = nan(obj.number_points,nAverages);
            obj.data.norm_data = nan(obj.number_points,nAverages);
            obj.data.norm_var = nan(obj.number_points,nAverages);
            obj.data.contrast_vector = nan(obj.number_points,1);
            obj.data.error_vector = nan(obj.number_points,1);
            
            obj.f = figure('visible','off','name',mfilename);
            a = axes('Parent',obj.f);
            dataObj = plot(NaN,NaN,'Parent',a);
            
            obj.RF.on; %turn MW on
            for cur_ave = 1:nAverages
                for tau = 1:obj.number_points
                    
                    obj.MW_on_time = time_list(tau);
                    [obj.sequence] = obj.setup_PB_sequence();
                    
                    APDpseq = APDPulseSequence(obj.Ni,obj.pulseblaster,obj.sequence);
                    
                    assert(~obj.abort_request,'User aborted');
                    
                    APDpseq.start(1e4);
                    APDpseq.stream(dataObj)
                    
                    obj.data.raw_data(tau,cur_ave) = squeeze(mean(dataObj.YData(1:2:end)));
                    obj.data.raw_var(tau,cur_ave) = squeeze(var(dataObj.YData(1:2:end)));
                    obj.data.norm_data(tau,cur_ave) = squeeze(mean(dataObj.YData(2:2:end)));
                    obj.data.norm_var(tau,cur_ave) = squeeze(var(dataObj.YData(2:2:end)));
                    num_data_bins = length(dataObj.YData)/2;
                    
                    %transient calculations for current tau to get
                    %contrast and error
                    raw_data_total = squeeze(nanmean(obj.data.raw_data(tau,:)));
                    raw_err_total = sqrt(squeeze(nanmean(obj.data.raw_var(tau,:)))/(cur_ave*num_data_bins));
                    norm_data_total = squeeze(nanmean(obj.data.norm_data(tau,:)));
                    norm_err_total = sqrt(squeeze(nanmean(obj.data.norm_data(tau,:)))/(cur_ave*num_data_bins));
                    
                    obj.data.contrast_vector(tau) = raw_data_total./norm_data_total;
                    obj.data.error_vector(tau) = obj.data.contrast_vector(tau)*...
                        sqrt((raw_err_total/raw_data_total)^2+(norm_err_total/norm_data_total)^2);
                    
                    obj.plot_data
                    if strcmp(obj.disp_mode,'fast')
                        title(obj.ax,sprintf('Rabi'))
                    else
                        title(obj.ax,sprintf('Performing Average %i of %i',cur_ave,obj.nAverages))
                    end
                end
            end
            obj.RF.off %turn MW on
            delete(obj.f);
        end
        
        function abort(obj)
            delete(obj.f);
            obj.Ni.ClearAllTasks;
            abort@Experiments.RABI.RABI_invisible(obj);
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.APDcounts = obj.data;
                GetData@Experiments.RABI.RABI_invisible(obj);
            else
                data = [];
            end
        end
    end
end