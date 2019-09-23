classdef SuperK < Modules.Source
    %   SuperK used to control all aspects of the superK laser.
    %
    %   The emission state of the laser is controlled by serial connection
    %   

    
    properties
        host = 'No Server';         % host of computer with and server
        prefs = {'host'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running                      % Boolean specifying if StaticLines program running
    end
    properties(SetAccess=private,Hidden)
        status                       % Text object reflecting running
        path_button
        comm = hwserver.empty
    end
    methods(Access=protected)
        function obj = SuperK()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SuperK();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            if obj.comm_isvalid
                delete(obj.comm);
            end
        end
        function set.host(obj,val)
            err = [];
            if obj.comm_isvalid
                delete(obj.comm);
            end
            if isempty(val) || strcmp(val,'No Server')
                obj.comm = hwserver.empty;
                obj.host = 'No Server';
                return
            end
            try
                obj.comm = Drivers.SuperK.instance(val);
                obj.host = val;   
            catch err
                obj.host = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            obj.comm.on();
            obj.source_on = true;
        end
        function off(obj)
            obj.comm.off();
            obj.source_on = false;
        end

        function arm(obj)
            % nothing needs to be done since SuperK just needs on/off methods
        end
        
        function val = get.comm(obj)
            d = dbstack(1);
            if ~strcmp(d(1).name,'SuperK.comm_isvalid') % avoid recursive call
                assert(obj.comm_isvalid,'Not connected (set.host)');
            end
            val = obj.comm;
        end
        
        function val = comm_isvalid(obj) % get method allows direct access to comm
            val = any(isvalid(obj.comm));
        end
    end
end