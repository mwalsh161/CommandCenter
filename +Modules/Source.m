classdef Source < Base.Module
    %MODULE Abstract Class for Modules.
    %   Simply enforces required properties. For future use.
    properties(Abstract,SetAccess=private,SetObservable)
        source_on   % Boolean representing if the source is illuminating area of interest.
    end
    properties(SetAccess={?SourcesManager},GetAccess=private)
        % CC_dropdown.h = Handle to dropdown in CommandCenter
        % CC_dropdown.i = index for this module in CC manager list
        CC_dropdown;
    end
    properties(Constant,Hidden)
        modules_package = 'Sources';
    end
    
    methods(Abstract)
        on(obj)     % Turn source on
        off(obj)    % Turn source off
    end
    methods
        function obj = Source
            addlistener(obj,'source_on','PostSet',@obj.updateCommandCenter);
        end
        function arm(obj)
            %this method should "arm" the source, doing whatever is
            %necessary such that a call of the "on" method will yield the
            %desired emissions from the source; for example, this may
            %include powering on a source
            % Note: this method will be called everytime a user manually
            % turns a source on from CC GUI, so the developer is responsible
            % for ensuring extra work isn't performed if not necessary.
            warning('SOURCE:notimplemented','arm method not implemented for %s',class(obj))
        end
        function blackout(obj)
            %this method should do whatever is necessary to completely
            %block emissions from the source; for example, this may include
            %powering off a source
            warning('SOURCE:notimplemented','blackout method not implemented for %s',class(obj))
        end
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

