classdef PulseBlaster < Modules.Driver & Drivers.PulseTimer_invisible
    %PULSEBLASTER Connects with hwserver on host machine to control
    % the PulseBlaster via the interpreter program.
    % Call with the IP of the host computer (singleton based on ip)
    
    properties(Constant)
        clk = 500           % MHz?
        resolution = 2;     % ns
        minDuration = 10;   % Minimum duration in ns
        maxRepeats = 2^20;  % positive integer value
        
        hwname = 'PulseBlaster';
    end
    properties(SetAccess=private,Hidden)
        connection
        lines
    end
    properties(SetAccess=immutable)
        host = '';
    end
%     properties(SetObservable,GetObservable,AbortSet)
%         host = Prefs.String();
%     end
    
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
        function obj = PulseBlaster(ip)
            obj.host = ip;
            obj.connection = hwserver(ip);
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
        function response = com(obj, varargin)
            response = obj.connection.com(obj.hwname, varargin{:});
        end
        
        function response = start(obj)
            response = obj.com('start');
        end
        function response = stop(obj)
            response = obj.com('stop');
        end
        function response = reset(obj)
            response = obj.com('setLines')';
        end
        
        function response = load(obj, program, clock)
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
        function response = getProgram(obj)
            response = obj.com('getProgram');
        end
        
        function response = isStatic(obj)
            response = obj.com('isStatic');
        end
        function response = setAllLines(obj, lines)         % Pass a logical array
            response = obj.com('setAllLines', lines)';
        end
        function response = setLines(obj, indices, values)  % Pass a list of indices to change
            response = obj.com('setLines', indices, values)';
        end
        function response = setLine(obj, index, value)      % Pass a single index to change.
            response = obj.com('setLines', index, value)';
        end
        function response = blink(obj, indices, rate)  % Pass a list of indices to change
            s = sequence('Blink');
            s.repeat = Inf;
            
            l = getLines(obj);
            
            for ii = 1:length(l)
                ch(ii) = channel(num2str(ii), 'hardware', ii-1);    % Should unify indexing!
            end
            
            s.channelOrder = ch;
            
            n = s.StartNode;
            
            for jj = 1:2
                t = jj*1e6/rate;
                for ii = indices
                    node(n, ch(ii), 'units', 'us', 'delta', t);
                end
            end
            
            obj.load(s.compile());
            obj.start();
        end
        function response = getLines(obj)
            response = obj.com('getLines')';
        end
    end
end