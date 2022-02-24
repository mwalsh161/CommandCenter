classdef stage < Modules.Driver
    %GALVOS Control Galvo position and perform scans (3 dimensions)
    %   4 Lines are necessary to perform scans
    %       digital APD input  - collects n+1 samples to display the difference of them (making it n samples)
    %       Analog Output for a galvo - outputs n samples then resets voltage to what it was before starting.
    %       Analog Output for the other galvo
    %       Digital Output for th external sync line - outputs n+1 periods
    %
    %   Triggering occurs on the rising edge.
    %   Data is stored in the nidaq until StreamToImage is called.  This
    %   function also cleans up tasks. One downside of this is resources on
    %   the nidaq aren't free until data is read and tasks cleaned up.
    %
    %   Error handling is left to nidaq.
    
    properties
        zigzag = true;      % Zig-zag when scanning
    end
    properties(Constant)
        min_dwell = 0.1;    % ms
    end
    properties(SetAccess=private,SetObservable,AbortSet)
        voltage = [0 0 0];    % [x,y,z] voltages
        moving = false;
    end
    properties(SetAccess=private,Hidden)
        xVals               % x votlage values in scan that has been set
        yVals               % y voltage values in scan that has been set
        VoltBeforeScan      % Voltage before scan, so we can restore at end
        taskScan            % Task handle to scan voltage out
        taskPulseTrain      % Task to control timing
        taskCounter         % Task to control counter
        listeners
        dwell               % ms. Used to update counts to cps
    end
    properties(SetAccess=immutable)
        nidaq           % NIDAQ handle
        x_line          % Name of x line on NIDAQ
        y_line          % Name of y line on NIDAQ
        z_line          % Name of z line on NIDAQ
        ext_sync        % Name of external sync line (pulsetrain)
        count_in        % Name of counter input line
    end
    
    methods(Access=protected)
        function obj = stage(x_line, y_line,z_line,count_in,ext_sync)
            obj.x_line = x_line;
            obj.y_line = y_line;
            obj.z_line = z_line;
            obj.ext_sync = ext_sync;
            obj.count_in = count_in;
            obj.nidaq = Drivers.NIDAQ.dev.instance('Dev1');
            % Check that lines exist, if not open nidaq view
            lines = {x_line,y_line,z_line,ext_sync,count_in};
            types = {'out','out','out','out','in'};
            msg = {};
            for i = 1:numel(lines)
                try
                    if ~isempty(lines{i})
                        lines{i} = obj.nidaq.getLines(lines{i},types{i});
                        if strcmp(lines{i}.type,'digital') && strcmp(types{i},'out')
                            if isempty(obj.listeners)
                                obj.listeners = addlistener(lines{i},'state','PostSet',@obj.VoltageChange);
                            else
                                obj.listeners(end+1) = addlistener(lines{i},'state','PostSet',@obj.VoltageChange);
                            end
                        end
                    end
                catch err
                    msg{end+1} = err.message;
                end
            end
            if ~isempty(msg)
                obj.nidaq.view;
                error('Add lines below, and load again.\n%s',strjoin(msg,'\n'))
            end
        end
        function clear_tasks(obj)
            obj.taskScan.Clear;
            obj.taskCounter.Clear;
            obj.taskPulseTrain.Clear;
            obj.SetCursor(obj.VoltBeforeScan(1),obj.VoltBeforeScan(2),obj.VoltBeforeScan(3));
        end
    end
    methods(Static)
        function obj = instance(x_line, y_line,z_line,count_in,ext_sync)
            mlock;
            id = {x_line, y_line,z_line,count_in,ext_sync};
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.NIDAQ.stage.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(id,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.NIDAQ.stage(x_line,y_line,z_line,count_in,ext_sync);
            obj.singleton_id = id;
            Objects(end+1) = obj;
        end
    end
    methods
        function delete(obj)
            for i = 1:numel(obj.listeners)
                if isvalid(obj.listeners(i))
                    delete(obj.listeners(i))
                end
            end
        end
        function set.zigzag(obj,val)
            obj.zigzag = boolean(val);
        end
        function val = get.voltage(obj)
            val = NaN(1,3);
            if ~isempty(obj.x_line)
                line = obj.nidaq.getLines(obj.x_line,'out');
                val(1) = line.state;
            end
            if ~isempty(obj.y_line)
                line = obj.nidaq.getLines(obj.y_line,'out');
                val(2) = line.state;
            end
            if ~isempty(obj.z_line)
                line = obj.nidaq.getLines(obj.z_line,'out');
                val(3) = line.state;
            end
        end
        
        function VoltageChange(obj,varargin)
            % obj.moving is listened to by CC, so this notifies CC to query
            % the position because it has moved.
            obj.moving = true;
            obj.moving = false;
        end
        function SetCursor(obj,x,y,z)
            err = [];
            assert(~obj.moving,'Galvos are currently moving!')
            lines = {obj.x_line,obj.y_line,obj.z_line};
            if nargin < 4
                z = [];
            end
            if isempty(z) || isempty(obj.z_line) || isnan(z)
                lines(3) = [];
                z = [];
            end
            if isempty(y) || isempty(obj.y_line) || isnan(y)
                lines(2) = [];
                y = [];
            end
            if isempty(x) || isempty(obj.x_line) || isnan(x)
                lines(1) = [];
                x = [];
            end
            if ~isempty(lines)
                obj.moving = true;
                try
                    obj.nidaq.WriteAOLines(lines,[x y z]);
                catch err
                end
                obj.moving = false;
                if ~isempty(err)
                    rethrow(err)
                end
            end
        end
        
        %% Scanning methods
        function SetupScanVoltage(obj,xVals,yVals,dwellTime)
            % Takes array of xVals and yVals then re-organizes and loads to NIDAQ
            % dwellTime should be in ms
            % NIDAQ will be ready to trigger at StartScan
            if ~isempty(xVals)
                assert(~isempty(obj.x_line),'Trying to setup 1D scan on x axis, but no line defined.')
            end
            if ~isempty(yVals)
                assert(~isempty(obj.y_line),'Trying to setup 1D scan on y axis, but no line defined.')
            end
            assert(~isempty(yVals)||~isempty(xVals),'No voltages supplied!')
            if dwellTime < obj.min_dwell
                dwellTime = obj.min_dwell;
                warning('Tried to set a dwell of %0.1f, which is less than the min_dwell of %0.1f. Set to minimum.',dwellTime,obj.min_dwell)
            end
            dwellTime = dwellTime/1000;  % ms to s
            obj.xVals = xVals;
            obj.yVals = yVals;
            numpoints = max(length(xVals),1)*max(length(yVals),1);  % If ignoring a line, we still need to keep numpoints nonzero!
            voltages = zeros(numpoints,~isempty(xVals)+~isempty(yVals)); % Second dimension determined by number of non-empty axes
            for i = 1:numel(yVals)
                for j = 1:numel(xVals)
                    if mod(i,2) || ~obj.zigzag
                        % Increasing Vx, Vy
                        voltages((i-1)*length(xVals)+j,:) = [xVals(j) yVals(i)];
                    else
                        % Decreasing Vx, Vy
                        voltages((i-1)*length(xVals)+j,:) = [xVals(end-j+1) yVals(i)];
                    end
                end
            end
            % Set Pulse Train
            obj.taskPulseTrain = obj.nidaq.CreateTask('GalvoPulseTrain');
            obj.dwell = dwellTime;
            freq = 1/dwellTime;
            try
                obj.taskPulseTrain.ConfigurePulseTrainOut(obj.ext_sync,freq,numpoints+1);
            catch err
                obj.taskPulseTrain.Clear
                rethrow(err)
            end
            % Set Voltage out to galvos
            obj.taskScan = obj.nidaq.CreateTask('GalvoScan');
            try
                if isempty(xVals)
                	obj.taskScan.ConfigureVoltageOut({obj.y_line},voltages,obj.taskPulseTrain);
                elseif isempty(yVals)
                    obj.taskScan.ConfigureVoltageOut({obj.x_line},voltages,obj.taskPulseTrain);
                else
                    obj.taskScan.ConfigureVoltageOut({obj.x_line,obj.y_line},voltages,obj.taskPulseTrain);
                end
            catch err
                obj.taskPulseTrain.Clear
                obj.taskScan.Clear
                rethrow(err)
            end
            % Set Counter from APD
            obj.taskCounter = obj.nidaq.CreateTask('GalvoCounter');
            try
                %obj.taskCounter.ConfigureCounterIn(obj.count_in,numpoints+1,obj.taskPulseTrain);
                obj.taskCounter.ConfigureVoltageIn(obj.count_in,obj.taskPulseTrain,numpoints+1);
            catch err
                obj.taskPulseTrain.Clear
                obj.taskScan.Clear
                obj.taskCounter.Clear
                rethrow(err)
            end
            addlistener(obj.taskScan,'status','PostSet',@obj.TaskUpdated);
        end
        function StartScanVoltage(obj)
            assert(isvalid(obj.taskPulseTrain),'No scan setup!')
            % Arm output/data lines
            obj.VoltBeforeScan = obj.voltage;
            obj.taskCounter.Start;
            obj.taskScan.Start;
            % Trigger to go!
            obj.taskPulseTrain.Start;
        end
        function StreamToImageVoltage(obj,imObj)
            assert(isvalid(imObj),'Invalid imObj handle')
            assert(~isempty(obj.taskPulseTrain)&&isobject(obj.taskPulseTrain)&&isvalid(obj.taskPulseTrain),'No scan setup!')
            numpoints = max(length(obj.xVals),1)*max(length(obj.yVals),1);
            CounterRawData = NaN(numpoints+1,1);
            ydat = linspace(imObj.YData(1),imObj.YData(end),size(imObj.CData,1));
            tracker = line(imObj.Parent,imObj.XData([1 end]),NaN(1,2),'color','g');
            ii = 0;
            while isvalid(obj.taskCounter)&&(~obj.taskCounter.IsTaskDone || obj.taskCounter.AvailableSamples)
                SampsAvail = obj.taskCounter.AvailableSamples;
                % Change to counts per second
                %counts = obj.taskCounter.ReadCounter(SampsAvail);
                counts = obj.taskCounter.ReadVoltageIn(SampsAvail);
                CounterRawData(ii+1:ii+SampsAvail) = counts;
                ImageData = reshape(CounterRawData(2:end),[max(length(obj.xVals),1),max(length(obj.yVals),1)])';
                ii = ii + SampsAvail;
                % Adjust for zig zag scan
                for row = 1:size(ImageData,1)
                    if ~mod(row,2) && obj.zigzag
                        ImageData(row,:)=fliplr(ImageData(row,:));
                    end
                end
                mask = ~isnan(ImageData);
                imObj.CData(mask) = ImageData(mask); % Only update new data
                yloc = find(any(~mask,2),1);
                if ~isempty(yloc)
                    tracker.YData = [0 0] + ydat(yloc);
                end
                drawnow;
            end
            delete(tracker);
            if ~isvalid(obj.taskCounter)
                return
            end
            % Wait for pulse train to complete, then clean up.
            obj.taskPulseTrain.WaitUntilTaskDone;
            obj.clear_tasks;
        end
        %%%%%
        function SetupScan(obj,xVals,yVals,dwellTime)
            % Takes array of xVals and yVals then re-organizes and loads to NIDAQ
            % dwellTime should be in ms
            % NIDAQ will be ready to trigger at StartScan
            if ~isempty(xVals)
                assert(~isempty(obj.x_line),'Trying to setup 1D scan on x axis, but no line defined.')
            end
            if ~isempty(yVals)
                assert(~isempty(obj.y_line),'Trying to setup 1D scan on y axis, but no line defined.')
            end
            assert(~isempty(yVals)||~isempty(xVals),'No voltages supplied!')
            if dwellTime < obj.min_dwell
                dwellTime = obj.min_dwell;
                warning('Tried to set a dwell of %0.1f, which is less than the min_dwell of %0.1f. Set to minimum.',dwellTime,obj.min_dwell)
            end
            dwellTime = dwellTime/1000;  % ms to s
            obj.xVals = xVals;
            obj.yVals = yVals;
            numpoints = max(length(xVals),1)*max(length(yVals),1);  % If ignoring a line, we still need to keep numpoints nonzero!
            voltages = zeros(numpoints,~isempty(xVals)+~isempty(yVals)); % Second dimension determined by number of non-empty axes
            for i = 1:numel(yVals)
                for j = 1:numel(xVals)
                    if mod(i,2) || ~obj.zigzag
                        % Increasing Vx, Vy
                        voltages((i-1)*length(xVals)+j,:) = [xVals(j) yVals(i)];
                    else
                        % Decreasing Vx, Vy
                        voltages((i-1)*length(xVals)+j,:) = [xVals(end-j+1) yVals(i)];
                    end
                end
            end
            % Set Pulse Train
            obj.taskPulseTrain = obj.nidaq.CreateTask('GalvoPulseTrain');
            obj.dwell = dwellTime;
            freq = 1/dwellTime;
            try
                obj.taskPulseTrain.ConfigurePulseTrainOut(obj.ext_sync,freq,numpoints+1);
            catch err
                obj.taskPulseTrain.Clear
                rethrow(err)
            end
            % Set Voltage out to galvos
            obj.taskScan = obj.nidaq.CreateTask('GalvoScan');
            try
                if isempty(xVals)
                	obj.taskScan.ConfigureVoltageOut({obj.y_line},voltages,obj.taskPulseTrain);
                elseif isempty(yVals)
                    obj.taskScan.ConfigureVoltageOut({obj.x_line},voltages,obj.taskPulseTrain);
                else
                    obj.taskScan.ConfigureVoltageOut({obj.x_line,obj.y_line},voltages,obj.taskPulseTrain);
                end
            catch err
                obj.taskPulseTrain.Clear
                obj.taskScan.Clear
                rethrow(err)
            end
            % Set Counter from APD
            obj.taskCounter = obj.nidaq.CreateTask('GalvoCounter');
            try
                obj.taskCounter.ConfigureCounterIn(obj.count_in,numpoints+1,obj.taskPulseTrain);
            catch err
                obj.taskPulseTrain.Clear
                obj.taskScan.Clear
                obj.taskCounter.Clear
                rethrow(err)
            end
            addlistener(obj.taskScan,'status','PostSet',@obj.TaskUpdated);
        end
        function StartScan(obj)
            assert(isvalid(obj.taskPulseTrain),'No scan setup!')
            % Arm output/data lines
            obj.VoltBeforeScan = obj.voltage;
            obj.taskCounter.Start;
            obj.taskScan.Start;
            % Trigger to go!
            obj.taskPulseTrain.Start;
        end
        function TaskUpdated(obj,varargin)
            if ~strcmpi(obj.taskScan.status,'Started')
                obj.moving = false;
            else
                obj.moving = true;
            end
        end
        function StreamToImage(obj,imObj)
            assert(isvalid(imObj),'Invalid imObj handle')
            assert(~isempty(obj.taskPulseTrain)&&isobject(obj.taskPulseTrain)&&isvalid(obj.taskPulseTrain),'No scan setup!')
            numpoints = max(length(obj.xVals),1)*max(length(obj.yVals),1);
            CounterRawData = NaN(numpoints+1,1);
            ydat = linspace(imObj.YData(1),imObj.YData(end),size(imObj.CData,1));
            tracker = line(imObj.Parent,imObj.XData([1 end]),NaN(1,2),'color','g');
            ii = 0;
            while isvalid(obj.taskCounter)&&(~obj.taskCounter.IsTaskDone || obj.taskCounter.AvailableSamples)
                SampsAvail = obj.taskCounter.AvailableSamples;
                % Change to counts per second
                counts = obj.taskCounter.ReadCounter(SampsAvail);
                CounterRawData(ii+1:ii+SampsAvail) = counts;
                ImageData = reshape(diff(CounterRawData),[max(length(obj.xVals),1),max(length(obj.yVals),1)])';
                ii = ii + SampsAvail;
                % Adjust for zig zag scan
                for row = 1:size(ImageData,1)
                    if ~mod(row,2) && obj.zigzag
                        ImageData(row,:)=fliplr(ImageData(row,:));
                    end
                end
                mask = ~isnan(ImageData);
                imObj.CData(mask) = ImageData(mask); % Only update new data
                yloc = find(any(~mask,2),1);
                if ~isempty(yloc)
                    tracker.YData = [0 0] + ydat(yloc);
                end
                drawnow;
            end
            delete(tracker);
            if ~isvalid(obj.taskCounter)
                return
            end
            % Wait for pulse train to complete, then clean up.
            obj.taskPulseTrain.WaitUntilTaskDone;
            obj.clear_tasks;
        end
        function AbortScan(obj)
            assert(strcmp(obj.taskPulseTrain.status,'Started'),'Scan is not running')
            obj.clear_tasks;
        end
    end
end