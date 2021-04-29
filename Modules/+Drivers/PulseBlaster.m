classdef PulseBlaster < Modules.Driver & Drivers.PulseTimer_invisible
    %PULSEBLASTER Connects with hwserver on host machine to control
    % the PulseBlaster via the interpreter program.
    % Call with the IP of the host computer (singleton based on ip)

    properties(Constant)
        clk = 500           % MHz
        resolution = 2;     % ns
        minDuration = 10;   % Minimum duration in ns
        maxRepeats = 2^20;  % positive integer value

        hwname = 'PulseBlaster';
    end
    properties(SetAccess=private,Hidden)
        connection
        lines                   % Array of `Drivers.PulseBlaster.Line`s with staticLines state stored in the pref "state".
        linesEnabled = true;    % Used for updating lines. If false, lines will not try to (slowly) talk with the PB.
    end
    properties(SetAccess=immutable)
        host = '';
    end

    methods(Static)
        function obj = instance(host_ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PulseBlaster.empty(1,0);
            end
            [~,host_resolved] = resolvehost(host_ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(host_resolved, Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PulseBlaster(host_ip);
            obj.singleton_id = host_resolved;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = PulseBlaster(host_)
            obj.host = host_;
            try
                obj.connection = hwserver(host_);
            catch err
                warning([   'Could not connect to an instance of hwserver at host "' host_ '". ' ...
                            'Are you sure hwserver is installed there? The hwserver repository is ' ...
                            'located at https://github.mit.edu/mpwalsh/hwserver/.']);
                rethrow(err);
            end
            obj.spawnLines();
        end
        function spawnLines(obj)                            % Spawns Drivers.PulseBlaster.Line objects mapping to hardware PulseBlaster lines.
            state = obj.getLines();

            for ii = 1:length(state)    % Eventually, have a system to only initialize certain lines (based on a pref) and to name them.
                obj.lines = [obj.lines Drivers.PulseBlaster.Line.instance(obj, ii)];
            end
        end
        function updateLines(obj, state)                    % Updates the state of the Drivers.PulseBlaster.Line objects with the state of the Drivers.PulseBlaster
            if nargin == 1
                state = obj.getLines();
            end

            obj.linesEnabled = false;
            
            if ~isempty(obj.lines)
                for ii = 1:length(state)
                    if isnumeric(obj.lines(ii).state)           % Avoid disturbing mid-pref-switch.
                        obj.lines(ii).state = state(ii);        % Update state without communicating with hardware.
                    end
                end
            end

            obj.linesEnabled = true;
        end
    end
    methods
        function delete(obj)
            delete(obj.lines);
            delete(obj.connection);
        end
        function response = com(obj, varargin)              % Communication helper function.
            response = obj.connection.com(obj.hwname, varargin{:});
        end

        function response = start(obj)                      % Start the currently-loaded program.
            response = obj.com('start');
        end
        function response = stop(obj)                       % Stop the currently-loaded program. Does not revert to staticLines state.
            response = obj.com('stop');
        end
        function state = reset(obj)                         % Reset to staticLines mode.
            if ~obj.isStatic
                state = obj.com('setLines')';               % setLines without arguments sets to staticLines mode.
            else
                state = obj.com('getLines')';
            end

            obj.updateLines(state)
        end

        function response = load(obj, program, clock)       % Load a program.
            if iscell(program)  % Process cell array of strings for backwards compatibility.
                program = strjoin(program, newline);
            end

            assert(ischar(program))
            assert(~isempty(program))

            if nargin == 2
                response = obj.com('load', program);
            else
                assert(clock > 0)
                response = obj.com('load', program, clock);
            end

            obj.updateLines(NaN(1,length(obj.lines)));
        end
        function response = getProgram(obj)                 % Get the currently-loaed program (text form).
            response = obj.com('getProgram');
        end

        function tf = isStatic(obj)                         % Whether we are currently in staticLines mode.
            tf = obj.com('isStatic');
        end
        function state = setAllLines(obj, state)            % Pass a logical array of the desired state of the lines. This will stop a currently-running program and revert to staticLines state.
            state = obj.com('setAllLines', state)';
            obj.updateLines(state);
        end
        function state = setLines(obj, indices, values)     % Pass a list of line indices to change values. This will stop a currently-running program and revert to staticLines state.
            state = obj.com('setLines', indices, values)';
            obj.updateLines(state);
        end
        function response = blink(obj, indices, rate)       % Blinks the listed lines in `indices` at `rate` Hz. Useful for debugging!
            s = sequence('Blink');
            s.repeat = Inf;

            l = getLines(obj);

            for ii = 1:length(l)
                ch(ii) = channel(num2str(ii), 'hardware', ii-1);    %#ok<AGROW> % Should unify indexing!
            end

            s.channelOrder = ch;

            n = s.StartNode;

            for jj = 1:2
                t = jj*1e6/rate/2;
                for ii = indices
                    node(n, ch(ii), 'units', 'us', 'delta', t);
                end
            end

            response = obj.load(s.compile());
            obj.start();

            delete(s);
        end

        function state = getLines(obj)                      % Get state of staticLines. All NaN if a program is running.
            state = obj.com('getLines')';
            obj.updateLines(state);
        end
    end
end
