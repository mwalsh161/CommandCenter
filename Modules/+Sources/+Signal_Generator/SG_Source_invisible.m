classdef SG_Source_invisible < Modules.Source 
    %SuperClass for serial sources
    
    properties
        serial; 
    end
  
    properties (SetObservable)
       MWFrequency = 3e9; %MW frequency 
       MWPower = -30; %dBm of SG
    end
    
    properties(SetAccess=private, SetObservable, AbortSet)
        source_on=false;
    end
   
    methods
        function obj = SG_Source_invisible()
        end
    end
    
    methods
        function set.MWFrequency(obj,val)
            assert(isnumeric(val),'MWFrequency must be of dataType numeric.')
            obj.serial.setFreqCW(val);
            obj.MWFrequency = obj.serial.getFreqCW;
        end
        
        function set.MWPower(obj,val)
            assert(isnumeric(val),'MWPower must be of dataType numeric.')
            obj.serial.setPowerCW(val);
            obj.MWPower = obj.serial.getPowerCW;
        end
       
        function MWFrequency = get.MWFrequency(obj)
            MWFrequency = obj.serial.getFreqCW;
            obj.MWFrequency = MWFrequency;
        end
        
        function MWPower = get.MWPower(obj)
            MWPower = obj.serial.getPowerCW;
            obj.MWPower = MWPower;
        end
        
        function delete(obj)
            obj.serial.delete;
        end

        function on(obj,~)
            obj.serial.on;
            obj.source_on=1;
        end
        
        function off(obj)
            obj.serial.off;
            obj.source_on=0;
        end
        
    end
end

