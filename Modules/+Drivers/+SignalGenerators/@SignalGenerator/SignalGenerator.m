classdef SignalGenerator < Modules.Driver

    properties (Abstract)
        comObjectInfo
        comObject;   
    end
    
    methods
        
        function setUnitPower(obj)
            %this should set the units of the SG to dBm.
            error('Not implemented');
        end
        
        function  setFreqCW(obj,Freq)
            %Freq should be a double
            error('Not implemented');
        end
        
        function  setPowerCW(obj,Power)
           %Power should be a double
            error('Not implemented');
        end
        
      
        %% 
        
        function getUnitPower(obj)
            %this should return the units of the SG power.
            error('Not implemented');
        end
        
        function  [Freq]=getFreqCW(obj)
            %should return Freq as a double. If in List mode should error. 
            error('Not implemented');
        end
        
        function  [Power]=getPowerCW(obj)
            %should return Power as a double. Power should be in dBm. If in List mode should error. 
            error('Not implemented');
        end
        
        function  [FreqMode]=getFreqMode(obj)
            %should FreqMode as a string. Options should be CW,FIX or List. 
            error('Not implemented');
        end
        
        function  [PowerMode]=getPowerMode(obj)
           %should PowerMode as a string. Options should be CW,FIX or List. 
            error('Not implemented');
        end
        
        function  [FreqList]=getFreqList(obj)
            %should return the frequencies set for List mode.
            error('Not implemented');
        end
        
        function  [PowerList]=getPowerList(obj)
            %should return the powers set for List mode.
            error('Not implemented');
        end
        
        function  [MWstate]=getMWstate(obj)
            %should return the state of the SG.On or Off. 
            error('Not implemented');
        end
        
       
        %% 
        
        function program_list(obj,freq_list,power_list)
            %this should program the SG to output a freq list that can be
            %stepped through on trigger.Trigger should be a rising edge.
            %freq_list and power_list should be a vector of
            %doubles and they should be the same length. The SG should be
            %off when done. 
            
            error('Not implemented');
        end
       
        function off(obj)
            %this should turn Off the signal generator.
            error('Not implemented');
        end
        
        function on(obj)
           %this should turn On the signal generator.
            error('Not implemented');
        end
        
        function reset(obj)
            %this should turn the SG to a known state. For instance to CW
            %mode and a reference frequency and power.
            error('Not implemented');
        end
    end
end