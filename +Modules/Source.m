classdef Source < Base.Module
    %MODULE Abstract Class for Modules.
    %   Simply enforces required properties. For future use.
    properties(GetObservable,SetObservable)
        source_on = Prefs.Boolean(false, 'display_only', true, 'allow_nan', true, 'set', 'set_source_on');   % Boolean representing if the source is illuminating area of interest.
        armed =     Prefs.Boolean(false, 'display_only', true, 'allow_nan', true, 'set', 'set_armed');
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
            addlistener(obj,'source_on','PostSet',@obj.updateCommandCenter);
        end
    end
    
    methods(Abstract)
        val = set_source_on(obj, val, ~)
    end
    
    methods
        function on(obj)     % Turn source on
            obj.source_on = true;
        end
        function off(obj)    % Turn source off
            obj.source_on = false;
        end
    end
    
    methods
        function val = set_armed(obj, val, ~)
            % For the user to set.
        end
        function arm(obj)
            %this method should "arm" the source, doing whatever is
            %necessary such that a call of the "on" method will yield the
            %desired emissions from the source; for example, this may
            %include powering on a source
            % Note: this method will be called everytime a user manually
            % turns a source on from CC GUI, so the developer is responsible
            % for ensuring extra work isn't performed if not necessary.
            if ~obj.armed
                resp = questdlg('Source not armed; arm source, then click "Ok"','Arm (Modules.Source)','Ok','Cancel','Ok');
                if ~strcmp(resp,'Ok')
                    error('%s not armed',class(obj))
                end
                obj.armed = true;
            end
        end
        function blackout(obj)
            %this method should do whatever is necessary to completely
            %block emissions from the source; for example, this may include
            %powering off a source
            if obj.armed
                resp = questdlg('Source is armed; blackout source, then click "Ok"','Blackout (Modules.Source)','Ok','Cancel','Ok');
                if ~strcmp(resp,'Ok')
                    error('%s not blacked out',class(obj))
                end
                obj.armed = false;
            end
        end
%         function val = set_armed(obj, val, ~)
%             if val
%                 obj.arm();
%             else
%                 obj.blackout();
%             end
%         end
    end
    methods(Access=private)
        function updateCommandCenter(obj,~,~)
            if isstruct(obj.CC_dropdown) && isvalid(obj.CC_dropdown.h)
                i = obj.CC_dropdown.i;
                name = strsplit(class(obj),'.');
                short_name = strjoin(name(2:end),'.');
                if obj.source_on
                    obj.CC_dropdown.h.String{i} = sprintf('<HTML><FONT COLOR="green">%s</HTML>',short_name);
                else
                    obj.CC_dropdown.h.String{i} = sprintf('<HTML><FONT COLOR="red">%s</HTML>',short_name);
                end
            end
        end
    end
    
end

