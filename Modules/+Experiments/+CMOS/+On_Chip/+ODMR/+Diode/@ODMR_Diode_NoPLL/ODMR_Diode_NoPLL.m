classdef ODMR_Diode_NoPLL < Experiments.CMOS.CMOS_invisible 
    
    properties
        data;
        abort_request = false;  % Request flag for abort
        Ni   % NIDAQ
        laser
        pulseblaster
        ax %axis to data axis
        trig_type = 'Internal';
        Display_Data = 'Yes'
        ChipControl
        prefs = {'DriverBias','PhotoDiodeBias','nAverages','start_voltage','stop_voltage','number_points',...
            'waitTimeVCOswitch','norm_voltage','VCO_CTRL_Line','LaserOn'}      
    end
 
    properties(SetObservable)
        PhotoDiodeBias = 1e-3;
        LaserOn = {'Yes','No'};
        nAverages = 5;
        start_voltage = 0;
        stop_voltage = 2;
        number_points = 60; %number of frequency points desired
        waitTimeVCOswitch = 1; %time to wait for SG to step in freq after triggering
        norm_voltage = 0; %V
        VCO_CTRL_Line = 'VCO_CTRL_Line';
    end
    
    methods(Access=private)
        function obj = ODMR_Diode_NoPLL()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.On_Chip.ODMR.Diode.ODMR_Diode_NoPLL();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
       
        function plot_data(obj)
            voltage_list = (obj.determine_voltage_list); %frequencies in GHz
            voltage_list(2:2:end) = [];
            errorbar(voltage_list,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax)
            xlim(obj.ax,voltage_list([1,end]));
            xlabel(obj.ax,'VCO Voltage (V)')
            ylabel(obj.ax,'Normalized Voltage')
        end
        
         function voltage_list = determine_voltage_list(obj)
            voltage_list = zeros(1,2*obj.number_points);
            voltage_list_data = linspace(obj.start_voltage,obj.stop_voltage,obj.number_points);
            voltage_list_norm = ones(1,obj.number_points).*obj.norm_voltage;
            voltage_list(1:2:end) = voltage_list_data;
            voltage_list(2:2:end) = voltage_list_norm;
         end
         
         function module_handle = find_active_module(obj,modules,active_class_to_find)
            module_handle = [];
            for index=1:length(modules)
                class_name=class(modules{index});
                num_levels=strsplit(class_name,'.');
                truth_table=contains(num_levels,active_class_to_find);
                if sum(truth_table)>0
                    module_handle=modules{index};
                end
            end
            assert(~isempty(module_handle)&& isvalid(module_handle),['No actice class under ',active_class_to_find,' in CommandCenter as a source!'])
        end
    end
    
    methods
      
        function abort(obj)
            obj.ChipControl.off;
            obj.abort_request = true;
            obj.laser.off;
            obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,0);
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                
                data.VCO.voltage_list = obj.determine_voltage_list();
                data.VCO.norm_voltage = obj.norm_voltage;
                data.VCO.VCO_CTRL_Line = obj.VCO_CTRL_Line;
                
                data.LaserOn = obj.LaserOn;
                
                data.averages = obj.nAverages;
                data.trig_type = obj.trig_type;
                data.Display_Data = obj.Display_Data;
                data.waitTimeVCOswitch = obj.waitTimeVCOswitch;
                data.data = obj.data;
                                
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