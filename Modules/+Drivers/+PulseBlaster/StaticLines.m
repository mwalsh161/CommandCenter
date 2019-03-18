classdef StaticLines < Modules.Driver
    %STATICLINES Control all chanels of pulseblaster
    %   StaticLines(host_ip); % Default interactive = true
    %   StaticLines(__,interactive)
    %
    %   Creates a continuous loop with the correct channel values.
    %   Does not use a stop command, so it is clear when something else
    %   tries to take over.
    %
    %   Set the lines(index) of the line you want to 0 for off and 1 for
    %   on.
    %
    %   If interactive is true, will prompt user to reset another client's
    %   connection if needed
    
    properties
        lines = zeros(1,21);    % State of each HW channel when running (meaningless if not running)
    end
    properties(SetObservable,SetAccess=private,AbortSet)
        running = 0;
    end
    properties(SetAccess=immutable,Hidden)
        HW                      % Handle to PulseBlaster driver
    end
    
    methods(Static)
        function obj = instance(host_ip,interactive)
            if nargin < 2
                interactive = true;
            end
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PulseBlaster.StaticLines.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(host_ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(resolvedIP,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PulseBlaster.StaticLines(host_ip,interactive);
            obj.singleton_id = resolvedIP;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = StaticLines(host_ip,interactive)
            obj.HW = Drivers.PulseBlaster.Remote.instance(host_ip);
            addlistener(obj.HW,'ObjectBeingDestroyed',@(~,~)obj.delete);
            addlistener(obj.HW,'running','PostSet',@(~,~)obj.updateRunning);
            try
                obj.HW.open;
            catch err
                if interactive && contains(err.message,'Another client is in session')
                    response = questdlg(err.message,mfilename,'Reset','Cancel','Cancel');
                    if strcmp(response,'Reset')
                        obj.HW.reset;
                        obj.HW.open;
                    else
                        error('Aborting construction due to another user in session.');
                    end
                else
                    rethrow(err);
                end
            end
            obj.start;
        end
    end
    methods
        function delete(obj)
            if obj.running % If the StaticLines are running, stop them.
                obj.HW.stop;
                obj.HW.close;
            end
        end
        function abort(obj)
            obj.running = false;
            obj.HW.stop;
        end
        function start(obj)
            flags = num2str(fliplr(obj.lines),'%i');
            instructions = {sprintf('START: 0b %s, 100 ms',flags),...
                            sprintf('       0b %s, 100 ms, BRANCH, START',flags)};
            try
                obj.HW.load(instructions);
            catch err  % Attempt to re-open connection once if server restarted
                if ~strcmp(err.message,'Client has not started a session.')
                    rethrow(err)
                end
                obj.HW.open;  % This will error if another client is using, which is a good error to throw
                obj.HW.load(instructions);
            end
            obj.HW.start;
            obj.running = true;
        end
        function set.lines(obj,val)
            if numel(val) == 1;
                obj.lines = ones(1,numel(obj.lines))*val;
            elseif numel(val) == 21
                obj.lines = val;
            else
                error('Lines must be set individually or all 21 specified.')
            end
            obj.start;
        end
        % Callbacks
        function updateRunning(obj)
            obj.running = strcmp(mfilename('class'),obj.HW.running);
        end
    end
end

