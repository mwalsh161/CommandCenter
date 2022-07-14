classdef AndorEMCCD < Imaging.umanager.Camera
    %AndorEMCCD for iXion 885
    
    properties(SetObservable,GetObservable)
        trigger = Prefs.MultipleChoice('Software','allow_empty',false,'choices',{'External','External Exposure','External Start','Fast External','Internal'},'help_text','Type of triggering for camera to use','set','set_trigger');
    end
    
    methods
        function val = set_trigger(obj,val,~)
            obj.mmc('Andor-Trigger',val)
        end
    end
    methods(Access=private)
        function obj = AndorEMCCD()
            obj.prefs = [obj.prefs, 'trigger']
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

