classdef CMOS_invisible < Modules.Experiment

     properties (SetObservable)
        DriverBias = 1; % in Volts
     end
    
     properties (Constant)
         maxVoltage = 1.2; %maximum operational voltage for the driver
         PLLDivisionRatio = 24;
     end
     
     methods
        function obj = CMOS_invisible()
        end
        
        function set.DriverBias(obj,val)
            assert(isnumeric(val),'DriverBias must be numeric')
            assert(val>=0 ,'DriverBias must be positive')
            assert(val<=obj.maxVoltage ,sprintf('DriverBias must be less than %d volts',obj.maxVoltage))
            obj.DriverBias = val;
        end
        
     end
    
   
end