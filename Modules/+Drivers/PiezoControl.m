classdef (Sealed) PiezoControl < Modules.Driver
    %PIEZOCONTROL Use to control MDT693B piezo controller (Thorlabs)
    %   Uses serial connection to change the voltage on 3 piezos (x,y,z).
    %   The controller is not closed loop, and has an error between set
    %   voltage and actual voltage displayed.
    %
    %   Would need to use NIDAQ to make a scan function (serial is too
    %   slow)
    %
    %   Voltage queries all axis, so takes ~3 times as long as quering the
    %   axis of interest (i.e. getVX). This goes for setting too. If you
    %   want to set all of them at once, use setVAll
    %   
    %	Singleton based off COM port (see <a href="matlab:doc('PiezoControl.instance')">PIEZOCONTROL.instance</a>)
    
    properties
        timeout = 0.5;      % Timeout for serial object in seconds
    	displayIntensity    % A number in [0,7]. Use to set this value.
    end
    properties (SetAccess=private,SetObservable,AbortSet)
        Working = false     % In the middle of changing voltage (closely related to VoltageChange event)
    end
    properties(Hidden,SetAccess=private)
        Voltage            % Voltage in um centered at the mean of voltLim/calibration
    end
    properties(Access=private)
        channel
        busy = false;
    end
    properties(Constant,Hidden)
        FriendlyName = 'MDT693B RS232 Interface';   % Name stored in PC's registry for USB connection
    end
    properties(SetAccess=immutable)
        voltLim      % Voltage limits of device
    end
    
    events
        % Triggered 0.1 second after setting to allow device to update itself
        VoltageChange
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            port = GetPorts(Drivers.PiezoControl.FriendlyName);
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PiezoControl.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && strcmpi(port,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PiezoControl;
            obj.singleton_id = obj.channel.port;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = PiezoControl()
            obj.init_channel;
            obj.communicate('echo=0');
            vMin = textscan(obj.communicate('xmin?'),'*%f');
            vMax = textscan(obj.communicate('xmax?'),'*%f');
            obj.voltLim = [vMin{1} vMax{1}];
        end
        
        % Initialize the channel by finding the FriendlyName in the registry
        function init_channel(obj)
            com = GetPorts(obj.FriendlyName);
            if isempty(com)
                error('No COM port found installed with name %s.',obj.FriendlyName)
            end
            % Take care of any old channel if necessary
            if ~isempty(obj.channel)&&isvalid(obj.channel)
                if strcmp(obj.channel.status,'open')
                    fclose(obj.channel);
                end
                delete(obj.channel)
            end
            obj.channel = serial(com);
            set(obj.channel,'BaudRate',115200);
            set(obj.channel,'DataBits',8);
            set(obj.channel,'StopBits',1);
            set(obj.channel,'Terminator','CR');
            set(obj.channel,'TimeOut',obj.timeout)
        end
        
        % Method to do basic communication
        %   It will pause for atleast 50 ms, to make we don't lose any msg.
        %   Should only use communicate!
        function out = basic_com(obj, msg)
            %To save time, this does NOT close the channel
            %This will take no less than 50 ms.
            if strcmp(obj.channel.status,'closed')
                fopen(obj.channel);
            end
            output = false;
            if msg(end)=='?'|| contains(msg,'echo')
                output = true;
            end
            t = clock;
            fprintf(obj.channel,msg);
            % Get output if necessary
            out = '';
            if output
                out = fscanf(obj.channel);
                pause(0.01)
                while obj.channel.bytesavailable
                    out = [out fscanf(obj.channel,'%s%c',obj.channel.bytesavailable)];
                    pause(0.01)
                end
                out = deblank(out);
            end
            pause(max(0,0.05-etime(clock,t)))   % Pause 50 ms after sending
        end
        
        % More robust communication (behaves like sprintf)
        %   If problem writing, attempt to re-init channel and try again
        %   Will solve hardware being turned off and on.  Sets the busy
        %   property to block access. If busy, issues warning and retuns
        %   empty string.
        function out = communicate(obj,msg,varargin)
            out = '';
            if obj.busy
                warning('Com is busy, dropping request')
                return
            end
            obj.busy = true;
            if ~isempty(varargin)
                msg = sprintf(msg,varargin{:});
            end
            try
                out = obj.basic_com(msg);
            catch err
                if ~strcmp(err.identifier,'MATLAB:serial:fprintf:opfailed')
                    obj.busy = false;
                    rethrow(err)
                end
                obj.init_channel;
                try
                    out = obj.basic_com(msg);
                catch err
                    obj.busy = false;
                    rethrow(err)
                end
            end
            obj.busy = false;
        end
        
        % Method to get Voltage on axis, ax
        function val = getV(obj,ax)
            if ~ismember(ax,'xyz')
                error('ax must be x, y, z; not %s',ax)
            end
            val = obj.communicate('%cvoltage?',ax);
            val = textscan(val,'%*s%f%*s');
            val = val{1};
        end
        
        % Method to set Voltage, val, on axis, ax (or all)
        function setV(obj,ax,val)
            if ~ismember(ax,{'x','y','z','all'})
                error('ax must be x, y, z; not %s',ax)
            end
            if length(val) ~= 1
                error('Can only set one voltage, got %i.',length(val))
            end
            if val < min(obj.voltLim) || val > max(obj.voltLim)
                error('Voltage limit is %0.2f - %0.2f. Tried to set %0.2f',min(obj.voltLim),max(obj.voltLim),val)
            end
            obj.communicate('%svoltage=%0.2f',ax,val);
            obj.Working = true;
            % Send notification after a delay to make sure it updates, but
            % don't hold up execution.
            t=timer('TimerFcn',@obj.notifyVoltChange,'StartDelay',0.1);
            start(t)
        end
        
        % Method to issue event 0.1 second after setV finishes
        function notifyVoltChange(obj,t,varargin)
            notify(obj,'VoltageChange')
            obj.Working = false;
            stop(t)
            delete(t)
        end
    end
    methods
        %% Basic methods and property control
        function delete(obj)
            if ~isempty(obj.channel)&&isvalid(obj.channel)
                if strcmp(obj.channel.status,'open')
                    fclose(obj.channel);
                end
                delete(obj.channel)
            end
        end
        function set.timeout(obj,val)
            set(obj.channel,'TimeOut',val) %#ok<MCSUP>
            obj.timeout = val;
        end
        function set.displayIntensity(obj,val)
            if val > 7 || val < 0
                val = min(max(0,val),7);
                warning('Must be 0-7, set to %i',val)
            end
            obj.communicate('intensity=%0.2f',val);
        end
        function val = get.displayIntensity(obj)
            val = obj.communicate('intensity?');
            val = textscan(val,'*%f');
            val = val{1};
        end
        function val = get.Voltage(obj)
            val(1) = obj.getVX;
            val(2) = obj.getVY;
            val(3) = obj.getVZ;
        end
        
        %% Get methods
        function val = getVX(obj)
            val = obj.getV('x');
        end
        function val = getVY(obj)
            val = obj.getV('y');
        end
        function val = getVZ(obj)
            val = obj.getV('z');
        end
        
        %% Set methods
        function setVX(obj,val)
            % Set voltage on x axis
            obj.setV('x',val)
        end
        function setVY(obj,val)
            % Set voltage on y axis
            obj.setV('y',val)
        end
        function setVZ(obj,val)
            % Set voltage on z axis
            obj.setV('z',val)
        end
        function setVAll(obj,val)
            % Set all voltages
            obj.setV('all',val)
        end
        function move(obj,x,y,z)
            % Move to x,y,z in V (if any are empty, ignore that axis)
            obj.Working = true;
            if ~isempty(x)
                obj.setVX(x);
            end
            if ~isempty(y)
                obj.setVY(y);
            end
            if ~isempty(z)
                obj.setVZ(z);
            end
        end
        function step(obj,dx,dy,dz)
            pos = obj.Voltage;
            obj.move(pos(1)+dx,pos(2)+dy,pos(3)+dz)
        end

        % If some error occured/issue when aborting during debug
        function forceUnlockCom(obj)
            obj.busy = false;
        end
    end
    
end
