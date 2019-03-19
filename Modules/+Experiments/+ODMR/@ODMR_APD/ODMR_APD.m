classdef ODMR_APD <  Experiments.ODMR.ODMR_invisible
    
    properties
        f%figure handle that we stream data to.
        readout_time;
        prefs={'RF_power','nAverages','start_freq','stop_freq','number_points','freq_step_size',...
            'dummy_pb_line','meas_time_ms','APD_PB_line','trig_type',...
            'disp_mode','waitTimeSGswitch_us'}
    end
    
    properties(SetObservable)
        meas_time_ms = 10;
        APD_PB_line = 3;
        trig_type = {'PulseBlaster'};
        disp_mode = {'verbose','fast'};
    end
    
    methods(Access=private)
        function obj = ODMR_APD()
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.ODMR.ODMR_APD();
            end
            obj = Object;
            obj.loadPrefs;
            
        end
    end
    
    methods(Access=protected)
        
        function freq_list = determine_freq_list(obj)
            start_freq = obj.start_freq;
            stop_freq = obj.stop_freq;
            freq_list = linspace(start_freq,stop_freq,obj.number_points);
        end
        
        function plot_data(obj)
            freq_list = (obj.determine_freq_list)*10^-9; %frequencies in GHz
            errorbar(freq_list,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax)
            xlim(obj.ax,freq_list([1,end]));
            xlabel(obj.ax,'Microwave Frequency (GHz)')
            ylabel(obj.ax,'Normalized Fluorescence')
        end
        
        function s=setup_PB_sequence(obj)
            meas_time = obj.meas_time_ms*1e6; %in ns (from milliseconds)
            deadTime = 2*1000; %in ns
            waitTimeSGswitch = obj.waitTimeSGswitch_us*1000; %in ns
            delayTime = 1*1000; %in ns
            obj.readout_time = 300*1000 ; %in ns
            switch obj.disp_mode
                %verbose (continual display) or fast (occasional display)
                case 'verbose'
                    nsamples = round(meas_time/obj.readout_time);
                case 'fast'
                    nsamples = round(obj.nAverages*meas_time/obj.readout_time);
                otherwise
                    error('Unrecognized display mode type.')
            end
            
            [laser_hw,APD_hw,MW_switch_hw,SG_trig_hw,dummy_pb_line] = obj.determine_PB_hardware_handles(); %get the pulsblaster hardware handles
            
            % Make some chanels
            claser = channel('laser','color','r','hardware',laser_hw);
            cAPDgate = channel('APDgate','color','g','hardware',APD_hw,'counter','APD1');
            cMWswitch = channel('MWswitch','color','b','hardware',MW_switch_hw);
            cSGtrig = channel('SGtrig','color','k','hardware',SG_trig_hw);
            cdummy = channel('xxx','color','y','hardware',dummy_pb_line);
            
            % Make sequence
            s = sequence('ODMR_sequence');
            s.channelOrder = [claser,cAPDgate,cMWswitch,cSGtrig,cdummy];
            
            %start freq list loop
            nloop_EXP = node(s.StartNode,'Freq list loop','type','start','delta',1,'units','us');
            
            % laser duration
            n_laser = node(nloop_EXP,claser,'delta',0,'units','ns');
            n_laser = node(n_laser,claser,'delta',obj.readout_time,'units','ns');
            n_laser = node(n_laser,claser,'delta',deadTime,'units','ns');
            n_laser = node(n_laser,claser,'delta',obj.readout_time,'units','ns');
            
            % APD gate duration
            n_APD = node(nloop_EXP,cAPDgate,'delta',0,'units','ns');
            n_APD = node(n_APD,cAPDgate,'delta',obj.readout_time,'units','ns');
            n_APD = node(n_APD,cAPDgate,'delta',deadTime,'units','ns');
            n_APD = node(n_APD,cAPDgate,'delta',obj.readout_time,'units','ns');
            
            % MW gate duration
            n_MW = node(nloop_EXP,cMWswitch,'delta',0,'units','ns');
            n_MW = node(n_MW,cMWswitch,'delta',obj.readout_time,'units','ns');
            
            % Loop
            nloop_EXP = node(n_laser,nsamples,'type','end','delta',1,'units','us');
            n_dummy   = node(nloop_EXP,cdummy,'delta',0,'units','ns');
            n_dummy   = node(n_dummy,cdummy,'delta',1000,'units','ns');
            
            % Signal Generator Trigger
            n_sigtrig_begin = node(nloop_EXP,cSGtrig,'delta',delayTime,'units','ns');
            n_sigtrig = node(n_sigtrig_begin,cSGtrig,'delta',waitTimeSGswitch,'units','ns');
        end
        
        function [laser_hw,APD_hw,MW_switch_hw,SG_trig_hw,dummy_pb_line] = determine_PB_hardware_handles(obj)
            laser_hw = obj.laser.PBline-1;
            
            APD_hw = obj.APD_PB_line-1;
            
            MW_switch_hw = obj.RF.MW_switch_PB_line-1;
            
            SG_trig_hw = obj.RF.SG_trig_PB_line-1;
            
            dummy_pb_line=obj.dummy_pb_line-1;
        end
        
        function initialize_data_acquisition_device(obj,~)
            obj.Ni = Drivers.NIDAQ.dev.instance('Dev1');
            obj.Ni.ClearAllTasks;
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
        end
    end
    
    methods
        
        function abort(obj)
            delete(obj.f);
            obj.Ni.ClearAllTasks;
            abort@Experiments.ODMR.ODMR_invisible(obj)
        end
        
        function start_experiment_CW(obj,statusH,managers,ax)
            error('CW mode not supported for ODMR APD.')
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.APDcounts = obj.data;
                data.meas_time = obj.meas_time_ms;
                data.readout_time = obj.readout_time;
                GetData@Experiments.ODMR.ODMR_invisible(obj); %call the superclass method
            else
                data = [];
            end
        end
    end
end