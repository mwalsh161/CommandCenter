classdef Wavemeter1Ch < Modules.Driver
    %WAVEMETER Connects with server.py on host machine to control
    % the Wavemeter. For single channel HighFinesse wavemeters.
    % See Wavemeter.m for multichannel functionality.
    %
    % Call with the IP of the host computer
    %   (singleton based on ip)
    %
    %
    % In following comments, generally:
    %   channel/port = measurement channel
    %   signal = signal line from DAC (for ease, client doesn't allow
    %       changing away from same as channel/port). As in, for
    %       channel/port 1, client will only allow setting/unsetting signal
    %       1.
    %   DAC == Deviation
    
    properties(Constant)
        hwname = 'wavemeter';
        resolution = 0.00001; %frequency resolution in THz
    end
    properties
        timeout = 2; %timeout for attempting to read from wavemeter
    end
    properties(SetAccess=private,Hidden)
        connection
    end
    properties(SetAccess=immutable)
        readonly = false;
        Channel = 1;
    end
    methods(Static)
        function obj = instance(ip)
%             if nargin < 3
%                 interactive = true;
%             end
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Wavemeter1Ch.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal({resolvedIP},Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.Wavemeter1Ch(ip);
            obj.singleton_id = {resolvedIP};
            Objects(end+1) = obj;
        end
        
        
        stream(ip,dt)
    end
    methods(Access=private)
        function obj = Wavemeter1Ch(ip)
            obj.connection = hwserver(ip);
            % Look for existing low signals on other channels
            % Not sure if interactive input is useful for anything 
            %if interactive
            %end
            
        end
        function response = com(obj,funcname,varargin) %keep this
%             if length(funcname) >= 2 && strcmpi(funcname(1:3),'set')
%                 assert(~obj.readonly, 'Instantiated in readonly mode due to another instance using this channel.')
%             end
            response = obj.connection.com(obj.hwname,funcname,varargin{:});
        end
        function output = measure(obj,cmd)
            tstart = tic;
            output = -1; % In case obj.timeout = 0
            while toc(tstart) <= obj.timeout && output < 0
                output = obj.com(cmd,obj.Channel,0);
            end
            if output <= 0
                if output == -1
                    msg = 'Low signal';
                elseif output == -2
                    msg = 'High signal';
                else
                    msg = sprintf('Unknown error code: %g',output);
                end
                ME = MException('WAVEMETER:read','wavemeter timeout on measurement: %s',msg);
                throwAsCaller(ME);
            end
        end
    end
    methods
        function delete(obj)
             delete(obj.connection)
        end
        
        %% Measurement
        function output = getWavelength(obj)
            output = obj.measure('GetWavelengthNum');
        end
        function output = getFrequency(obj)
            output = obj.measure('GetFrequencyNum');
        end
        
        %% Global Control Settings
        function output = getPIDstatus(obj)
            % Note, this applies to all ports with ACTIVE signals
            output = obj.com('GetDeviationMode',0);
        end
        function setPIDstatus(obj,bool,override)
            % Note, this applies to all ports with ACTIVE signals
            % override is used to make sure old code/users doesn't accidentally call
            if nargin < 3 || ~override
                answer = questdlg(sprintf('%s\n%s','Are you sure you want to change PID status for all channels?',...
                    'Consider turning off just for yours using setDeviationChannel(true|false).'),...
                    mfilename,'Continue','Cancel','Cancel');
                if strcmp(answer,'Cancel')
                    return
                end
            end
            if ~obj.getDeviationChannel
                warning('DAC Channel currently disabled. Use setDeviationChannel(true) to turn on.')
            end
            bool = logical(bool);
            obj.com('SetDeviationMode',bool);
        end
        
        %% PID Set Point
        function output = getPIDtarget(obj)
            % Units are whatever is returned by getPIDunits
            eq = obj.com('GetPIDCourseNum',obj.Channel,0);
            output = str2num(eq); %#ok<ST2NM> % PIDtarget can be equations; attempt to eval
            assert(~isempty(output),sprintf('Could not evaluate PIDtarget: %s',eq));
        end
        function setPIDtarget(obj,val)
            if ~obj.getDeviationChannel
                warning('DAC Channel currently disabled. Use setDeviationChannel(true) to turn on.')
            end
            obj.com('SetPIDCourseNum',obj.Channel,num2str(val,'%0.7f')); %set with 0.1 MHz precision
        end
        function units = getPIDunits(obj)
            unit_types = {'nm','nm_air','THz','1/cm','eV'};
            units = obj.com('GetPIDSetting','cmiDeviationUnit',obj.Channel);
            units = unit_types{units.val+1};
        end
        function setPIDunits(obj,unit)
            % Unit can be a string in unit_types or an index (from 1)
            unit_types = {'nm','nm_air','THz','1/cm','eV'};
            if all(ischar(unit))
                unit = ismember(unit_types,unit);
                assert(sum(unit)==1,sprintf('%s not allowed unit: %s',unit,strjoin(unit_types,', ')));
                unit = find(unit);
            else
                assert(unit <= length(unit_types) && unit > 0,'Unit index out of range')
            end
            obj.com('SetPIDSetting','cmiDeviationUnit',obj.Channel,unit-1); % DLL indexes this from 0
        end
        
        function ClearPIDHistory(obj)
            obj.com('ClearPIDHistory',obj.Channel);
        end
        
        %% DAC Voltage
        function ch = getDeviationChannel(obj)
            % This is the "signal" for the given port (aka channel)
            % Returns true if set, false if not
            ch = obj.com('GetPIDSetting','cmiDeviationChannel',obj.Channel);
            ch = logical(ch.val);
        end
        function setDeviationChannel(obj,state)
            % This is the "signal" for the given port (aka channel)
            % Either false if not set, or true if on
            % Note this function only allows setting and removing
            if state % Keep it same as channel number
                if ~obj.getPIDstatus % If "global" PID is off, prompt to enable
                    answer = questdlg(['PID regulation is off for all signals, ',...
                        'so setting Deviation Channel will not do anything ',...
                        'unless PID regulation is enabled.',newline, newline,...
                        'Do you want to enable PID regulation now?',newline,...
                        '(note this might impact other users)'],...
                        mfilename,'Yes','No','No');
                    if strcmp(answer,'Yes')
                        obj.com('SetDeviationMode','1'); % Manually to avoid additional queries in setPIDstatus
                    else
                        warning('Note, PID regulation is off. Call setPIDstatus(true) to enable.')
                    end
                end
                obj.com('SetPIDSetting','cmiDeviationChannel',obj.Channel,obj.Channel);
            else
                obj.com('SetPIDSetting','cmiDeviationChannel',obj.Channel,0);
            end
        end
        
        function output = getDeviationVoltage(obj)
            % Output in volts
            assert(logical(obj.getDeviationChannel),'DAC signal is disabled, thus can be set but not read. Use setDeviationChannel(true) to turn on.')
            output = obj.com('GetDeviationSignalNum',obj.Channel,0)/1000;
        end
        function setDeviationVoltage(obj,volts)
            % Input in volts
            assert(~obj.getPIDstatus()||~obj.getDeviationChannel,'Cannot set while PID is enabled and channel is active.') 
            mv = round(volts*1000);
            %if (volts == 0)
            %    mv = 0;  
            %end
            obj.com('SetDeviationSignalNum',obj.Channel,mv);
        end
        
        
        %% Camera control
        function output = getExposureMode(obj)
            % true for auto exposure, false for manual
            output = obj.com('GetExposureModeNum',obj.Channel,0);
        end
        function setExposureMode(obj,bool)
            % true for auto exposure, false for manual
            bool = logical(bool);
            obj.com('SetExposureModeNum',obj.Channel,bool);     
        end
        function val = getPower(obj)
            val = obj.com('GetPowerNum',obj.Channel,0);
        end
    end
end