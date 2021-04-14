classdef (ConstructOnLoad) PrefListener < handle
    % PREFLISTENER is designed to be a drop in for event.proplistener
    % preflistener(event.proplistener)
    % preflistener(hSource,PropertyName,EventName,callback)
    %   Limitations: cannot be in a heterogeneous array with event.proplistener
    %       Instead, you can wrap event.proplistener with this class
    
    properties(SetAccess=immutable)
        Object = {}; % Present for proplisteners, not eventlisteners
        Source
        EventName
        Callback
    end
    properties
        Enabled = true;
        Recursive = false;
    end
    properties(Access={?Base.Module})
        % Used internally for Module
        executing = false;
        PropertyName = '';
    end
    properties%(Access=private)
        % Used when wrapping proplistener (wrapping useful to maintain arrays of listeners)
        wrapper = false;  % Indicates proplistener is present
        proplistener;
    end

    methods
        function obj = PrefListener(varargin)
            % preflistener(proplistener)
            % preflistener(hSource,PropertyName,EventName,callback)
            if nargin == 1
                obj.proplistener = varargin{1};
                if isprop(obj.proplistener,'Object')
                    obj.Object = obj.proplistener.Object;
                end
                obj.Source = obj.proplistener.Source;
                obj.EventName = obj.proplistener.EventName;
                obj.Callback = obj.proplistener.Callback;
                addlistener(obj.proplistener,'ObjectBeingDestroyed',@(~,~)obj.delete);
                obj.wrapper = true;
            else
                obj.Object = {varargin{1}};
                obj.Source = {findprop(varargin{1},varargin{2})};
                obj.PropertyName = varargin{2};
                obj.EventName = varargin{3};
                obj.Callback = varargin{4};
            end
        end

        function delete(obj)
            delete(obj.proplistener);
        end
        function set.Enabled(obj,val)
            if obj.wrapper %#ok<MCSUP>
                obj.proplistener.Enabled = val; %#ok<MCSUP>
            end
            obj.Enabled = val;
        end
        function set.Recursive(obj,val)
            if obj.wrapper
                obj.proplistener.Recursive = val;
            end
            obj.Recursive = val;
        end
    end
end