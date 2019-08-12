classdef PowerSupplies < Modules.Driver
    
    properties(Constant,Abstract)
        Dual_Polarity       %Can your power supply source a negative voltage? options: Yes or No
        Number_of_channels  %How many channels are programable? Should be a string. ex: '1', '2', '3'
        dev_id              %name of your device. ex: HAMEG
    end
    
    properties (Abstract)
        deviceID %device name
        comObject; % handle to device through Serial/GPIB/Prologix
    end
    
    %upon construction you should set the voltage limit to be 5 V and the
    %current limit to be 50 mA.
    
    %Power supply should be off upon construction.
    
    methods
        
        function  setCurrent(obj,channel,current)
            %this sets the current to desired value. Does not turn on.
            %current should be in Amps.
            
            %channel must be entered as a string that is an integer ex:
            %'1'. Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %current must be a double.
            
            error('Not implemented');
        end
        
        function  setVoltage(obj,channel,voltage)
            %this sets the voltage to desired value. Does not turn on.
            %voltage should be in Volts.
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %voltage must be a double.
            
            error('Not implemented');
        end
        
        function  setVoltageLimit(obj,channel,voltage_limit)
            %this sets the voltage limit to desired value. Does not turn on.
            %voltage_limit should be in Volts.
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %voltage limit must be a double.
            
            %If voltage limit is entered as a vector of length two then
            %each element should apply to each pole of the voltage
            %source.First element should be positive pole and second
            % should be the negative pole. If it has a length of one 
            %should be applied symmetrically: +/- voltage_limit.
            
            error('Not implemented');
        end
        
        function  setCurrentLimit(obj,channel,current_limit)
            %this sets the current limit to desired value. Does not turn on.
            %current_limit should be in Amps.
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %Current limit must be a double.
            
            %If current limit is entered as a vector of length two then
            %each element should apply to each pole of the current
            %source.First element should be positive pole and second
            %should be the negative pole. If it has a length of one 
            %should be applied symmetrically: +/- current_limit.
            
            
            error('Not implemented');
        end
           %% 
        
        function  [voltage] = measureVoltage(obj,channel)
            %this gets the voltage. Unit should be Volts
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %output: double  
            
            error('Not implemented');
        end
        
        function  [current] = measureCurrent(obj,channel)
            %this gets the current. Unit should be Amps
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %output: double 
            
            error('Not implemented');
        end
        %%
      
        function [upperlim,lowerlim]  = getCurrentLimit(obj,channel)
            %this gets the CurrentLim in Amps
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %output: double, unit should be Amps
            
            %upperlim should be the positive rail.
            %lowerlim should be the negative rail. 
            
            % for a single pole powersupply lowerlim should be 0.
            
            error('Not implemented');
        end
        
        function [upperlim,lowerlim]  = getVoltageLimit(obj,channel)
            %this gets the VoltLim in Volts
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %output: double,units Volts
            
            %upperlim should be the positive rail.
            %lowerlim should be the negative rail. 
            
            %for a single pole powersupply lowerlim should be 0.
      
            error('Not implemented');
        end
        
        function voltage = getVoltage(obj,channel)
            %this gets the set voltage in Volts, not the voltage
            %when the device is on. Call measureVoltage for that. 
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %output: double,units Volts
            
        end
        
        function current = getCurrent(obj,channel)
            %this gets the set Current in Amps, not the current
            %when the device is on. Call measureCurrent for that. 
            
            %channel must be entered as a string that is an integer ex:
            %'1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            %output: double,units Volts
            
        end
        
        function [Power_supply_state] = getState(obj,channel)
            % channel must be entered as a string that is an integer ex:
            % '1'.Channel input must be less than or equal to
            %'Number_of_channels'.
            
            % output should be On or Off
            
            error('Not implemented');
        end
     
        %% 
        function off(obj,channel)
            %should turn off all channel if no channel is supplied. Turn 
            %off only channel if that is supplied
            error('Not implemented');
        end
        
        function on(obj,channel)
            %should turn on all channel if no channel is supplied.If a
            %channel is supplied only that channel should turn on.
            %if should check that a current and voltage limit is set. If it
            %isn't then it should error.
            %it should also check if the power supply is railing. If it is
            %then it should issue a warning.
            
            error('Not implemented');
        end
       
        function reset(obj)
            %should turn off all channel. It should also set default voltage
            %limit(5 V) and current limit (50 mA) for all channel. It should also return
            %the power supply to conditions where like it has just been
            %constructed. Consider calling a *RST setting.
            error('Not implemented');
        end
    end
end