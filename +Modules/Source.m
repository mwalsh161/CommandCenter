classdef Source < Base.Module
    % SOURCE abstracts hardware objects that emit signal.

    % Required signal control prefs source_on (fast modulation) and armed (preparation for fast modulation).
    %    display_only means the Prefs will not be saved (or accidentally loaded at startup).
    %    This is important for the prevention of unscheduled explosions.
    properties(GetObservable,SetObservable,Hidden)
        source_on = Prefs.Boolean(false, 'display_only', true, 'allow_nan', true, 'set', 'set_source_on', ...
                        'help', ['source_on is usually the "fast" method for modulating the source, such as an AOM. ' ...
                                'If no fast method exists, this usually simply wraps armed. The user must define the ' ...
                                'Abstract method set_source_on to interface with the hardware. Is wrapped by on()/off().']);
    end
    properties(GetObservable,SetObservable)
        armed =     Prefs.Boolean(false, 'display_only', true, 'allow_nan', true, 'set', 'set_armed', ...
                        'help', ['armed prepares the source for fast modulation such as turning the diode on. If armed is ' ...
                                'false, the source should not emit signal at all. Is wrapped by arm()/blackout().']);
    end

    properties(SetAccess={?SourcesManager},GetAccess=private)
        % CC_dropdown.h = Handle to dropdown in CommandCenter
        % CC_dropdown.i = index for this module in CC manager list
        CC_dropdown;
    end
    properties(Constant,Hidden)
        modules_package = 'Sources';
    end
    methods
        function obj = Source
            addlistener(obj, 'source_on',   'PostSet', @obj.updateCommandCenter);
            addlistener(obj, 'armed',       'PostSet', @obj.updateCommandCenter);
        end
    end

    % source_on methods
    methods(Abstract)   % For the user to set to interface with the "fast" hardware.
        val = set_source_on(obj, val, ~)
    end
    methods(Sealed)     % Methods for backwards compatibility with code that uses the old on() and off() methods. Now simply wraps source_on.
        function on(obj)     % Turn source on
            obj.source_on = true;
            % Don't additionally arm in case one is just testing modulation without light.
        end
        function off(obj)    % Turn source off
            obj.source_on = false;
        end
    end

    % armed methods
    methods             % For the user to overwrite if arming or preparing the laser can be automated.
        function val = set_armed(obj, val, pref)
            if pref.value ~= val
                if val
                    %this method should "arm" the source, doing whatever is
                    %necessary such that a call of the "on" method will yield the
                    %desired emissions from the source; for example, this may
                    %include powering on a source
                    % Note: this method will be called everytime a user manually
                    % turns a source on from CC GUI, so the developer is responsible
                    % for ensuring extra work isn't performed if not necessary.
                    resp = questdlg(['Source not armed; please arm source manually, then click "Ok" ' ...
                            '(disable this warning by overwriting val = set_armed(obj, val, ~))'], 'Arm (Modules.Source)', ...
                            'Ok', 'Cancel', 'Ok');
                    if ~strcmp(resp, 'Ok')
                        error('%s not armed',class(obj));
                    end
                else
                    %this method should do whatever is necessary to completely
                    %block emissions from the source; for example, this may include
                    %powering off a source
                    resp = questdlg(['Source is armed; please blackout source manually, then click "Ok" ' ...
                            '(disable this warning by overwriting val = set_armed(obj, val, ~))'], 'Blackout (Modules.Source)', ...
                            'Ok', 'Cancel', 'Ok');
                    if ~strcmp(resp, 'Ok')
                        error('%s not blacked out',class(obj));
                    end
                end
            else
                % AbortSet
            end
        end
    end
    
    methods(Sealed)     % Methods for backwards compatibility with code that uses the old arm() and blackout() methods. Now simply wraps armed.
        function arm(obj)
            obj.armed = true;
        end
        function blackout(obj)
            obj.armed = false;
        end
    end
    
    methods(Hidden)
        function updateCommandCenter(obj,~,~)
            if isstruct(obj.CC_dropdown) && isvalid(obj.CC_dropdown.h)
                i = obj.CC_dropdown.i;

                name = strsplit(class(obj),'.');
                short_name = strjoin(name(2:end),'.');

                if isnan(obj.source_on) || isnan(obj.armed)
                    color = 'rgb(255,0,255)';               % NaN is used when connectivity is certain to be *unknown* (i.e. no com connection).
                elseif obj.source_on && obj.armed
                    color = 'rgb(0,200,0)';                 % Green ==> all good.
                elseif obj.armed
                    color = 'rgb(255,128,0)';               % Orange ==> ready for source_on
                elseif obj.source_on
                    color = 'rgb(255,69,0)';                % Dark-orange ==> not armed.
                else
                    color = 'rgb(255,0,0)';                 % Red ==> entirely off.
                end
                
                obj.CC_dropdown.h.String{i} = sprintf('<html><font color=%s>%s</html>', color, short_name);
            end
        end
    end

end
