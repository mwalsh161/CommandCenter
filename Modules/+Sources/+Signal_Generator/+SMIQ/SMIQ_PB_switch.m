classdef SMIQ_PB_switch < Sources.Signal_Generator.MW_PB_switch_invisible
    %SMIQ serial source class
    
    properties
       prefs = {'MWFrequency','ip','MWPower','MW_switch_on','MW_switch_PB_line','SG_trig_PB_line'};
    end
    
    properties(SetAccess=private, SetObservable)
        SG_name='Signal Generator 1';
    end
    
    methods(Access=protected)
        function obj = SMIQ_PB_switch()
            obj.serial = Drivers.SignalGenerators.SMIQ06B.instance(obj.SG_name); 
            obj.loadPrefs;
            obj.MW_switch_on = 'yes';
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Signal_Generator.SMIQ.SMIQ_PB_switch();
            end
            obj = Object;
        end
    end
end

