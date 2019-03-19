classdef SuperK < Modules.Driver
    %SUPERK Connects with server.py on host machine to control
    % the SuperK
    %
    % Call with the IP of the host computer (singleton based on ip)
    
    properties (Constant)
        hwname = 'superk';
    end
    properties (SetAccess=immutable)
        connection
    end

    methods(Static)
        function obj = instance(ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.SuperK.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(ip,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.SuperK(ip);
            obj.singleton_id = ip;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = SuperK(ip)
            obj.connection = hwserver(ip);
            
        end
        function response = com(obj,funcname,varargin) %keep this
            response = obj.connection.com(obj.hwname,funcname,varargin{:});
        end
    end
    methods
        function delete(obj)
            delete(obj.connection)
        end
        function on(obj)
            obj.com('on');
        end
        function off(obj)
            obj.com('off');
        end
        function setPower(obj,val)
            assert(val>0 && val < 100,'Power should be between 0% and 100%')
            strval = num2str(val,10);
            obj.com('setpower',strval);
        end
        function setND(obj,val)
            assert(val>0 && val < 100,'ND filter setting should be between 0% and 100%')
            strval = num2str(val,10);
            obj.com('setND',strval);
        end
        function setBandwidth(obj,val)
            assert(val>0,'Bandwidth must be > 0')
            strval = num2str(val,10);
            obj.com('setbandwidth',strval);
        end
        function setPulsePicker(obj,val)
            assert(mod(val,1) == 0,'Must pick out an integer # of pulses')
            strval = num2str(val,10);
            obj.com('setpulsepicker',strval);
        end
        function setRepRate(obj,val)
            assert(val > 0,'Rep. rate must be positive')
            strval = num2str(val,10);
            obj.com('setreprate',strval);
        end
        function setWavelength(obj,val)
            strval = num2str(val,10);
            obj.com('setwavelength',strval);
        end        
        function output = getND(obj)
            output = obj.com('getND');
        end
        function output = getBandwidth(obj)
            output = obj.com('getbandwidth');
        end
        function output = getPower(obj)
            output = obj.com('getpower');
        end
        function output = getPulsePicker(obj)
            output = obj.com('getpulsepicker');
        end
        function output = getRepRate(obj)
            output = obj.com('getreprate');
        end
        function output = getCurrent(obj)
            output = obj.com('getcurrent');
        end
        function output = getWavelength(obj)
            output = obj.com('getwavelength');
        end
    end
end