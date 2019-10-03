classdef MEdge_invisible < handle
    %Millenia Edge Responsible for basic Millenia Edge control
    %   Wrapper for the MillendiaEdgeClient
    %   Upon loading, will check out laser (enable)
    %   Upon deleting and/or inactivity period, will check in laser (disable)
    
    properties(SetObservable)
        Secret_Key_path = '';
        enabled = false;
    end
    properties
        prefs = {'Secret_Key_path'};
        show_prefs = {'enabled','Secret_Key_path'};
    end
    
    methods
        function obj = MEdge_invisible
            if ~isempty(obj.Secret_Key_path)
                obj.enabled = true;
            end
        end
        function delete(obj)
            obj.inactive;
        end
        function arm(obj)
            obj.enabled = true;
        end
        function task = inactive(obj)
            task = '';
            if ~isempty(obj.Secret_Key_path)
                obj.enabled = false;
                task = 'MILLENIA EDGE checked in';
            end
        end
        
        function set.Secret_Key_path(obj,val)
            % Either make sure it is empty or it exists
            if ~isempty(val) && ~isfile(val)
                err.message = 'Secret Key path does not exist!';
                err.identifier = 'MILLENIA EDGE:secret_key';
                error(err)
            end
            obj.Secret_Key_path = val;
        end
        function set.enabled(obj,val)
            if isempty(obj.Secret_Key_path)
                err.message = 'Secret Key path not set!';
                err.identifier = 'MILLENIA EDGE:secret_key';
                error(err)
            end
            if ~islogical(val)
                err.message = 'enabled must be a logical';
                err.identifier = 'MILLENIA EDGE:wrong_inputs';
                error(err)
            end
            checkoutlaser(val,obj.Secret_Key_path)
            obj.enabled = val;
        end
    end
end

