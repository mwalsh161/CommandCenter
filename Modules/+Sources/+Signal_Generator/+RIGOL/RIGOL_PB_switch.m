classdef RIGOL_PB_switch < Sources.Signal_Generator.MW_PB_switch_invisible
    %RIGOL serial source class
    
    properties
        piezoStage
        prefs = {'MWFrequency','ip','MWPower','MW_switch_on','MW_switch_PB_line','SG_trig_PB_line','visaAddress'};
    end
    
    properties(SetObservable)
        visaAddress = 'USB0::0x1AB1::0x099C::DSG8E192000035::0::INSTR';
    end
    
    properties(SetAccess=private, SetObservable)
        SG_name='Signal Generator 1';
    end
    
    methods(Access=protected)
        function obj = RIGOL_PB_switch()
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
            obj.MW_switch_on = 'yes';
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Signal_Generator.RIGOL.RIGOL_PB_switch();
            end
            obj = Object;
        end
    end
  
end



