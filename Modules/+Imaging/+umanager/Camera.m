classdef Camera < Imaging.umanager.umanager_invisible
    %CAMERA Provide the simplest of interfaces where the user specifies the
    %   config file and dev as a setting. loadPrefs is called in the init
    %   method.
    
    properties(SetObservable,GetObservable)
        dev = Prefs.String('help_text',...
            'This is the Device label for the Camera from the config file.');
        config_file = Prefs.String('help_text','Path to the .cfg file.');
        reload = Prefs.Boolean(false,'set','reload_toggle',...
            'help_text','Toggle this to reload core.')
    end
    
    methods(Access=private)
        function obj = Camera()
            obj.prefs = [obj.prefs, {'dev','config_file','reload'}];
        end
    end
    methods
        function val = reload_toggle(obj,~)
            % TODO: replace with a Prefs.Button
            % Pretends to be a button from a boolean pref
            val = false; % Swap back to false
            obj.init;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.umanager.Camera();
            end
            obj = Object;
        end
    end
end

