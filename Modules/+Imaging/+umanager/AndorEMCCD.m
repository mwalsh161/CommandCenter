classdef AndorEMCCD < Imaging.umanager.Camera
    %AndorEMCCD for iXion 885
    
    properties(SetObservable,GetObservable)
        trigger = Prefs.MultipleChoice('Software','allow_empty',false,'choices',{'Software','External','External Exposure','External Start','Fast External','Internal'},'help_text','Type of triggering for camera to use','set','set_trigger');
        EM_gain = Prefs.Double(3,'help_text','EM gain on the CCD','set','set_EM_gain','min',3,'max',1000);
    end
    
    methods
        function val = set_trigger(obj,val,~)
            obj.mmc('setProperty','Andor','Trigger',val)
        end
        function val = set_EM_gain(obj,val,~)
            obj.mmc('setProperty','Andor','Gain',val)
        end
    end
    methods(Access=private)
        function obj = AndorEMCCD()
            obj.prefs = [obj.prefs{1:2}, {'trigger', 'EM_gain'}, obj.prefs{3:numel(obj.prefs)}];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.umanager.AndorEMCCD();
            end
            obj = Object;
        end
    end
end

