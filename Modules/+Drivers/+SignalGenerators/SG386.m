classdef SG386 < Drivers.SignalGenerators.SignalGenerator 
    % Drivers.SignalGenerators.SG386 is the driver class for the serial interface to a Standford Research Systems SG386 signal generator.

    properties
        prefs = {'comObjectInfo'};
        comObjectInfo = struct('comType','','comAddress','','comProperties','') 
        comObject;     % USB-Serial/GPIB/Prologix
    end
  
    methods(Static)
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.SignalGenerators.SG386.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.SignalGenerators.SG386();
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function [obj] = SG386()
            obj.SG_init;
        end
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
            %should return the frequencies set for List mode. Not critical to implement.
            error('Not implemented');
        end
        
        function  [PowerList]=getPowerList(obj)
            %should return the powers set for List mode. Not critical to implement.
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
            %off when done. Not critical to implement.
            
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