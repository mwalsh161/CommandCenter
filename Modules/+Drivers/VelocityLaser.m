classdef VelocityLaser < Modules.Driver
    %VELOCITYLASER Connects with server.py on host machine to control
    % the Velocity Laser.
    %
    % Call with the IP of the host computer (singleton based on ip)
    
    properties (Constant)
        hwname = 'velocitylaser';
    end
    properties(Access=private)
        init = true; % Used in set methods
    end
    properties (SetAccess=immutable)
        connection
        idn
    end
    properties
        TuningTimout = 60;
    end
    properties (SetObservable)
        PiezoPercent = [];
        Wavelength = [];  % This is the set wavelength (not actual)
        ConstantPowerMode = [];
        TrackMode = [];
        Power = [];
    end
    methods(Static)
        function obj = instance(ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.VelocityLaser.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(resolvedIP,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.VelocityLaser(ip);
            obj.singleton_id = resolvedIP;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = VelocityLaser(ip)
            obj.connection = hwserver(ip);
            try % Init laser
                obj.idn = obj.com('idn');
                obj.PiezoPercent = obj.com('getPiezoPercent');
                obj.Wavelength = obj.measuredWavelength;
                obj.Power = obj.com('getPower');
            catch err
                error(err.message);
            end
            obj.init = false;
            obj.ConstantPowerMode = true;
            obj.TrackMode = false;
        end
        function response = com(obj,funcname,varargin) %keep this
            response = obj.connection.com(obj.hwname,funcname,varargin{:});
        end
    end
    methods
        function delete(obj)
            delete(obj.connection)
        end
        function on = getDiodeState(obj)
            on = obj.com('getDiodeState');
        end
        function wl = measuredWavelength(obj)
            wl = obj.com('getWavelength');
        end
        function on(obj)
            obj.com('on');
            pause(5); % As stated in the manual
        end
        function off(obj)
            obj.com('off');
        end
        function out = opc(obj)
            % Operation complete query
            out = obj.com('opc');
        end
        function set.Power(obj,val)
            if ~obj.init
                obj.com('setPower',val);
            end
            obj.Power = val;
        end
        function set.TrackMode(obj,val)
            if ~obj.init
                if ~ischar(val)
                    if ~islogical(val)
                        error('TrackMode requires true/false or string on/off input')
                    else
                        if val
                            val = 'on';
                        else
                            val = 'off';
                        end
                    end
                end
                obj.com('setTrackMode',val);
            end
            obj.TrackMode = val;
        end
        function set.ConstantPowerMode(obj,val)
            if ~obj.init
                if ~ischar(val)
                    if ~islogical(val)
                        error('ConstantPowerMod requires true/false or string on/off input')
                    else
                        if val
                            val = 'on';
                        else
                            val = 'off';
                        end
                    end
                end
                obj.com('setConstantPowerMode',val);
            end
            obj.ConstantPowerMode = val;
        end
        function set.Wavelength(obj,val)
            if ~obj.init
                start_timeout = obj.connection.connection.Timeout;
                obj.connection.connection.Timeout = obj.TuningTimout;
                try
                    obj.com('setWavelength',val,obj.TuningTimout);
                catch err
                    obj.connection.connection.Timeout = start_timeout;
                    rethrow(err);
                end
                obj.connection.connection.Timeout = start_timeout;
                if strcmpi(obj.TrackMode,'off')
                    obj.TrackMode = 'off'; %set.TrackMode affirms local setting with hardware
                end
            end
            obj.Wavelength = val;
        end
        function set.PiezoPercent(obj,val)
            if ~obj.init
                obj.com('setPiezoPercent',val);
            end
            obj.PiezoPercent = val;
        end
        function output = get.PiezoPercent(obj)
            output = obj.PiezoPercent;
        end
        function output = get.Wavelength(obj)
            output = obj.Wavelength;
        end
        function output = get.ConstantPowerMode(obj)
            output = obj.ConstantPowerMode;
        end
        function output = get.TrackMode(obj)
            output = obj.TrackMode;
        end
        function output = get.Power(obj)
            output = obj.Power;
        end
    end
end