classdef CG635ClockGenerator < Modules.Source 
    %CG635ClockGenerator serial source class
    
    properties
        serial
        prefs = {'ClockFrequency','Voltage'};
        running
    end
     
    properties (SetObservable)
       ClockFrequency = 1e6; 
       Voltage = {'1.2','1.8','2.5','3.3','5'}; 
    end
  
    properties(SetAccess=private, SetObservable, AbortSet)
        source_on=false;
    end
   
    properties(SetAccess=private, SetObservable)
        Clock_name='CG635ClockGenerator 1';
    end
   
    methods(Access=protected)
        function obj = CG635ClockGenerator()
            obj.serial = Drivers.CG635ClockGenerator.instance(obj.Clock_name);
            obj.loadPrefs;
            obj.off;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.CG635ClockGenerator();
            end
            obj = Object;
        end
    end
   
    methods
        function set.ClockFrequency(obj,val)
            obj.serial.setOutputClockFrequency(val); %debugging happens here
            obj.ClockFrequency = val;
        end
        
        function set.Voltage(obj,val)
            obj.serial.setOutputVoltage(val); %debugging happens here
            obj.Voltage =val;
        end
       
        function ClockFrequency = get.ClockFrequency(obj)
            ClockFrequency = obj.serial.getOutputClockFrequency;
        end
        
        function Voltage = get.Voltage(obj)
            Voltage = obj.serial.getOutputVoltage;
            Voltage = num2str(Voltage);
        end
        
        function on(obj,~)
           obj.serial.on;
           obj.source_on = 1;
        end
        
        function delete(obj)
            obj.serial.delete;
        end

        function off(obj)
            obj.serial.off;
            obj.source_on = 0;
        end
    end
end
    
