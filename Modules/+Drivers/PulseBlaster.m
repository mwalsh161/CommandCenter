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
        lines               % Array of `Drivers.PulseBlaster.Line`s with state stored in the pref "state".
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
        function spawnLines(obj)
            state = obj.getLines();
            
            for ii = 1:length(state)    % Eventually, have a system to only initialize certain lines (based on a pref) and to name them.
                obj.lines = [obj.lines Drivers.PulseBlaster.Line.instance(obj, ii)];
            end
        end
        function killLines(obj)
            delete(obj.lines);
        end
    end
    methods
        function delete(obj)
            obj.killLines();
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
        function response = reset(obj)                      % Reset to staticLines mode.
            if ~obj.isStatic
                response = obj.com('setLines')';
            else
                response = obj.com('getLines')';
            end
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
        end
        function response = getProgram(obj)                 % Get the currently-loaed program (text form).
            response = obj.com('getProgram');
        end
        
        function response = isStatic(obj)                   % Whether we are currently in staticLines mode.
            response = obj.com('isStatic');
        end
        function response = setAllLines(obj, lines)         % Pass a logical array of the desired state of the lines. This will stop a currently-running program and revert to staticLines state.
            response = obj.com('setAllLines', lines)';
        end
        function response = setLines(obj, indices, values)  % Pass a list of line indices to change values. This will stop a currently-running program and revert to staticLines state.
            response = obj.com('setLines', indices, values)';
        end 
        function response = getLines(obj)                   % Get state of staticLines. All NaN if a program is running.
            response = obj.com('getLines')';
        end
    end
end
