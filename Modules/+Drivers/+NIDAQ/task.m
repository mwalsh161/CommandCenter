classdef task < handle
    %TASK is a handle container for task objects for NIDAQ
    %   If task is aborted/cleared before completion, the lines in use will
    %   be in an unknown state!
    
    properties
        UserData;        % Anything
    end
    properties(SetAccess=private)
        name;            % Name given to task
        handle;          % Handle assigned by NIDAQ
        dev;             % Handle to NIDAQ to determine when complete
    end
    properties(SetAccess=private,SetObservable)
        lines = {};      % Lines in use for this task
    end
    properties(SetAccess={?Drivers.NIDAQ.task,?Drivers.NIDAQ.dev},SetObservable,AbortSet)
        % frequency provides info on how timing is configured.
        status= 'Stopped';                 % Started, Aborted, Stopped, Done (simplified state model)
        clock = struct('src',NaN,'freq',NaN);
    end
    properties(SetAccess={?Drivers.NIDAQ.dev})
        niListener                     % Handle to NIDAQ's listener to state_change
    end
    properties(Access=private)
        timerH
        VoltageOutEndVals               % Used to confirm state of output after a scan or something
    end
    
    methods(Access={?Drivers.NIDAQ.task,?Drivers.NIDAQ.dev,?timer,?Drivers.NIDAQ.in,?Drivers.NIDAQ.out})
        function obj = task(dev,name)
            [~,th] = dev.LibraryFunction('DAQmxCreateTask','',[]);
            obj.name = name;
            obj.handle = th;
            obj.dev = dev;
            addlistener(obj,'status','PostSet',@obj.status_changed);
        end
        function str = text(obj)
            HTMLize = @(str,col)sprintf('<HTML><FONT color="%s">%s</Font></html>',col,str);
            switch obj.status
                case 'Stopped'
                    str = HTMLize(obj.name,'black');
                case 'Aborted'
                    str = HTMLize(obj.name,'red');
                case 'Started'
                    str = HTMLize(obj.name,'green');
                case 'Done'
                    str = HTMLize(obj.name,'orange');
                otherwise
                    str = sprintf('%s: %s',obj.name,obj.status);
            end
        end
        function WaitUntilDoneCallback(obj,t,varargin)
            % Called by the WaitUntilDoneBG timer
            % If aborted, it will never get here.
            if obj.IsTaskDone
                obj.status = 'Done';
                stop(t)
            end
        end
        function StopTimer(obj,t,varargin)
            if isvalid(obj)&&isvalid(t)
                obj.timerH = [];
                delete(t)
            end
        end
    end
    methods
        function delete(obj)
            if ~isempty(obj.timerH)
                stop(obj.timerH)
                delete(obj.timerH)
            end
            obj.LibraryFunction('DAQmxClearTask',obj);
            % Clean up any counters if necessary
            for i = 1:numel(obj.lines)
                try
                    line = obj.lines{i};
                    if length(line.line)>3
                        if sum(strcmpi(line.line(end-3:end),obj.dev.Counters))
                            obj.dev.returnCtr(line)
                        end
                    end
                catch
                    
                end
            end
            if obj.dev.CurrentTask == obj
                obj.dev.CurrentTask = [];
            end
            obj.dev.Tasks(strcmp({obj.dev.Tasks.name},obj.name)) = [];
        end
    end
    methods(Access=private)
        function addLines(obj,lines)
            for i = 1:length(lines)
                obj.lines{end+1} = lines(i);
            end
        end
        function status_changed(obj,varargin)
            % Setup in constructor
            switch obj.status
                case 'Started'
                    if ~isempty(obj.VoltageOutEndVals)
                        for i = 1:numel(obj.VoltageOutEndVals)
                            try
                                line = obj.dev.getLines(obj.VoltageOutEndVals(i).line,obj.dev.OutLines);
                                line.state = NaN;
                            catch
                            end
                        end
                    end
                    obj.timerH = timer('ExecutionMode','fixedSpacing',...
                        'Period',0.1,'name',['Task_' obj.name],...
                        'TimerFcn',@obj.WaitUntilDoneCallback,'StopFcn',@obj.StopTimer);
                    start(obj.timerH);
                case 'Done'
                        for i = 1:numel(obj.VoltageOutEndVals)
                            try
                                line = obj.dev.getLines(obj.VoltageOutEndVals(i).line,obj.dev.OutLines);
                                line.state = obj.VoltageOutEndVals(i).endval;
                            catch
                            end
                        end
                        obj.VoltageOutEndVals = [];
                case ['Aborted','Stopped']
                    for i = 1:numel(obj.VoltageOutEndVals)
                        try
                            line = obj.dev.getLines(obj.VoltageOutEndVals(i).line,obj.dev.OutLines);
                            line.state = NaN;
                        catch
                        end
                    end
                    obj.VoltageOutEndVals = [];
            end
        end
    end
    methods
        %% Library Access
        function [varargout] = CreateChannels(obj,FunctionName,lines,varargin)
            % Wrapper for create channels functions. Does a few additional
            % things before calling the Lib function. Assumes first two
            % arguments are task handle then the lines
            line_names = {lines.line};
            line_names = strjoin(line_names,', ');
            temp = obj.dev.CurrentTask;
            obj.dev.CurrentTask = obj;
            varargout = {obj.dev.LibraryFunction(FunctionName,obj,line_names,varargin{:})};
            if ~isempty(temp)&&isa(temp,'Drivers.NIDAQ.task')&&isvalid(temp)
                obj.dev.CurrentTask = temp;
            else
                obj.dev.CurrentTask = [];
            end
            obj.addLines(lines)
        end
        function varargout = LibraryFunction(obj,FunctionName,varargin)
            temp = obj.dev.CurrentTask;
            obj.dev.CurrentTask = obj;
            % determine how many outputs there should be for the function
            FunctionProto = libfunctions(obj.dev.LibraryName,'-full');
            % find the matching name
            A = strfind(FunctionProto,FunctionName);
            
            fIndex = NaN;
            
            for k=1:length(A)
                if ~isempty(A{k})
                    fIndex = k;
                    break
                end
            end
            
            if isnan(fIndex)
                error(['Drivers.NIDAQ: ' FunctionName ' not found in library. Valid functiibs are:' 13 strjoin(FunctionProto, char(13))]);
            end
            
            % use regexp to get the number of args, given as [a, b, c, d]
            argText = regexp(FunctionProto{fIndex},'\[(.*)\]','match');
            if isempty(argText) % no [] proto implies 1 return
                obj.dev.LibraryFunction(FunctionName,varargin{:});
            else
                nargs = length(regexp(argText{1}(2:end-1),'\w+'));
                [varargout{1:nargs-1}] = obj.dev.LibraryFunction(FunctionName,varargin{:});
            end
            if ~isempty(temp)&&isa(temp,'Drivers.NIDAQ.task')&&isvalid(temp)
                obj.dev.CurrentTask = temp;
            else
                obj.dev.CurrentTask = [];
            end
        end
        %% Control
        % [See Task State Machine in nidaqmx help]
        function Start(obj)
        obj.LibraryFunction('DAQmxStartTask',obj);
        obj.status = 'Started';
        end
        function Abort(obj)
            if ~isempty(obj.timerH)
                stop(obj.timerH)
            end
            obj.LibraryFunction('DAQmxTaskControl',obj,obj.dev.DAQmx_Val_Task_Abort);
            obj.status = 'Aborted';
        end
        function Stop(obj)
            if ~isempty(obj.timerH)
                stop(obj.timerH)
            end
            obj.LibraryFunction('DAQmxStopTask',obj);
            obj.status = 'Stopped';
        end
        function Clear(obj)
            if strcmp(obj.status,'Started')
                obj.status = 'Aborted';
            end
            delete(obj)
        end
        function WaitUntilTaskDone(obj,timeout)
            % int32 DAQmxWaitUntilTaskDone (TaskHandle taskHandle, float64 timeToWait);
            if nargin < 3
                timeout = obj.dev.DAQmx_Val_WaitInfinitely;  % Default wait forever
            end
            obj.LibraryFunction('DAQmxWaitUntilTaskDone',obj,timeout);
        end
        function bool = IsTaskDone(obj)
            [~,bool] = obj.LibraryFunction('DAQmxIsTaskDone',obj,0);
        end
        function Verify(obj)
            try
                obj.LibraryFunction('DAQmxTaskControl',obj,obj.dev.DAQmx_Val_Task_Verify);
            catch err
                warning('Task "%s" will probably have to be deleted and re-created',obj.name)
                rethrow(err)
            end
        end
        
        %% Configure
        function ConfigureStartTrigger(obj,lineName,type)
            % Given a timing task (e.g. PulseTrainOut), make it start on a
            % digital rising or falling edge (note this can be another
            % nidaq task or digital input)
            if nargin < 3
                type = 'rising';
            end
            % Capitalize (as defined in dev constants)
            type = lower(type); type(1) = upper(type(1));
            assert(ismember(type,{'Rising','Falling'}),'type must be rising or falling')
            line = obj.dev.getLines(lineName,obj.dev.OutLines);
            obj.LibraryFunction('DAQmxCfgDigEdgeStartTrig',obj,line.line,obj.dev.(['DAQmx_Val_', type]));
            obj.Verify;
        end
        function ConfigurePulseTrainOut(obj,lineName,frequency,NSamples,DutyCycle,delay)
            % If no lineName is specfied (isempty) then it will leave the default line for that counter
            if nargin < 4
                DutyCycle = obj.dev.DefaultDutyCycle;
                NSamples = 0;
                delay = 0;
            elseif nargin < 5
                DutyCycle = obj.dev.DefaultDutyCycle;
                delay = 0;
            elseif nargin < 6
                delay = 0;
            end
            % Determine continous or finite
            if NSamples < 1
                mode = obj.dev.DAQmx_Val_ContSamps;
                NSamples = 0;                   % Just to make sure it is positive
            else
                mode = obj.dev.DAQmx_Val_FiniteSamps;
            end
            % When the task starts and completes, we can set to NaN then the last set value
            obj.VoltageOutEndVals = struct('line',lineName,'endval',0);
            
            line = obj.dev.getLines(lineName,obj.dev.OutLines);
            % Find an open ctr, if there is one
            ctr = obj.dev.getAvailCtr;
            obj.CreateChannels('DAQmxCreateCOPulseChanFreq',ctr,'',obj.dev.DAQmx_Val_Hz,obj.dev.DAQmx_Val_Low,delay,frequency,DutyCycle);
            obj.LibraryFunction('DAQmxCfgImplicitTiming',obj,mode,NSamples);
            % Route the output terminal to the PhysicalLine Spec'd in the Configuration
            obj.LibraryFunction('DAQmxSetCOPulseTerm',obj,ctr,line);
            
            obj.clock = struct('src',line,'freq',frequency);         % Update task frequency for any application interested.
            obj.Verify
        end
        function ConfigureVoltageOut(obj,lineNames,Voltages,ClkTask,continuous)
            if nargin < 5
                continuous = false;
            end
            if ~isa(ClkTask.clock.src,'Drivers.NIDAQ.out')
                error('ClkTask requires DAQout object for clock.src')
            end
            if ~iscell(lineNames)
                lineNames = {lineNames};
            end
            if continuous
                mode = obj.dev.DAQmx_Val_ContSamps;
            else
                mode = obj.dev.DAQmx_Val_FiniteSamps;
            end
            s = size(Voltages);
            assert(s(2)==length(lineNames),'Voltages should be size samples X nlines, received %i x %i',s(1),s(2))
            NVoltagesPerLine = s(1);
            lines = obj.dev.getLines(lineNames,obj.dev.OutLines); %#ok<*PROP>
            % Make sure we are within voltage limits
            for i = 1:numel(lines)
                vs = Voltages(:,i);
                assert(min(vs) >= min(lines(i).limits),'Trying to write %g on line %s is forbidden since its lower limit is %g',min(vs),lines(i).name,min(lines(i).limits))
                assert(max(vs) <= max(lines(i).limits),'Trying to write %g on line %s is forbidden since its higher limit is %g',max(vs),lines(i).name,max(lines(i).limits))
            end
            
            % When the task starts and completes, we can set to NaN then the last set value
            obj.VoltageOutEndVals = struct('line',lineNames,'endval',num2cell(Voltages(end,:)));
            
            clkLine = ClkTask.clock.src;
            % Set the frequency of this guy slightly above the expected clock frequency
            Freq = 1.1*ClkTask.clock.freq;
            Voltages = Voltages(:);   % Make voltages linear
            
            % create analog out voltage channel(s)
            obj.CreateChannels('DAQmxCreateAOVoltageChan',lines,'',min(Voltages),max(Voltages),obj.dev.DAQmx_Val_Volts ,[]);
            obj.LibraryFunction('DAQmxCfgSampClkTiming',obj, clkLine, Freq, obj.dev.DAQmx_Val_Rising, mode ,NVoltagesPerLine);
            
            AutoStart = 0; % wait until user starts task
            obj.LibraryFunction('DAQmxWriteAnalogF64',obj,NVoltagesPerLine, AutoStart, obj.dev.WriteTimeout, obj.dev.DAQmx_Val_GroupByChannel, Voltages, [],[]);
            obj.clock = struct('src',clkLine,'freq','ext');
            % Allow regeneration of samples (e.g. dont clear FIFO)
            obj.LibraryFunction('DAQmxSetWriteRegenMode',obj,obj.dev.DAQmx_Val_AllowRegen);
            obj.Verify
        end
        function ConfigureDigitalOut(obj,lineNames,States,ClkTask,type)
            if ~isa(ClkTask.clock.src,'Drivers.NIDAQ.out')
                error('ClkTask requires DAQout object for clock.src')
            end
            if nargin < 5
                type = obj.dev.DAQmx_Val_ActiveDrive;
            end
            if ~iscell(lineNames)
                lineNames = {lineNames};
            end
            
            s = size(States);
            assert(s(2) == length(lineNames),'States should be size samples x nlines, received %i x %i',s(1),s(2))
            NStatesPerLine = s(1);
            States = States(:);   % Make voltages linear
            
            lines = obj.dev.getLines(lineNames,obj.dev.OutLines);
            clkLine = ClkTask.clock.src;
            % Set the frequency of this guy slightly above the expected clock frequency
            Freq = 1.1*ClkTask.clock.freq;

            % create a digital out channel
            obj.CreateChannels('DAQmxCreateDOChan',lines,'',obj.dev.DAQmx_Val_ChanPerLine);
            try
                obj.LibraryFunction('DAQmxSetDOOutputDriveType',obj,lines,type);
            catch err
                warning('It seems that some DAQs do not support DAQmxSetDOOutputDriveType. It''s probably fine to just ignore this, as the default is likely DAQmx_Val_ActiveDrive (which means LO == 0V and HI == 5V)')
            end
            
            % timing of the channel is set to that of the digial clock
            obj.LibraryFunction('DAQmxCfgSampClkTiming',obj, clkLine,Freq, obj.dev.DAQmx_Val_Rising, obj.dev.DAQmx_Val_FiniteSamps,NStatesPerLine);

            AutoStart = 0; % don't autostart
            obj.LibraryFunction('DAQmxWriteDigitalLines',obj,NStatesPerLine,AutoStart,obj.dev.WriteTimeout,obj.dev.DAQmx_Val_GroupByChannel,States,[],[]);
            obj.clock = struct('src',clkLine,'freq','ext');
            % Allow regeneration of samples (e.g. dont clear FIFO)
            obj.LibraryFunction('DAQmxSetWriteRegenMode',obj,obj.dev.DAQmx_Val_AllowRegen);
            obj.Verify
        end
        
        function ConfigureCounterIn(obj,lineName,NSamples,ClkTask,continuous)
            % The last input is optional, if true NSamples is used to determine the buffer size.
            if nargin < 5
                continuous = false;
            end
            ctrLine = obj.dev.getLines(lineName,obj.dev.InLines);
            if ~isa(ClkTask.clock.src,'Drivers.NIDAQ.out')
                error('ClkTask requires DAQout object for clock.src')
            end
            clkLine = ClkTask.clock.src;
            % Set the frequency of this guy slightly above the expected clock frequency
            Freq = 1.1*ClkTask.clock.freq;

            % Determine continous or finite
            if continuous
                mode = obj.dev.DAQmx_Val_ContSamps;
            else
                mode = obj.dev.DAQmx_Val_FiniteSamps;
            end
            
            % Find an open ctr, if there is one
            ctr = obj.dev.getAvailCtr;
            obj.CreateChannels('DAQmxCreateCICountEdgesChan',ctr,'', obj.dev.DAQmx_Val_Rising,0, obj.dev.DAQmx_Val_CountUp);
            obj.LibraryFunction('DAQmxSetCICountEdgesTerm',obj,ctr,ctrLine.line);
            % Route the output terminal to the PhysicalLine Spec'd in the Configuration
            obj.LibraryFunction('DAQmxCfgSampClkTiming',obj, clkLine.line,Freq, obj.dev.DAQmx_Val_Rising,mode,NSamples);
            obj.clock = struct('src',clkLine,'freq','ext');
            obj.Verify
        end
        function ConfigurePulseWidthCounterIn(obj,lineName,GateLineName,NSamples,MinCounts,MaxCounts,continuous)
            % The last input is optional, if true NSamples is used to determine the buffer size.
            if nargin < 7
                continuous = false;
            end
            % use this style counter for pulsed spin measurements (i.e. not imaging or basic counting)      
            clkLine = obj.dev.getLines(lineName,obj.dev.InLines);
            ctrLine = obj.dev.getLines(GateLineName,obj.dev.InLines);

            % Determine continous or finite
            if continuous
                mode = obj.dev.DAQmx_Val_ContSamps;
            else
                mode = obj.dev.DAQmx_Val_FiniteSamps;
            end
            
            % Find an open ctr, if there is one
            ctr = obj.dev.getAvailCtr;
            obj.CreateChannels('DAQmxCreateCIPulseWidthChan',ctr,'',MinCounts,MaxCounts, obj.dev.DAQmx_Val_Ticks,obj.dev.DAQmx_Val_Rising,'');
            % the terminal hardware channel
            obj.LibraryFunction('DAQmxSetCIPulseWidthTerm',obj,ctr,ctrLine);
 
            % set counter clock to NIDAQ configured line
            obj.LibraryFunction('DAQmxSetCICtrTimebaseSrc',obj, ctr,clkLine);
                
            % set to a finite number of samples
            obj.LibraryFunction('DAQmxCfgImplicitTiming',obj,mode, NSamples);            
            
            % set Duplicate Counter prevention for this counting mode
            obj.LibraryFunction('DAQmxSetCIDupCountPrevent',obj,ctr,1);
            obj.clock = struct('src',clkLine,'freq','ext');
            obj.Verify
        end
        function ConfigureVoltageIn(obj,lineNames,ClkTask,NSamples,limits)
            % The last input is optional, if supplied should be a 1x2
            % vector: [min max] strictly increasing
            if nargin < 5
                limits = [obj.dev.AnalogOutMinVoltage obj.dev.AnalogOutMaxVoltage];
            end
            if ~isa(ClkTask.clock.src,'Drivers.NIDAQ.out')
                error('ClkTask requires DAQout object for clock.src')
            end
            if ~iscell(lineNames)
                lineNames = {lineNames};
            end
            assert(numel(limits)==2,'Limits should have two elements: [min max]');
            assert(limits(1) < limits(2), 'Limits should be increasing: [min max]');
            assert(limits(1) >= obj.dev.AnalogOutMinVoltage, sprintf('Lower limit is below device min voltage (%g V)',obj.dev.AnalogInMinVoltage));
            assert(limits(2) <= obj.dev.AnalogOutMaxVoltage, sprintf('Upper limit is above device max voltage (%g V)',obj.dev.AnalogInMaxVoltage));
            
            lines = obj.dev.getLines(lineNames,obj.dev.InLines);
            clkLine = ClkTask.clock.src;
            % Set the frequency of this guy slightly above the expected clock frequency
            Freq = 1.1*ClkTask.clock.freq;

            % create an analog out voltage channel
            obj.CreateChannels('DAQmxCreateAIVoltageChan',lines,'',obj.dev.DAQmx_Val_Cfg_Default,limits(1), limits(2),obj.dev.DAQmx_Val_Volts ,[]);
            obj.LibraryFunction('DAQmxCfgSampClkTiming',obj, clkLine, Freq, obj.dev.DAQmx_Val_Rising, obj.dev.DAQmx_Val_FiniteSamps,NSamples);
            obj.clock = struct('src',clkLine,'freq','ext');
            obj.Verify
        end
        function ConfigureDigitalIn(obj,lineNames,ClkTask,NSamples)
            if ~isa(ClkTask.clock.src,'Drivers.NIDAQ.out')
                error('ClkTask requires DAQout object for clock.src')
            end
            if ~iscell(lineNames)
                lineNames = {lineNames};
            end
            lines = obj.dev.getLines(lineNames,obj.dev.InLines);
            clkLine = ClkTask.clock.src;
            % Set the frequency of this guy slightly above the expected clock frequency
            Freq = 1.1*ClkTask.clock.freq;

            % create an analog out voltage channel
            obj.CreateChannels('DAQmxCreateDIChan',lines,'',obj.dev.DAQmx_Val_ChanPerLine);
            obj.LibraryFunction('DAQmxCfgSampClkTiming',obj, clkLine, Freq, obj.dev.DAQmx_Val_Rising, obj.dev.DAQmx_Val_FiniteSamps,NSamples);
            obj.clock = struct('src',clkLine,'freq','ext');
            obj.Verify
        end

        function ConfigureMultiInMultiOut(obj, in, out, NSamples, continuous)
            
        end
        
        %% Read
        function count = AvailableSamples(obj)
            count = uint32(0);
            [~,count] = obj.LibraryFunction('DAQmxGetReadAvailSampPerChan',obj,count);
        end
        function [Data,nRead] = ReadCounter(obj,NSamples)
            if nargin < 2
                NSamples = 1;
            end
            Data = zeros(1,NSamples);
            
            % size of buffer
            SizeOfBuffer = uint32(NSamples);
            pRead = libpointer('int32Ptr',0);
            
            [~,Data,nRead,~] = obj.LibraryFunction('DAQmxReadCounterU32',obj,SizeOfBuffer,obj.dev.ReadTimeout,Data,SizeOfBuffer,pRead,[]);
            if nRead ~= NSamples
                warning('Read %i samples instead of %i',nRead,NSamples)
            end
        end
        function [Data,nRead] = ReadVoltageIn(obj,NSamples)
            if nargin < 2
                NSamples = 1;
            end
            % Determine number of analog input lines
            NLines = 0;
            for i = 1:length(obj.lines)
                line = obj.lines{i};
                if strcmp(line.type,'analog')&&isa(line,'Drivers.NIDAQ.in')
                    NLines = NLines + 1;
                end
            end
            assert(logical(NLines),'Task requires analog in lines')

            % size of buffer
            Data = zeros(NLines,NSamples);
            SizeOfBuffer = uint32(NLines*NSamples);
            pRead = libpointer('int32Ptr',0);
            
            [~,Data,nRead,~] = obj.LibraryFunction('DAQmxReadAnalogF64',obj, NSamples,obj.dev.ReadTimeout, obj.dev.DAQmx_Val_GroupByChannel, Data, SizeOfBuffer, pRead,[]);
            if nRead ~= NSamples
                warning('Read %i samples instead of %i',nRead,NSamples)
            end
        end
        function [Data,nRead] = ReadDigitalIn(obj,NSamples)
            if nargin < 2
                NSamples = 1;
            end
            % Determine number of analog input lines
            NLines = 0;
            for i = 1:length(obj.lines)
                line = obj.lines{i};
                if strcmp(line.type,'digital')&&isa(line,'Drivers.NIDAQ.in')
                    NLines = NLines + 1;
                end
            end
            assert(logical(NLines),'Task requires analog in lines')

            % size of buffer
            Data = uint8(zeros(NLines,NSamples));
            SizeOfBuffer = uint32(NLines*NSamples);
            pRead = libpointer('int32Ptr',0);
            pBytesPerSamp = libpointer('int32Ptr',0); % ConfigureDigitalIn doesn't allow flexibility here
            
            [~,Data,nRead,nBytesPerSamp,~] = obj.LibraryFunction('DAQmxReadDigitalLines',obj, NSamples,obj.dev.ReadTimeout, obj.dev.DAQmx_Val_GroupByChannel, Data, SizeOfBuffer, pRead, pBytesPerSamp, []);
            if nRead ~= NSamples
                warning('Read %i samples instead of %i',nRead,NSamples)
            end
        end
    end
end
