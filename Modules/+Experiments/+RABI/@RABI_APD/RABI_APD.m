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