classdef dev < Modules.Driver
    % Matlab Object Class implementing control for National Instruments
    % Digital Acquistion Card. Only voltage implemented, no current.
    %
    % Primary purpose of this is to create tasks and lines and manage the
    % GUI.  Other task based control is in Drivers.NIDAQ.task
    %
    % Singleton based on DeviceChannel
    %
    % All task control is in the task object returned by dev.
    %
    % Typical Work Flow for reading
    %                 0. Initialize lines*
    %    1. Create a task          1. Quick Read/Write
    %    2. Configure task
    %        b. Add Lines
    %        a. Configure Timing
    %    4. Start Task
    %    5. Clean up
    % *Only needs to be done once
    %
    % obj.view starts the GUI to help manage lines. Clearing the obj will
    % not delete it while the GUI exists. Use delete(obj) to be sure.
    %
    % Note that the counter uses implicit timing, so it requires a separate
    % pulse train task (task that has ConfigurePulseTrainOut called with
    % it).  This allows multiple things to be synced to the pulse train.
    %
    % One instance controls 1 physical device. Multiple instances can exist
    % simultaneously for different hardware channels. If you need two
    % devices to work together, a new class should be designed.
    %
    % Depending on how the C libraries are written, this could produce
    % many warnings because loadlibrary does not recognize '...' in the
    % header file. Edit the prototype file (not header file) and use it
    % instead to fix these warnings. Eliminating unused functions will
    % decrease load time.
    %
    % To see what function from the dll are loaded - look through the
    % nidaqmxprototype.m
    % If you wish to add functions - search through the
    % full_list_functions.m and copy them to nidaqmxprototype.m
    %
    % Inspired from code by: Jonathan Hodges, jhodges@mit.edu, (2009)

    properties
        ReadTimeout = 10;                    % Timeout for a read operation (sec)
        WriteTimeout = 10;                   % Timeout for a write operation (sec)
        DefaultDutyCycle = 0.5;             % If no duty cycle specified, will use this (0 - 1)
    end
    properties(SetAccess=private,SetObservable)
        OutLines = Drivers.NIDAQ.out.empty(1,0);
        InLines = Drivers.NIDAQ.in.empty(1,0);
    end
    properties(SetAccess={?Drivers.NIDAQ.task},SetObservable)
        Tasks = Drivers.NIDAQ.task.empty(1,0);
        CurrentTask = NaN;                  % Task object that called last LibFunction for error handling
    end
    properties(SetAccess=private)
        AvailCounters = {'Ctr0','Ctr1','Ctr2','Ctr3'};
    end
    properties(Access=private)
        GUI
    end
    properties (SetAccess=immutable)
        DeviceChannel                       % device handle from MAX, eg. Dev1, Dev2, etc
    end
    properties (SetAccess=immutable,GetAccess=protected)
        init_error = true;                  % used to unload library if loaded
        load_error = true;                  % Prevent saving partially loaded lines
        init_warnings;                      % just informative
        namespace_dev
    end

    properties(Constant,Hidden)
        % constants for NI USB-6343
        numAIchannels  = 32;                % 16 bit resolution, 500kS/s
        numAOchannels  = 4;                 % 16 bit resolution
        numDIOchannels = 48;
        numCLKchannels = 4;                 % 32 bit counters/timers
        AnalogOutMaxVoltage = 10;
        AnalogOutMinVoltage = -10;
        AnalogInMaxVoltage = 10;
        AnalogInMinVoltage = -10;
        Counters = {'Ctr0','Ctr1','Ctr2','Ctr3'};

        % constants for C library
        LibraryName = 'nidaqmx';            % alias for library
        LibraryFilePath = 'nicaiu.dll';     % Path to dll
        DAQmx_Val_Volts =  10348;
        DAQmx_Val_Rising = 10280;           % Rising
        DAQmx_Val_Falling =10171;           % Falling
        DAQmx_Val_CountUp =10128;           % Count Up
        DAQmx_Val_CountDown =10124;         % Count Down
        DAQmx_Val_ExtControlled =10326;     % Externally Controlled
        DAQmx_Val_Hz = 10373;               % Hz
        DAQmx_Val_Low =10214;               % Low
        DAQmx_Val_ContSamps =10123;         % Continuous Samples
        DAQmx_Val_GroupByChannel = 0;
        DAQmx_Val_Cfg_Default = int32(-1);
        DAQmx_Val_FiniteSamps =10178;       % Finite Samples
        DAQmx_Val_Auto = -1;
        DAQmx_Val_WaitInfinitely = -1.0     % Value for the Timeout parameter of DAQmxWaitUntilTaskDone
        DAQmx_Val_Ticks =10304;
        DAQmx_Val_Seconds =10364;
        DAQmx_Val_ChanPerLine = 0;
        DAQmx_Val_ChanForAllLines = 1;
        DAQmx_Val_Task_Verify = 2;
        DAQmx_Val_Task_Abort = 6;
        DAQmx_Val_ActiveDrive = 12573;      % Digital output 0:GND 1:+V [default]
        DAQmx_Val_OpenCollector = 12574;    % Digital output 0:GND 1:high-impedance
        DAQmx_Val_AllowRegen = 10097;       % Buffered writes: keep FIFO (allows restarting task)
        DAQmx_Val_DoNotAllowRegen = 10158;  % Buffered writes: clear FIFO
        DAQmx_Val_FirstSample = 10424;      % For AllowRegen mode (start over)
    end

    methods(Static)
        function obj = instance(DeviceChannel)
            mlock;
            DeviceChannel = lower(DeviceChannel);
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.NIDAQ.dev.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && strcmpi(DeviceChannel,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.NIDAQ.dev(DeviceChannel);
            obj.singleton_id = DeviceChannel;
            Objects(end+1) = obj;
        end
        function [line,mask] = getLine(name,line_type)
%             name
%             line_type
            names = {line_type.name};
            mask = strcmp(names,name);
            if sum(mask) == 1
                line = line_type(mask);
                return
            elseif sum(mask) > 1
                error('Found multiple lines with name "%s"!',name)
            elseif sum(mask) == 0
                error('No line with name "%s".',name)
            end
        end
    end
    
    % Base methods
    methods(Access={?Drivers.NIDAQ.dev,?Drivers.NIDAQ.task})
        function obj = dev(DeviceChannel)
            obj.DeviceChannel = DeviceChannel;
            if  ~libisloaded(obj.LibraryName)
                if strcmp(computer,'PCWIN') % 32 bit
                    proto = @obj.nidaqmxprototype32;
                    path = fullfile(fileparts(mfilename('fullpath')),obj.LibraryFilePath);
                else                        % 64 bit
                    proto = @obj.nidaqmxprototype;
                    path = obj.LibraryFilePath;
                end
                [~,obj.init_warnings] = loadlibrary(path,proto,'alias',obj.LibraryName);
            end
            obj.SelfTest();
            obj.init_error = false;
            obj.namespace_dev = [obj.namespace '_' DeviceChannel];
            % Initialize lines from last time
            if ispref(obj.namespace_dev,'OutLines')
                p = getpref(obj.namespace_dev,'OutLines');
                for i = 1:numel(p)
                    line = p(i);
                    obj.addOutLine(line.line,line.name,line.limits,line.state);
                end
            end
            if ispref(obj.namespace_dev,'InLines')
                p = getpref(obj.namespace_dev,'InLines');
                for i = 1:numel(p)
                    line = p(i);
                    obj.addInLine(line.line,line.name);
                end
            end
            obj.load_error = false;
        end
        function [obj] = CheckErrorStatus(obj,ErrorCode)
            if(ErrorCode ~= 0)
                BufferSize = 0;
                [BufferSize] = calllib(obj.LibraryName,'DAQmxGetExtendedErrorInfo',[],BufferSize);
                if BufferSize < 0
                    obj.CheckErrorStatus(BufferSize);
                end
                % create a string of spaces
                ExtendedString = char(32*ones(1,BufferSize));
                % now get the actual string
                [~,ExtendedString] = calllib(obj.LibraryName,'DAQmxGetExtendedErrorInfo',ExtendedString,BufferSize);
                if isa(obj.CurrentTask,'Drivers.NIDAQ.task')
                    % Fill in task name if possible and necessary
                    expression = ': (\w*)<(\w*)>';
                    ExtendedString=regexprep(ExtendedString,expression,[': ' obj.CurrentTask.name]);
                end
                if ErrorCode < 0
                    error(['NIDAQ_Driver!! -- ',ExtendedString]);
                elseif ErrorCode > 0
                    warning(['NIDAQ_Driver!! -- ',ExtendedString]);
                end
            end
        end
        function ctr = getAvailCtr(obj,name)
            if nargin < 2
                name = 'Default Counter';
            end
            if isempty(obj.AvailCounters)
                error('No available counters; clear tasks that have counters')
            end
            % Get the next available counter
            ctr = obj.AvailCounters{1};
            % Remove it from the counter list
            obj.AvailCounters(1) = [];
            ctr = Drivers.NIDAQ.out(obj,ctr,name);
        end
        function returnCtr(obj,ctr)
            % Make sure this is a counter and is not already present
            line = ctr.line(end-3:end);
            if ~sum(find(strcmpi(obj.Counters,line)))
                error('%s is not a valid counter!',line)
            elseif sum(find(strcmpi(obj.AvailCounters,line)))
                warning('%s was already available')
            else
                % Add to the end of counters list
                obj.AvailCounters{end+1} = line;
            end
            delete(ctr)
        end
    end
    
    % Pref handler methods (overwrites Module methods)
    methods
        function varargout = addlistener(obj,varargin)
            % el = addlistener(hSource,EventName,callback)
            % el = addlistener(hSource,PropertyName,EventName,callback)
            varargout = {};
            if nargin == 4 && isfield(obj.external_ls,varargin{1}) % externals_ls field names are all pref properties
                el = Base.PrefListener(obj,varargin{:});
                obj.external_ls.(varargin{1}).(varargin{2})(end+1) = el;
                addlistener(el,'ObjectBeingDestroyed',@obj.preflistener_deleted);
            else
                el = addlistener@handle(obj,varargin{:});
                el = Base.PrefListener(el); % Wrap it to make array compatible
            end
            if nargout
                varargout = {el};
            end
        end
    end
    
    % view() methods
    methods(Access={?Drivers.NIDAQ.dev,?Drivers.NIDAQ.in,?Drivers.NIDAQ.out,?Drivers.NIDAQ.task,?timer})
        %% View callbacks
        function close(obj,varargin)
            % Remove listeners
            try
                for i = 1:numel(obj.OutLines)
                    line = obj.OutLines(i);
                    delete(line.niListener)
                    line.niListener = [];
                end
            catch
            end
            try
                for i = 1:numel(obj.Tasks)
                    task = obj.Tasks(i);
                    delete(task.niListener)
                    task.niListener = [];
                end
            catch
            end
            delete(obj.GUI.listeners)
            % Close out GUI
            delete(obj.GUI.fig)
            obj.GUI = [];
        end
        % Listener Callbacks (should use drawnow)
        function RefreshTasks(obj,varargin)
            Strings = cell(1,numel(obj.Tasks));
            for i = 1:numel(obj.Tasks)
                Strings{i} = obj.Tasks(i).text;
            end
            set(obj.GUI.tasks,'String',Strings)
            drawnow;
        end
        function RefreshLines(obj,varargin)
            inLines = cell(size(obj.InLines));
            for i = 1:length(obj.InLines)
                inLines{i} = obj.InLines(i).text;
            end
            if ~get(obj.GUI.InLines,'Value')
                set(obj.GUI.InLines,'Value',1)
            end
            set(obj.GUI.InLines,'String',inLines)

            outLines = cell(size(obj.OutLines));
            for i = 1:length(obj.OutLines)
                outLines{i} = obj.OutLines(i).text;
            end
            if ~get(obj.GUI.OutLines,'Value')
                set(obj.GUI.OutLines,'Value',1)
            end
            set(obj.GUI.OutLines,'String',outLines)
            drawnow;
        end
        function UpdateLine(obj,~,eventData)
            % Update state of output (same order as obj.OutLines)
            src = eventData.AffectedObject;
            Lines = get(obj.GUI.OutLines,'String');
            mask = obj.OutLines == src;
            if sum(mask)
                Lines{mask} = src.text;
                set(obj.GUI.OutLines,'String',Lines)
                drawnow;
            end
        end
        function UpdateTask(obj,~,eventData)
            src = eventData.AffectedObject;
            TaskStrs = get(obj.GUI.tasks,'String');
            mask = obj.Tasks == src;
            if sum(mask)
                TaskStrs{mask} = src.text;
                set(obj.GUI.tasks,'String',TaskStrs)
                drawnow;
            end
        end
        % Input Callbacks (will trigger listener callbacks)
        function addInLine_Callback(obj,varargin)
            prompt = {'Line Name (physical):',...
                'Alias (physical if blank):'};
            dlg_title = 'Add input line';
            answer = inputdlg(prompt,dlg_title,[1 50; 1 50]);
            if ~isempty(answer)
                LineName = answer{1};
                alias = answer{2};
                if isempty(alias)
                    alias = LineName;
                end
                try
                    obj.addInLine(LineName,alias);
                catch err
                    errordlg(err.message)
                    rethrow(err)
                end
            end
        end
        function removeInLine_Callback(obj,varargin)
            string = get(obj.GUI.InLines,'String');
            val = get(obj.GUI.InLines,'Value');
            selected = string{val};
            line = strsplit(selected,':'); line = line{1};
            val = min(val,length(string)-1);
            set(obj.GUI.InLines,'Value',val)
            obj.removeInLine(line);
        end
        function addOutLine_Callback(obj,varargin)
            prompt = {'Line Name (physical):',...
                'High Voltage Limit (if analog)',...
                'Low Voltage Limit (if analog)',...
                'Alias (physical if blank):',...
                'Initial State (0 if blank)'};
            dlg_title = 'Add output line';
            answer = inputdlg(prompt,dlg_title,[1 50; 1 50; 1 50; 1 50; 1 50]);
            if ~isempty(answer)
                LineName = answer{1};
                if isempty(answer{2})||isempty(answer{3})
                    limits = [-10 10];
                else
                    limits = [str2double(answer{3}) str2double(answer{2})];
                end
                alias = answer{4};
                init = answer{5};
                if isempty(alias)
                    alias = LineName;
                end
                if isempty(init)
                    init = 0;
                else
                    init = str2double(init);
                end
                try
                    obj.addOutLine(LineName,alias,limits,init);
                catch err
                    errordlg(err.message)
                    rethrow(err)
                end
            end
        end
        function removeOutLine_Callback(obj,varargin)
            string = get(obj.GUI.OutLines,'String');
            val = get(obj.GUI.OutLines,'Value');
            selected = string{val};
            line = strsplit(selected,':'); line = line{1};
            val = min(val,length(string)-1);
            set(obj.GUI.OutLines,'Value',val)
            obj.removeOutLine(line);
        end
    end
    
    % Hardware methods
    methods
        function [varargout] = LibraryFunction(obj,FunctionName,varargin)
            % use this function to call arbitrary library functions from
            % nidaqmx DLL. Checks for error, and returns all but status
            % It will interpret Task and DAQin/out objects as their
            % appropriate form for the lib

            % Don't allow arbitrary calls to this for channel creation (all end in chan)
            if Base.EndsWith(lower(FunctionName),'chan')&&~Base.EndsWith(lower(FunctionName),'readavailsampperchan')
                st = dbstack;
                st_names = {st.name};
                if numel(st_names) < 2 || ~Base.EndsWith(st_names{2},'CreateChannels')
                    error('Cannot create a channel directly through LibraryFunction, use CreateChannels.')
                end
            end
            % Convert any task objects to C pointers
            for i = 1:numel(varargin)
                if isa(varargin{i},'Drivers.NIDAQ.task')
                    obj.CurrentTask = varargin{i};
                    varargin{i} = varargin{i}.handle;
                elseif isa(varargin{i},'Drivers.NIDAQ.out') || isa(varargin{i},'Drivers.NIDAQ.in')
                    varargin{i} = varargin{i}.line;
                end
            end

            nargs = Base.libnargout(obj.LibraryName,FunctionName);
            if nargs < 2
                varargout = '';
                status = calllib(obj.LibraryName,FunctionName,varargin{:});
            else
                [status,varargout{1:nargs-1}] = calllib(obj.LibraryName,FunctionName,varargin{:});
            end
            obj.CheckErrorStatus(status);
        end
        %% Init
        function delete(obj)
            % Only execute if successfully initialized
            if ~isempty(obj.GUI)
                obj.close
            end
            if ~obj.load_error
                % Save channels
                try
                    TempOutLines = struct('line',{},'name',{},'state',{},'limits',{});
                    for i = 1:length(obj.OutLines)
                        OutLineObj = obj.OutLines(i)
                        line = strsplit(OutLineObj.line,'/');
                        line = strjoin(line(3:end),'/');
                        OutLineStruct.line = line;        % Remove /Dev#/
                        OutLineStruct.name = OutLineObj.name;
                        OutLineStruct.state = OutLineObj.state;
                        OutLineStruct.limits = OutLineObj.limits;
                        TempOutLines(end+1) = OutLineStruct;
                        delete(OutLineObj.niListener)
                        OutLineObj.niListener = [];
                    end
                    TempInLines = struct('line',{},'name',{});
                    for i = 1:length(obj.InLines)
                        InLineObj = obj.InLines(i)
                        line = strsplit(InLineObj.line,'/');
                        line = strjoin(line(3:end),'/');
                        InLineStruct.line = line;        % Remove /Dev#/
                        InLineStruct.name = InLineObj.name;
                        TempInLines(end+1) = InLineStruct;
                    end
                    setpref(obj.namespace,'OutLines',TempOutLines)
                    setpref(obj.namespace,'InLines',TempInLines)
                catch err
                    warning(err.message)
                end
                setpref(obj.namespace_dev,'OutLines',TempOutLines)
                setpref(obj.namespace_dev,'InLines',TempInLines)
            end
            delete(obj.OutLines);
            delete(obj.InLines);
            if ~obj.init_error
                % clear all tasks
                obj.ClearAllTasks();
                % unload library
                if libisloaded(obj.LibraryName)
                    unloadlibrary(obj.LibraryName);
                end
            end
        end
        function ResetDevice(obj)
            obj.ClearAllTasks;
            obj.LibraryFunction('DAQmxResetDevice',obj.DeviceChannel);
        end
        function SelfTest(obj)
            obj.LibraryFunction('DAQmxSelfTestDevice',obj.DeviceChannel);
        end
        %function view(obj) - in separate file

        %% Basic Task Control
        function task = GetTaskByName(obj,TaskName)
            mask = find(strcmp({obj.Tasks.name},TaskName));
            if ~sum(mask)
                error('No task with name: %s',TaskName)
            end
            task = obj.Tasks(mask);
        end
        function task = CreateTask(obj,TaskName)
            % Handle task names at MATLAB level to avoid problems of losing task handles
            mask = find(strcmp({obj.Tasks.name},TaskName));
            if sum(mask)
                error('Task "%s" already exists. Consider running ClearAllTasks.',TaskName)
            end
            task = Drivers.NIDAQ.task(obj,TaskName);
            obj.Tasks(end+1) = task;
            if ~isempty(obj.GUI)
                task.niListener = addlistener(task,'status','PostSet',@obj.UpdateTask);
            end
        end
        function ClearAllTasks(obj)
            tasks = obj.Tasks;
            for i = 1:numel(tasks)
                if isvalid(tasks(i))
                    tasks(i).Clear;
                end
                delete(tasks(i))
            end
        end

        %% Add/Remove "Global" lines (global to NIDAQ, not the nidaqmx lib)
        function line = addOutLine(obj,LineName,alias,limits,initial)
            % For a digital lines, it is ok to leave limits as empty array
            % Assigns line (e.g. PFI1 ) to an alias
            if nargin < 3
                alias = LineName;
                initial = 0;
                limits = [-10 10];
            elseif nargin < 4
                initial = 0;
                limits = [-10 10];
            elseif nargin < 5
                initial = 0;
            end
            % Determine if line is in use
            if sum(find(strcmp({obj.OutLines.line},LineName)))
                error('Line already exists as out line')
            elseif sum(find(strcmp({obj.InLines.line},LineName)))
                error('Line already exists as in line')
            elseif sum(find(strcmp({obj.OutLines.name},alias)))
                error('Name for line already exists')
            end
            line = Drivers.NIDAQ.out(obj,LineName,alias,limits);
            % The above will error if there is a problem in creation
            obj.OutLines(end+1) = line;
            if ~isempty(obj.GUI)
                line.niListener = addlistener(line,'state','PostSet',@obj.UpdateLine);
            end
            if strcmp(line.type,'digital')
                obj.WriteDOLines(line.name,initial)
            else
                obj.WriteAOLines(line.name,initial)
            end
        end
        function removeOutLine(obj,name)
            [line,mask] = obj.getLine(name,obj.OutLines);
            delete(line)
            obj.OutLines(mask) = [];
        end
        function line = addInLine(obj,LineName,alias)
            % Assigns line (e.g. AO1 ) to a name
            if nargin < 3
                alias = LineName;
            end
            % Determine if line is in use
            if sum(find(strcmp({obj.InLines.line},LineName)))
                error('Line already exists as in line')
            elseif sum(find(strcmp({obj.OutLines.line},LineName)))
                error('Line already exists as out line')
            elseif sum(find(strcmp({obj.InLines.name},alias)))
                error('Name for line already exists')
            end
            line = Drivers.NIDAQ.in(obj,LineName,alias);
            % The above will error if there is a problem in creation
            obj.InLines(end+1) = line;
        end
        function removeInLine(obj,name)
            [line,mask] = obj.getLine(name,obj.InLines);
            delete(line)
            obj.InLines(mask) = [];
        end

        function lines = getLines(obj,names,line_type)
            % Return line objects with names of type "in" or "out"
            if ~iscell(names)
                names = {names};
            end
            if isa(line_type,'char')
                if strcmpi(line_type(1:2),'in')
                    line_type = obj.InLines;
                elseif strcmpi(line_type(1:3),'out')
                    line_type = obj.OutLines;
                else
                    error('line_type needs to be in/out, but received %s',line_type);
                end
            end
            % Get the line associated to names instead
            for i = 1:numel(names)
                lines(i) = obj.getLine(names{i},line_type);
            end
        end

        %% Quick Read/Write (no task prep/clean necessary)
        function WriteDOLines(obj,names,values)
            if ~iscell(names)
                names = {names};
            end
            % names refer to the names of the lines when created
            lines = obj.getLines(names,obj.OutLines);
            if length(values) ~= numel(names)
                error('%i values, but %i names given',length(values),numel(names))
            end
            TaskName = 'DigitalWrite';
            task = obj.CreateTask(TaskName);

            % Equivalent to try catch finally statement:
            err = NaN;
            try
                task.CreateChannels('DAQmxCreateDOChan',lines,[],obj.DAQmx_Val_ChanPerLine);
                task.Start;
                task.LibraryFunction('DAQmxWriteDigitalLines',task,1,obj.WriteTimeout,10.0,0,values,0,[]);
            catch err
            end
            task.Clear
            if isa(err,'MException'); rethrow(err); end
            for i=1:numel(lines)
                lines(i).state = values(i);
            end
        end
        function WriteAOLines(obj,names,values)
            if ~iscell(names)
                names = {names};
            end
            lines = obj.getLines(names,obj.OutLines);
            assert(length(values)==numel(names),sprintf('%i values, but %i names given',length(values),numel(names)));
            % Make sure within limits
            for i = 1:length(lines)
                if isnan(values(i))
                    values(i) = 0;
                end
                assert(values(i) >= min(lines(i).limits),'Trying to write %f on line %s is forbidden since its lower limit is %f',values(i),lines(i).name,min(lines(i).limits))
                assert(values(i) <= max(lines(i).limits),'Trying to write %f on line %s is forbidden since its higher limit is %f',values(i),lines(i).name,max(lines(i).limits))
            end
            % MinVal 10% around values, but at least +/- 0.01
            MinVal = max(obj.AnalogOutMinVoltage,min(values)-max(abs(min(values)*0.1),0.01));
            MaxVal = min(obj.AnalogOutMaxVoltage,max(values)+max(abs(max(values)*0.1),0.01));

            TaskName = 'AnalogWrite';
            task = obj.CreateTask(TaskName);

            % Equivalent to try catch finally statement:
            err = NaN;
            try
                task.CreateChannels('DAQmxCreateAOVoltageChan',lines,[],MinVal, MaxVal,obj.DAQmx_Val_Volts ,[]);
                task.Start
                task.LibraryFunction('DAQmxWriteAnalogF64',task, 1,1, obj.WriteTimeout,obj.DAQmx_Val_GroupByChannel, values,[],[]);
            catch err
            end
            task.Clear
            if isa(err,'MException'); rethrow(err); end
            for i=1:numel(lines)
                lines(i).state = values(i);
            end
        end

        function voltage = ReadAILine(obj,name,VoltLim)
            % If user optionally specifies min/max, it will give a better result
            TaskName = 'AnalogRead';
            if nargin < 3
                % Default to device limits
                VoltLim = [obj.AnalogInMinVoltage obj.AnalogInMaxVoltage];
            end
            line = obj.getLine(name,obj.InLines);
            voltage = libpointer('doublePtr',0);
            MinVal = VoltLim(1);
            MaxVal = VoltLim(2);

            % create a new task
            task = obj.CreateTask(TaskName);

            % create an analog in voltage channel
            err = NaN;
            try
                task.CreateChannels('DAQmxCreateAIVoltageChan',line,'',obj.DAQmx_Val_Cfg_Default,MinVal, MaxVal,obj.DAQmx_Val_Volts ,[]);
                task.Start;
                [~,voltage] = task.LibraryFunction('DAQmxReadAnalogScalarF64',task,obj.ReadTimeout, voltage,[]);
            catch err
            end
            task.Clear;
            if isa(err,'MException'); rethrow(err); end
        end
        function state   = ReadDILine(obj,name)
            TaskName = 'DigitalRead';
            line = obj.getLine(name,obj.InLines);

            % create a new task
            task = obj.CreateTask(TaskName);

            % create a digital in channel
            err = NaN;
            try
                task.CreateChannels('DAQmxCreateDIChan',line,'',obj.DAQmx_Val_ChanForAllLines)
                task.Start
                warning('NotImplemented');
                state = NaN;
%                 [~,ptr] = task.LibraryFunction('DAQmxReadDigitalScalarU32',task,obj.ReadTimeout, ptr,[]);
%(TaskHandle taskHandle, int32 numSampsPerChan, float64 timeout, bool32 fillMode, uInt8 readArray[], uInt32 arraySizeInBytes, int32 *sampsPerChanRead, int32 *numBytesPerSamp, bool32 *reserved);
                task.LibraryFunction('DAQmxReadDigitalLines', task, 1, obj.ReadTimeout, obj.DAQmx_Val_GroupByChannel, ptr, [], [], []);
                state = ptr.Value;
            catch err
            end
            task.Clear
            if isa(err,'MException'); rethrow(err); end
        end
        function counts  = ReadCILine(obj,name)
            TaskName = 'CounterRead';
            line = obj.getLine(name,obj.InLines);

            % create a new task
            task = obj.CreateTask(TaskName);

            % create a counter in channel
            err = NaN;
            try
                task.CreateChannels('DAQmxCreateCICountEdgesChan',line,'',obj.DAQmx_Val_Rising, 0, obj.DAQmx_Val_CountUp);
                task.Start
                warning('NotImplemented');
                counts = NaN;
%                 [~,state] = task.LibraryFunction('DAQmxReadCounterScalarU32',task,obj.ReadTimeout, state,[]);

%                 task.LibraryFunction('DAQmxReadDigitalScalarU32',task,obj.ReadTimeout, ptr,[]);
%                 state = ptr.Value;
            catch err
            end
            task.Clear
            if isa(err,'MException'); rethrow(err); end
        end
    end
end
