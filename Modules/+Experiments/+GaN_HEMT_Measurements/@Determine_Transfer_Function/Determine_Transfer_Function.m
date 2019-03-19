classdef Determine_Transfer_Function  < Modules.Experiment 
    
    properties
        ax
        data;
        listeners
        abort_request = false;  % Request flag for abort
        gateSupply
        drainSupply
        gateChannel
        drainChannel
        multimeterChannel
        measureDevice
        prefs = {'Drain_Power_Supply','Gate_Power_Supply','Multimeter',...
            'Drain_Voltage','start_gate_voltage','stop_gate_voltage',...
            'number_points','gate_voltage_step_size'};
    end
    
    properties (Constant)
      gateCurrentLimit = -10e-6; %Amps-maximum current allowed to flow through the gate 
      drainCurrentLimit = 0.1; %Amps-maximum current allowed to flow through the drain
    end
    
    properties (SetObservable)
        Drain_Power_Supply = {'Yokogawa_channel_1','HAMEG_channel_1','HAMEG_channel_2'};
        Gate_Power_Supply = {'Yokogawa_channel_1'};
        Multimeter = {'Yokogawa_channel_1','HP_3478A_channel_1'};
        
        Drain_Voltage = 0.1;
        start_gate_voltage = -5;
        stop_gate_voltage = 0;
        number_points = 25;
        gate_voltage_step_size = 1;
        
    end
    
    methods(Access=private)
        function obj = Determine_Transfer_Function()
%             obj.determine_correct_options;
            obj.loadPrefs;
            obj.listeners = addlistener(obj,'start_gate_voltage','PostSet',@obj.update_voltage_step);
            obj.listeners(end+1) = addlistener(obj,'stop_gate_voltage','PostSet',@obj.update_voltage_step);
            obj.listeners(end+1) = addlistener(obj,'number_points','PostSet',@obj.update_voltage_step);
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.GaN_HEMT_Measurements.Determine_Transfer_Function();
            end
            obj = Object;
        end
        
        function drivers = determine_all_class(path)
            classes=[];
            all_files=dir(path);
            if isempty(all_files)
                [~,path,~] = uigetfile('.m');
                all_files=dir(path);
            end
            all_class=all_files(3:end);
            for index=1:length(all_class)
                if isempty(strfind(all_class(index).name,'@'))
                    classes{index}=all_class(index).name;
                end
            end
            classes = classes(~cellfun('isempty',classes));
            if contains(path,'Modules')
                index = strfind(path,'Modules');
                path(index:numel('Modules')) = [];
            end
            new_path = strrep(path,'\+','.');
            if strcmp(new_path(1),'.')
                new_path(1) = [];
            end
            if ~strcmp(new_path(end),'.')
                new_path = [new_path,'.'];
            end
            for index = 1:numel(classes)
                if contains(classes{index},'.m')
                    class_name = strsplit(classes{index},'.m');
                    drivers{index} = [new_path,class_name{1}];
                end
            end
           drivers = drivers(~cellfun('isempty',drivers));  
        end
        
    end
    
    methods (Access=private)
        function channel = get_channel(obj,name)
            strings=strsplit(name,'channel_');
            channel = strings{end};
        end
       
        function plot_data(obj,index)
            gate_voltage_list = linspace(obj.start_gate_voltage,obj.stop_gate_voltage,obj.number_points);
            plot(gate_voltage_list(1:index),obj.data.drainCurrent(1:index)*1000,'parent',obj.ax)    
            title('Drain Current vs. Gate Voltage','parent',obj.ax)
            ylabel('Drain Current (mA)','parent',obj.ax)
            xlabel('Gate Voltage (V)','parent',obj.ax)
        end
    end
    
    methods
        
         function set.start_gate_voltage(obj,val)
            assert(isnumeric(val),'start_gate_voltage must be a of type numeric.')
            assert(val<0,'start_gate_voltage must be negative.')
            if ~isequal(val,obj.start_gate_voltage)
                obj.start_gate_voltage = val;
            end
        end
        
        function set.stop_gate_voltage(obj,val)
            assert(isnumeric(val),'stop_gate_voltage must be a of type numeric.')
            if ~isequal(val,obj.stop_gate_voltage)
                obj.stop_gate_voltage = val;
            end
        end
        
        function set.number_points(obj,val)
            assert(isnumeric(val),'number_points must be a of type numeric.')
            assert(val>0,'number_points must be positive.')
            assert(~logical(mod(val,1)),'number_points must be an integer.')
            if ~isequal(val,obj.number_points)
                obj.number_points = val;
            end
        end
        
        function set.gate_voltage_step_size(obj,val)
            assert(isnumeric(val),'gate_voltage_step_size must be a of type numeric.')
            try
                obj.number_points = (obj.stop_gate_voltage-obj.start_gate_voltage)./(val);
            catch err
                warning('Error when attempting to change gate_voltage_step_size')
                error(err.message)
            end
            obj.gate_voltage_step_size = val;
        end
        
        function update_voltage_step(obj,~,~)
            step_size = (obj.stop_gate_voltage-obj.start_gate_voltage)/obj.number_points;
            if ~isequal(step_size,obj.gate_voltage_step_size)
                obj.gate_voltage_step_size = step_size;
            end
        end
        
        function initialize_experiment(obj,managers)            
            strings = strsplit(obj.Gate_Power_Supply,'_channel');
            gate_power_supply_name=strings{1};
            
            strings = strsplit(obj.Drain_Power_Supply,'_channel');
            drain_power_supply_name=strings{1};
            
            strings = strsplit(obj.Multimeter,'_channel');
            multimeter_name=strings{1};

            obj.gateSupply = obj.intitialize_device(gate_power_supply_name,managers);
            obj.drainSupply = obj.intitialize_device(drain_power_supply_name,managers);
            obj.measureDevice = obj.intitialize_device(multimeter_name,managers);
            %turn off all three in case they were on
            obj.gateSupply.off;
            obj.drainSupply.off;
            obj.measureDevice.off;
            
            obj.drainChannel = obj.get_channel(obj.Drain_Power_Supply);
            obj.gateChannel = obj.get_channel(obj.Gate_Power_Supply);
            obj.multimeterChannel=obj.get_channel(obj.Multimeter);

        end
        
        function abort(obj)
            obj.abort_request = true;
            obj.gateSupply.off;
            obj.drainSupply.off;
            obj.measureDevice.off;
        end
        
         function delete(obj)
            delete(obj.listeners);
         end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data= obj.data;
                data.Drain_Power_Supply = obj.drainSupply;
                data.Gate_Power_Supply = obj.gateSupply;
                data.measureDevice = obj.measureDevice;
                data.gateChannel =obj.gateChannel;
                data.drainChannel = obj.drainChannel;
                data.multimeterChannel = obj.multimeterChannel;
            else
                data = [];
            end
        end
        
    end
    
end