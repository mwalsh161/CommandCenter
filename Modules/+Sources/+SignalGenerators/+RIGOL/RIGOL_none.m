classdef RIGOL_none < Sources.SignalGenerators.SG_Source_invisible
    %RIGOL serial source class
    
    properties
        %prefs = {'MWFrequency','MWPower','visaAddress'};
    end
    
    properties(SetObservable)
        visaAddress = 'USB0::0x1AB1::0x099C::DSG8E192000035::0::INSTR';
    end
    
    properties(SetAccess=private, SetObservable)
        SG_name='Signal Generator 1';
    end
    
    methods(Access=protected)
        function obj = RIGOL_none()
            comObjectArray = instrfind('Type', 'visa-usb', 'RsrcName', obj.visaAddress, 'Tag', '');
            
            % Create the VISA-USB object if it does not exist
            % otherwise use the object that was found.
            if isempty(comObjectArray)
                rigolComObject = visa('NI', obj.visaAddress);
            else
                if iscell(comObjectArray)
                    for index = 1:numel(comObjectArray)
                        rigolComObject = comObjectArray{index};
                        if strcmpi(rigolComObject.status,'open')
                            break
                        end
                        if index == numel(comObjectArray)
                            fclose(comObjectArray);
                            rigolComObject = comObjectArray(1);
                        end
                    end
                else
                    rigolComObject = comObjectArray(1);
                end
            end
            
            obj.serial = Drivers.SignalGenerators.RIGOL_DSG830.instance(obj.SG_name,rigolComObject);
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SignalGenerators.RIGOL.RIGOL_none();
            end
            obj = Object;
        end
    end
    
    methods
        function delete(obj)
        end

        function f_sweep(obj,f_start, f_stop, n)
            % sets up a frequency sweep such that every time the external trigger is pressed, the frequency changes to the next value, looping back to first value after reaching the end.
            % f_start, f_stop: sweep start & stop frequency in Hz
            % n: number of points in the sweep
            obj.serial.setSweepType('freq')
            obj.serial.setTrigPolarity('pos')
            obj.serial.setSweepMode('continuous') %Ensure that sweep loops
            obj.serial.setPointTrig('ext') % Sweep step triggered by external TTL
            obj.serial.setSweepStartFreq(f_start)
            obj.serial.setSweepStopFreq(f_stop)
            obj.serial.setSweepNumPoints(n)

            obj.serial.executeSweep()
        end
    end
end

