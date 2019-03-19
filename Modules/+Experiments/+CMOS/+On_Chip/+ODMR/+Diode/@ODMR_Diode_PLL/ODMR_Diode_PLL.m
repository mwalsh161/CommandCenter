classdef ODMR_Diode_PLL < Experiments.CMOS.CMOS_invisible & Experiments.ODMR.ODMR_invisible
    
    properties
        ChipControl
        prefs = {'DriverBias','nAverages','start_freq','stop_freq',...
            'dummy_pb_line','Norm_freq','number_points','freq_step_size',...
            'Display_Data','waitTimeSGswitch_us','RF_power','trig_type'};
    end
    
    properties(SetObservable)
        Norm_freq = 2e9;
        Display_Data ={'Yes','No'};
        trig_type = {'Internal'};
    end
    
    
    methods(Access=private)
        function obj = ODMR_Diode_PLL()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.On_Chip.ODMR.Diode.ODMR_Diode_PLL();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
        
        function freq_list=determine_freq_list(obj)
            freq_list = zeros(1,2*obj.number_points);
            freq_list_data = linspace(obj.start_freq,obj.stop_freq,obj.number_points);
            freq_list_norm = ones(1,obj.number_points).*obj.Norm_freq;
            freq_list(1:2:end) = freq_list_data;
            freq_list(2:2:end) = freq_list_norm;
        end
        
        function initialize_data_acquisition_device(obj,~)
            obj.data = [];
        end
        
        function plot_data(obj)
            freq_list = (obj.determine_freq_list)*10^-9; %frequencies in GHz
            freq_list = freq_list(1:2:end);
            nanIndex = ~isnan(obj.data.contrast_vector);
            errorbar(freq_list(nanIndex),obj.data.contrast_vector(nanIndex),obj.data.error_vector(nanIndex),'parent',obj.ax)
            xlim(obj.ax,freq_list([1,end]));
            xlabel(obj.ax,'Microwave Frequency (GHz)')
            ylabel(obj.ax,'Normalized Current')
        end
        
    end
    
    methods
       
        function abort(obj)
            obj.ChipControl.off;
            abort@Experiments.ODMR.ODMR_invisible(obj)
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data = GetData@Experiments.ODMR.ODMR_invisible(obj);
                data.data = obj.data;
                data.DriverBias = obj.DriverBias;
                data.Norm_freq = obj.Norm_freq;
                data.ChipControl.VCO_CTRL_Line = obj.VCO_CTRL_Line;
                data.ChipControl.VDD_VCO = obj.ChipControl.VDD_VCO; 
                data.ChipControl.V_Capacitor = obj.ChipControl.V_Capacitor;
                data.ChipControl.VDD_Driver = obj.ChipControl.VDD_Driver;
                data.ChipControl.DriverBias = obj.ChipControl.DriverBias;
                data.ChipControl.PhotoDiodeBias = obj.ChipControl.PhotoDiodeBias;
                
            else
                data = [];
            end
        end
    end
end