classdef SG_Source_invisible < Modules.Source 
    %SuperClass for serial sources
    
    properties
        serial; 
        show_prefs = {'MWFrequency','MWPower'};
        prefs = {};
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
        
        function delete(obj)
            if ~isempty(obj.serial) % Could be empty if error constructing
                obj.serial.delete;
            end
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

