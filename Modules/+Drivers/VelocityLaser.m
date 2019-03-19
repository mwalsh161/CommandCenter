classdef VelocityLaser < Modules.Driver
    %VELOCITYLASER Connects with server.py on host machine to control
    % the Velocity Laser.
    %
    % Call with the IP of the host computer (singleton based on ip)
    
    properties (Constant)
        hwname = 'velocitylaser';
    end
    properties (SetAccess=immutable)
        connection
        idn
    end
    properties (SetObservable)
        PiezoPercent = [];
        Wavelength = [];
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
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(ip,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.VelocityLaser(ip);
            obj.singleton_id = ip;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = VelocityLaser(ip)
            obj.connection = hwserver(ip);
            try
                obj.idn = obj.com('idn');
            catch err
                error(err.message);
            end
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
        function on(obj)
            obj.com('on');
            pause(5);
        end
        function off(obj)
            obj.com('off');
            pause(5);
        end
        function set.Power(obj,val)
            obj.com('setPower',val);
            obj.Power = val;
        end
        function set.TrackMode(obj,val)
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
            obj.TrackMode = val;
        end
        function set.ConstantPowerMode(obj,val)
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
            obj.ConstantPowerMode = val;
        end
        function set.Wavelength(obj,val)
            assert(val>635 && val < 640,'Laser wavelength must be in range [635 640].')
            obj.com('setWavelength',val);
            obj.Wavelength = val;
            if strcmpi(obj.TrackMode,'off')
                obj.TrackMode = 'off'; %set.TrackMode affirms local setting with hardware
            end
            pause(0.1); %needed to give laser time to settle into new mode
        end
        function set.PiezoPercent(obj,val)
            obj.com('setPiezoPercent',val);
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