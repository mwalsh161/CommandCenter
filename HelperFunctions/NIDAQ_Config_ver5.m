classdef NIDAQ_Config_ver5 < handle % Not ready; Do I really need confocal for tracking purpose?
    % Matlab Object Class implementing control for National Instruments
    % Digital Acquistion Card
    % Written by Donggyu, donggyu@MIT.edu, 31 Oct 2014
    % Version 2, by Donggyu, donggyu@MIT.edu, 21 Mar 2015
    % Version 4 by Donggyu, for irrational changes on libraries..
    % Version 5 by Donggyu, NI-6343, Added SinglePulse output using counter
    % Version 6 by Donggyu, NI-6343, Added analog voltage scanning line for confocal scanning

    properties
        LibraryName             % alias for library loaded
        LibraryFilePath         % path to nicaiu.dll on Windows
        HeaderFilePath          % path to NIDAQmx.h on Windows
        DeviceChannel           % device handle from MAX, eg. Dev1, Dev1, etc
        
        CounterIn=struct([]);             % array of structures for counters
        CounterOut=struct([]);
        TriggerIn=struct([]);                 % array of structures for clocks
        AnalogIn=struct([]);
        AnalogOut=struct([]);
        DigitalOut=struct([]);
        Task=struct([]);        
        ErrorStrings=[];
        AOHistory=[];
        minCountRate=0;
        maxCountRate=10e6;
        SamplingRate;            
        
        Mirror1
        Mirror2
       
        
        TaskHandle=[]; % What is going on? 8/21/2015... It should be void pointer, but it is fine with [], libfunctionview(nidaqmx)
        
        
          
        ReadTimeout = 10;       % Timeout for a read operation (sec)
%         WriteTimeout = 10;      % Timeout for a write operation (sec)
%         
%         ErrorStrings = {};      % Strings from DAQmx Errors
        
    end

    
    properties (Constant, Hidden) %(Transient, Constant, GetAccess = public)
        % constants for NI Board
        DAQmx_Val_Volts =  10348;
        DAQmx_Val_Rising = 10280; % Rising
        DAQmx_Val_Falling =10171; % Falling
        DAQmx_Val_CountUp =10128; % Count Up
        DAQmx_Val_CountDown =10124; % Count Down
        DAQmx_Val_ExtControlled =10326; % Externally Controlled
        DAQmx_Val_Hz = 10373; % Hz
        DAQmx_Val_Low =10214; % Low
        DAQmx_Val_ContSamps =10123; % Continuous Samples
        DAQmx_Val_GroupByChannel = 0;
        DAQmx_Val_Cfg_Default = int32(-1);
        DAQmx_Val_FiniteSamps =10178; % Finite Sample      
        DAQmx_Val_Auto = -1;
        DAQmx_Val_WaitInfinitely = -1.0 %*** Value for the Timeout parameter of DAQmxWaitUntilTaskDone
        DAQmx_Val_Ticks =10304;
        DAQmx_Val_Seconds =10364;
        DAQmx_Val_ChanPerLine = 0;
        DAQmx_Val_ChanForAllLines   = 1;
        DAQmx_Val_Timeout=0.50; 

        
        

    end
    
    methods
        
        % instantiation function
        function obj = NIDAQ_Config_ver5(LibraryName,LibraryFilePath,HeaderFilePath)
            obj.LibraryName = LibraryName;
            obj.LibraryFilePath = LibraryFilePath;
            obj.HeaderFilePath = HeaderFilePath;
            obj.Initialize();

        end

        function obj = UpdateAllLines(obj)
%             obj.addCounterOutLine('Dev1/Ctr0','','ExtClock'); % ExtClk Generation
%             obj.addCounterOutLine('Dev1/Ctr1','','SGSyncPulse'); % Pulse Generation for Signal generator trigger
%             obj.addCounterInLine('Dev1/Ctr2','/Dev1/PFI4','TickSource'); % Tick Sources 
            obj.addCounterInLine('Dev1/Ctr2','/Dev1/PFI3','SampleClk'); % ExtClk
%             obj.addTriggerInLine('/Dev1/PFI6','DMDSyncPulseTrig'); % Start Trigger 
%             obj.addTriggerInLine('/Dev1/PFI7','SGSyncPulseTrig'); % Start Trigger 
            obj.addAnalogInLine('/Dev1/ai8','/Dev1/PFI3','DMDSyncPulse'); % Gating Recording with ExtClk (DMD)
            obj.addAnalogOutLine('/Dev1/ao0', '/Dev1/PFI3', 'LockInModulation');
%             obj.addAnalogInLine('/Dev1/ai16','/Dev1/PFI5','SGSyncGating'); % Gating Recording with ExtClk (Signal Generator)

%             obj.addAnalogOutLine('')
%             obj.addAnalogOutLine
%             obj.addAnalogOutLine
% 
%             obj.addDigitalOutLine('/Dev1/port1/line0','FlipMirror1') % Mirror 1
%             obj.addDigitalOutLine('/Dev1/port1/line1','FlipMirror2') % Mirror 2
% %             obj.addAnalogInLine('/Dev2/ai2','/Dev2/PFI3','LaserFluctuation');
%             obj.addAnalogOutLine('Dev2/ao1','LaserDrive'); % Laser
%             obj.addAnalogOutLine('Dev2/ao0','BackLight'); % Laser for widefield excitation 
        end

        function obj = DisarmAllLine(obj)
            obj.ClearTask('PulseWidth');
            obj.ClearTask('ExtClock');
            obj.ClearTask('FlipMirror1');
            obj.ClearTask('FlipMirror2');
        end



        
        function [obj] = CheckErrorStatus(obj,ErrorCode)
            
            if(ErrorCode ~= 0)
                % get the required buffer size
                BufferSize = 0;
                [BufferSize] = calllib(obj.LibraryName,'DAQmxGetErrorString',ErrorCode,[],BufferSize);
                % create a string of spaces
                ErrorString = char(32*ones(1,BufferSize));
                % now get the actual string
                [~,ErrorString] = calllib(obj.LibraryName,'DAQmxGetErrorString',ErrorCode,ErrorString,BufferSize);
                warning(['NIDAQ_Driver Error!! -- ',datestr(now),char(13),num2str(ErrorCode),'::',ErrorString]);
                obj.ErrorStrings{end+1} = ErrorString;
            end
        end
        
        
        % Driver Setup, string input
        function obj = addTriggerInLine(obj,Terminal,TaskName)            
            addTriggerIn.Terminal = Terminal;            
            addTriggerIn.Task = TaskName;            

            obj.TriggerIn = [obj.TriggerIn,addTriggerIn]; %augment array of structures
        end
        
        function obj = addCounterInLine(obj,Logic,Terminal,TaskName)            
            addCounterIn.Logic = Logic; %logical name , eg '/Dev1/Ctr0'
            addCounterIn.Terminal = Terminal; % eg '/Dev1/PFI0'  
            addCounterIn.Task = TaskName;  %eg 'TickSource'       
            obj.CounterIn = [obj.CounterIn,addCounterIn];            
        end
        
        function obj = addCounterOutLine(obj,Logic,Terminal,TaskName)            
            addCounterOut.Logic = Logic; %logical name , eg /Dev1/ctr0
            addCounterOut.Terminal = Terminal; % eg /Dev1/PFI0     
            addCounterOut.Task = TaskName;       
            obj.CounterOut = [obj.CounterOut,addCounterOut];            
        end
        
        function obj=addAnalogInLine(obj,Terminal,ExtClk,TaskName)
            addAnalogIn.Terminal=Terminal;
            addAnalogIn.ExtClk=ExtClk;
            addAnalogIn.Task=TaskName;
            obj.AnalogIn=[obj.AnalogIn,addAnalogIn];            
        end
        
        function obj=addAnalogOutLine(obj,Terminal,ExtClk, TaskName)
            addAnalogOut.Terminal=Terminal;
            addAnalogOut.ExtClk = ExtClk;
            addAnalogOut.Task=TaskName;
            obj.AnalogOut=[obj.AnalogOut,addAnalogOut];
        end
        
        function obj=addDigitalOutLine(obj,Terminal,TaskName)
            addDigitalOut.Terminal=Terminal;
            addDigitalOut.Task=TaskName;
            obj.DigitalOut=[obj.DigitalOut,addDigitalOut];
        end
        
            
            
        
        % Initialization
        function Initialize(obj)
            if  ~libisloaded(obj.LibraryName)
                fprintf('Loading NIDAQ library.....');
                [~,~] = loadlibrary(obj.LibraryFilePath,obj.HeaderFilePath,'alias',obj.LibraryName);
                fprintf('Done.\n');                
            end
            obj.DeviceChannel='Dev1';
            obj.ResetDevice();
            display('NI-DAQ: loaded');
        end            
 
     
%         
%         function ConfigureAOSingleVoltage(obj,TaskName,minVol,maxVol)           
% 
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;
% 
%             LineNum=structfind(obj.AnalogOut,'Task',TaskName); 
%             
%             [~]=calllib(obj.LibraryName, ... 
%                 'DAQmxCreateAOVoltageChan',TaskHandle,obj.AnalogOut(LineNum).Terminal,...
%                 '',minVol,maxVol,obj.DAQmx_Val_Volts,'');            
%             
%         end

        function ConfigureGatedAOVoltageChan...
                (obj,TaskName,minVol,maxVol, SamplingRate, NumSamples, AOData)           
            % This is for CTIA Readout (Nov 16 2017 by DK)
            % This is only for the external clock has already been defined in a
            % task
            TaskNum=structfind(obj.Task,'TaskName',TaskName);
            TaskHandle=obj.Task(TaskNum).PointerNum;
            LineNum=structfind(obj.AnalogOut, 'Task', TaskName);          
            
            [~]=calllib(obj.LibraryName, ... 
                'DAQmxCreateAOVoltageChan', TaskHandle, obj.AnalogOut(LineNum).Terminal,...
                '',minVol, maxVol, obj.DAQmx_Val_Volts, '');            
           
            [~]=calllib(obj.LibraryName, ...
                'DAQmxCfgSampClkTiming',TaskHandle,obj.AnalogOut(LineNum).ExtClk,...
                SamplingRate, obj.DAQmx_Val_Rising, obj.DAQmx_Val_FiniteSamps, NumSamples);
                        
            [~]=calllib(obj.LibraryName, ... 
                'DAQmxWriteAnalogF64', TaskHandle, NumSamples, 0, 10.0, obj.DAQmx_Val_GroupByChannel, ...
               AOData, [], []);
            
        end
        
        function ConfigureContGatedAOVoltageChan...
                (obj,TaskName,minVol,maxVol, SamplingRate, NumSamples, AOData)           
        %  This is the continuous generation of a waveform for Lock-in
        %  modulation Nov 16 2017, DK
        %  This is only for the external clock has already been defined in a
        %  Task
            TaskNum=structfind(obj.Task,'TaskName',TaskName);
            TaskHandle=obj.Task(TaskNum).PointerNum;
            LineNum=structfind(obj.AnalogOut, 'Task', TaskName);          
            
            [~]=calllib(obj.LibraryName, ... 
                'DAQmxCreateAOVoltageChan', TaskHandle, obj.AnalogOut(LineNum).Terminal,...
                '',minVol, maxVol, obj.DAQmx_Val_Volts, '');            
           
            [~]=calllib(obj.LibraryName, ...
                'DAQmxCfgSampClkTiming',TaskHandle,'',...
                SamplingRate, obj.DAQmx_Val_Rising, obj.DAQmx_Val_ContSamps, NumSamples);
                        
            [~]=calllib(obj.LibraryName, ... 
                'DAQmxWriteAnalogF64', TaskHandle, NumSamples, 0, 10.0, obj.DAQmx_Val_GroupByChannel, ...
               AOData, [], []);
            
        end
        
        function [obj]=ConfigureAIVoltageChan...
                (obj,TaskName,minVol,maxVol,SamplingRate,NumSamples,ExternalSampClk)
            
            TaskNum=structfind(obj.Task,'TaskName',TaskName);
            TaskHandle=obj.Task(TaskNum).PointerNum;
            AILineNum=structfind(obj.AnalogIn,'Task',TaskName);            

            [~]=calllib(obj.LibraryName, ... 
                'DAQmxCreateAIVoltageChan',TaskHandle,obj.AnalogIn(AILineNum).Terminal,...
                '',obj.DAQmx_Val_Cfg_Default,minVol,maxVol,obj.DAQmx_Val_Volts,[]);

            if ExternalSampClk            
                [~]=calllib(obj.LibraryName, ...
                    'DAQmxCfgSampClkTiming',TaskHandle,obj.AnalogIn(AILineNum).ExtClk,...
                    SamplingRate,obj.DAQmx_Val_Rising, ...
                    obj.DAQmx_Val_FiniteSamps,NumSamples);
            else
                [~]=calllib(obj.LibraryName, ...
                    'DAQmxCfgSampClkTiming',TaskHandle,'',...
                    SamplingRate,obj.DAQmx_Val_Rising, ...
                    obj.DAQmx_Val_FiniteSamps,NumSamples);
            end
                
        end


        
        
        
%         function LaserPowerAO(obj,Voltage)
%             TimeOut=10;
%             
%             TaskNum=structfind(obj.Task,'TaskName','LaserControl');
%             TaskHandle=obj.Task(TaskNum).PointerNum;
%             
%             if Voltage==obj.LaserVoltage(length(obj.LaserVoltage))
%                 display('Updated')
%             else
%                 if obj.LaserVoltage(length(obj.LaserVoltage)) < Voltage
%                     step=0.001;
%                 else
%                     step=-0.001;
%                 end
% 
%                 InterVoltage=obj.LaserVoltage(length(obj.LaserVoltage));
%                 nstep=abs(obj.LaserVoltage(length(obj.LaserVoltage)) ...
%                     - Voltage)/abs(step);
%                 for i=1:nstep
%                     InterVoltage=InterVoltage+step;
%                     [~]=calllib(obj.LibraryName, ... 
%                         'DAQmxWriteAnalogF64',TaskHandle,1,1,TimeOut,...
%                         obj.DAQmx_Val_GroupByChannel,InterVoltage,[],[]);                                            
%                     
%                 end
%                 obj.LaserVoltage=[obj.LaserVoltage,Voltage];
%                 display('Voltage is gently updated')
%             end
%             
%         end
%         
%         function ConfigureCIPulseWidthPhotonTick...
%                 (obj,TaskName,SampleClk,TickSource,minCR,maxCR,NumSamples)                
%             
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;
% 
%             ClkLineNum=structfind(obj.CounterIn,'Task',SampleClk); 
%             TickLineNum=structfind(obj.CounterIn,'Task',TickSource);
%             
%             [~]=calllib(obj.LibraryName, ... 
%                 'DAQmxCreateCIPulseWidthChan',TaskHandle,obj.CounterIn(ClkLineNum).Logic,...
%                 '',minCR,maxCR,obj.DAQmx_Val_Ticks,obj.DAQmx_Val_Rising,'');
% 
%             [~]=calllib(obj.LibraryName, ... 
%                 'DAQmxSetCICtrTimebaseSrc',TaskHandle,obj.CounterIn(TickLineNum).Logic, ...
%                 obj.CounterIn(TickLineNum).Terminal); % Tick Sources
% 
%             [status]=calllib(obj.LibraryName, ...
%                 'DAQmxSetCIPulseWidthTerm',TaskHandle,obj.CounterIn(ClkLineNum).Logic, ...
%                 obj.CounterIn(ClkLineNum).Terminal); % PulseTrain
%                 obj.CheckErrorStatus(status)
%             if NumSamples == -1
%                 [~]=calllib(obj.LibraryName, ...
%                     'DAQmxCfgImplicitTiming',TaskHandle,obj.DAQmx_Val_ContSamps,1);
%             else
%                 [~]=calllib(obj.LibraryName, ...
%                     'DAQmxCfgImplicitTiming',TaskHandle,obj.DAQmx_Val_FiniteSamps,NumSamples);
%             end
%    
%         end
%         
%         function ConfigureSingleCI...
%                 (obj,TaskName,TickSource)
% 
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;
%             LineNum=structfind(obj.CounterIn,'Task',TickSource); 
%             
%             [status]=calllib(obj.LibraryName, ...
%                 'DAQmxCreateCICountEdgesChan',TaskHandle,obj.CounterIn(LineNum).Logic, ...
%                 '',obj.DAQmx_Val_Rising,0,obj.DAQmx_Val_CountUp);
%             obj.CheckErrorStatus(status);
%             status
%             [status]=calllib(obj.LibraryName, ...
%                 'DAQmxSetCICountEdgesTerm',TaskHandle,obj.CounterIn(LineNum).Logic, ...
%                 obj.CounterIn(LineNum).Terminal); % PulseTrain
%                 obj.CheckErrorStatus(status);
%         end
%         
%         function [CountRate]=SingleCount(obj,TaskName)
%             
% 
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;
%             timeout=10.0;                                                       
%             [status,~,CountRate,~]=calllib(obj.LibraryName,...
%                 'DAQmxReadCounterScalarU32',TaskHandle,timeout,libpointer('uint32Ptr',0),[]);
%             %[error,librarypointer,countrate,void]
%             obj.CheckErrorStatus(status);
%             
%         end
%         
%         
%         function [obj]=ConfigureCOSinglePulseGen...
%                 (obj,TaskName,InitialDelay,LowTime,PulseWidth)
%             
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;
%             LineNum=structfind(obj.CounterOut,'Task',TaskName); 
%      
%             [~]=calllib(obj.LibraryName, ...
%                 'DAQmxSetCOPulseTerm',TaskHandle,obj.CounterOut(LineNum).Logic, ...
%                 obj.CounterOut(LineNum).Terminal);
%                 
%  
%             [status]=calllib(obj.LibraryName, ...
%                 'DAQmxCreateCOPulseChanTime',TaskHandle,obj.CounterOut(LineNum).Logic,...
%                 '',obj.DAQmx_Val_Seconds,obj.DAQmx_Val_Low,InitialDelay,LowTime,PulseWidth);
%             
%             obj.CheckErrorStatus(status);
%             % Time in sec
%         end
% 
%         
%         function [obj]=ConfigureSingleDO...
%                 (obj,TaskName)
%             
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;
%             LineNum=structfind(obj.DigitalOut,'Task',TaskName); 
%      
%             [status]=calllib(obj.LibraryName, ...
%                 'DAQmxCreateDOChan',TaskHandle, ...
%                 obj.DigitalOut(LineNum).Terminal,'',obj.DAQmx_Val_ChanForAllLines);               
% %             status
%             
%             % Time in sec
%         end
% 
%      
%            function [obj]=WriteSingleDO...
%                 (obj,TaskName,Value)
%             
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;
%             LineNum=structfind(obj.DigitalOut,'Task',TaskName); 
%      
%             
%             [status]=calllib(obj.LibraryName, ...
%                 'DAQmxWriteDigitalLines',TaskHandle,...
%                 1,1,obj.DAQmx_Val_Timeout,obj.DAQmx_Val_GroupByChannel,Value,0,[]);                                   
%             obj.CheckErrorStatus(status);
% 
%             % Time in sec
%            end 
% 
%      
%             
%             
%                 
%         
%         function [Data]=ReadCI...
%                 (obj,TaskName,NumSamples)
%             
% 
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;            
% 
%             TimeOut=100;
%             
%             if NumSamples == -1
%                 [status,~,Data,~,~]=calllib(obj.LibraryName,...
%                     'DAQmxReadCounterU32',TaskHandle,uint32(1),TimeOut,...
%                     uint32(zeros(1,1)),uint32(1),...
%                     libpointer('int32Ptr',0),[]);
%                 obj.CheckErrorStatus(status);
%             else
%                 [status,~,Data,~,~]=calllib(obj.LibraryName,...
%                     'DAQmxReadCounterU32',TaskHandle,uint32(NumSamples),TimeOut,...
%                     uint32(zeros(1,NumSamples)),uint32(NumSamples),...
%                     libpointer('int32Ptr',0),[]);
%                 obj.CheckErrorStatus(status);
%             end
%             
%         end
%         
%             
%         
%         function [obj]=ConfigurePulseGenerator...
%                 (obj,TaskName,NumPulses,initialDelay,Freq,dutyCycle,Trigger,TriggerTaskName)
%             
%             TaskNum=structfind(obj.Task,'TaskName',TaskName);
%             TaskHandle=obj.Task(TaskNum).PointerNum;
%             LineNum=structfind(obj.CounterOut,'Task',TaskName);        
%             
%             
%             [~]=calllib(obj.LibraryName, ...
%                 'DAQmxCreateCOPulseChanFreq',...
%                 TaskHandle,obj.CounterOut(LineNum).Logic,'',obj.DAQmx_Val_Hz,obj.DAQmx_Val_Low, ... 
%                 initialDelay,Freq,dutyCycle);
%             
%             if NumPulses==-1
%                 [~]=calllib(obj.LibraryName,'DAQmxCfgImplicitTiming',...
%                 TaskHandle,obj.DAQmx_Val_ContSamps,1);
%             else                
%                 [~]=calllib(obj.LibraryName,'DAQmxCfgImplicitTiming',...
%                     TaskHandle,obj.DAQmx_Val_FiniteSamps,NumPulses);
%             end
% 
%                 
%             if Trigger
%                 
%                 TriggerNum=structfind(obj.TriggerIn,'Task',TriggerTaskName);
%                 
%                 [~]=calllib(obj.LibraryName, ...
%                 'DAQmxCfgDigEdgeStartTrig',TaskHandle,obj.TriggerIn(TriggerNum).Terminal,obj.DAQmx_Val_Rising);
%             end
%         end        
        

         
        function [Data]=ReadAI ...
                (obj,TaskName,NumSamples)

                TaskNum=structfind(obj.Task,'TaskName',TaskName);
                TaskHandle=obj.Task(TaskNum).PointerNum;
            
                [status,~,Data,~,~]=calllib(obj.LibraryName,...
                    'DAQmxReadAnalogF64',TaskHandle,-1,obj.DAQmx_Val_Timeout,...
                    obj.DAQmx_Val_GroupByChannel,uint32(zeros(1,(NumSamples))), ...
                    uint32((NumSamples)),libpointer('int32Ptr',0),[]); % -1 for numSampsPerChan*13200
                
                obj.CheckErrorStatus(status);                                
        end
        

        % function WriteSingleAO(obj,TaskName,Voltage)

        %     TaskNum=structfind(obj.Task,'TaskName',TaskName);
        %     TaskHandle=obj.Task(TaskNum).PointerNum;

        %     LineNum=structfind(obj.AnalogOut,'TaskName',TaskName); 

        %     TimeOut=10;
        %     [~]=calllib(obj.LibraryName, ... 
        %         'DAQmxWriteAnalogF64',th,1,1,TimeOut,...
        %         obj.DAQmx_Val_GroupByChannel,Voltage,[],[]);            
        % end
        
        % function GentlyWriteSingleAO(obj,TaskName,Voltage)
        %     TimeOut=10;

        %     TaskNum=structfind(obj.Task,'TaskName',TaskName);
        %     TaskHandle=obj.Task(TaskNum).PointerNum;

        %     LineNum=structfind(obj.AnalogOut,'TaskName',TaskName); 
            
        %     if Voltage==obj.LaserVoltage(length(obj.LaserVoltage))
        %         display('Updated')
        %     else
        %         if obj.LaserVoltage(length(obj.LaserVoltage)) < Voltage
        %             step=0.001;
        %         else
        %             step=-0.001;
        %         end

        %         InterVoltage=obj.LaserVoltage(length(obj.LaserVoltage));
        %         nstep=abs(obj.LaserVoltage(length(obj.LaserVoltage)) ...
        %             - Voltage)/abs(step);
        %         for i=1:nstep
        %             InterVoltage=InterVoltage+step;
        %             [~]=calllib(obj.LibraryName, ... 
        %                 'DAQmxWriteAnalogF64',TaskHandle,1,1,TimeOut,...
        %                 obj.DAQmx_Val_GroupByChannel,InterVoltage,[],[]);                                            
                    
        %         end
        %         obj.LaserVoltage=[obj.LaserVoltage,Voltage];
        %         display('Voltage is gently updated')
        %     end
            
        % end



        

  
        
%         function [CountRate]=ReadSingleCI...
%                 (obj,PulseTask,CITask,pCount,TimeWindows)
%             obj.StartTask(CITask);
            
%             obj.StartTask(PulseTask);           
%             [~,Data]=calllib(obj.LibraryName,...
%                 'DAQmxReadCounterScalarF64',CITask,10.0,pCount,[]);
%             CountRate=Data/TimeWindows;
%             obj.StopTask(PulseTask);
%             obj.StopTask(CITask);                       
%         end
        
%         function [obj]=SampleCLockFilterOn( ...
%                 obj,th,MinimumPulseWidth)
%              [~]=calllib(obj.LibraryName, ...
%                 'DAQmxSetSampClkDigFltrEnable',th,0);
            
%             [~]=calllib(obj.LibraryName, ...
%                 'DAQmxSetSampClkDigFltrMinPulseWidth', ...
%                 th,MinimumPulseWidth);
%              [~]=calllib(obj.LibraryName, ...
%                 'DAQmxSetSampClkDigFltrEnable',th,1);
            
%         end
        
%         function [obj]=DigitalFilterOn( ... 
%                 obj,th,ClockInLine,MinimumPulseWidth)
            
%             CounterDevice=obj.ClockLines(ClockInLine).PhysicalName;
           
%             [~]=calllib(obj.LibraryName, ...
%                 'DAQmxSetDIDigFltrEnable',th,CounterDevice,0);
% %             [~]=calllib(obj.LibraryName, ...
% %                 'DAQmxSetDIDigFltrTimebaseRate',th,CounterDevice,30e3);

%             [~]=calllib(obj.LibraryName, ...
%                 'DAQmxSetDIDigFltrMinPulseWidth', ...
%                 th,CounterDevice,MinimumPulseWidth);
%              [~]=calllib(obj.LibraryName, ...
%                 'DAQmxSetDIDigFltrEnable',th,CounterDevice,1);

%         end
      
                   
   % % Get Sample
        % function [count] = GetAvailableSamples(obj,TaskName)            
        %     th = obj.Tasks.get(TaskName);
        %     count = uint32(0);
        %     TimeOut = 0; %read once, then report
            
        %     if th,
        %         [status,count] = calllib(obj.LibraryName,'DAQmxGetReadAvailSampPerChan',th,count);

        %         % Error Check
        %         obj.CheckErrorStatus(status);
        %     else
        %         count = 0;
        %     end
        % end
        
        % Task Handle
        function obj = CreateTask(obj,TaskName) % Taskname ='ExtClk'
            
            thnum=structfind(obj.Task,'TaskName',TaskName);            

            if ~thnum                                                 
                for i=1:size(thnum,2)
                    [~]=calllib(obj.LibraryName,'DAQmxClearTask',...
                        obj.Task(thnum(1,i)).PointerNum);
                    obj.Task(thnum(1,i))=[];                        
                end
                display('Task Reset. Care your taskhandle capability')                
            end                                       
            [status,~,TaskHandle] = ...
                                        calllib(obj.LibraryName,'DAQmxCreateTask','',[]);            % Fixed by Donggyu @Aug/25/2015
%             calllib(obj.LibraryName,'DAQmxCreateTask','',length(obj.Task)+1);             % Fixed by Donggyu.. @Aug /21 /2015


                % Error Check
                obj.CheckErrorStatus(status);
                
            addTask.RefNum=length(obj.Task)+1; 
            addTask.TaskName=TaskName;
            addTask.PointerNum=TaskHandle;
            obj.Task=[obj.Task,addTask];
          
        end
        
        function [obj] = StartTask(obj,TaskName)
            % start the task
            TaskNum=structfind(obj.Task,'TaskName',TaskName);
            TaskHandle=obj.Task(TaskNum).PointerNum;

            [status] = calllib(obj.LibraryName,'DAQmxStartTask',TaskHandle);
            
                % Error Check
            obj.CheckErrorStatus(status);
        end
        
        
        function [obj] = WaitUntilTaskDone(obj,TaskName)
           
            TaskNum=structfind(obj.Task,'TaskName',TaskName);
            TaskHandle=obj.Task(TaskNum).PointerNum;

        
        
            [status] = calllib(obj.LibraryName,'DAQmxWaitUntilTaskDone',TaskHandle,obj.ReadTimeout);

            % Error Check
            obj.CheckErrorStatus(status);

        
        end
        
        
        
        function [obj] = StopTask(obj,TaskName)

            TaskNum=structfind(obj.Task,'TaskName',TaskName);
            TaskHandle=obj.Task(TaskNum).PointerNum;

            [status] = calllib(obj.LibraryName,'DAQmxStopTask',TaskHandle);

            obj.CheckErrorStatus(status);

            
        end

        function [obj] = ClearTask(obj,TaskName)
            
            TaskNum=structfind(obj.Task,'TaskName',TaskName);
            TaskHandle=obj.Task(TaskNum).PointerNum;

            [status] = calllib(obj.LibraryName,'DAQmxClearTask',TaskHandle);            

            obj.Task(TaskNum)=[];                                      
            obj.CheckErrorStatus(status);

        end

        function [obj] = RemoveTask(obj,TaskNum) % To remove individual task by num
            TaskHandle=obj.Task(TaskNum).PointerNum;

              [status] = calllib(obj.LibraryName,'DAQmxClearTask',TaskHandle);            

            obj.Task(TaskNum)=[];                                      
            obj.CheckErrorStatus(status);

        end

       function [obj] = TaskRemove(obj) % To remove every task except for Laser
            NumOfTask=length(obj.Task);
            for i=1:NumOfTask-1 
                TaskNum=NumOfTask-(i-1);
                TaskHandle=obj.Task(TaskNum).PointerNum;

                  [status] = calllib(obj.LibraryName,'DAQmxClearTask',TaskHandle);            

                obj.Task(TaskNum)=[];                                      
                obj.CheckErrorStatus(status);
            end

        end

        
        function [obj] = ClearAllTasks(obj)
            
            while length(obj.Task)
                [~]=calllib(obj.LibraryName,'DAQmxClearTask',...
                    obj.Task(length(obj.Task)).PointerNum);
                obj.Task(length(obj.Task))=[];                              
            end
        end
     
         function [] = ResetDevice(obj)
            [status] = calllib(obj.LibraryName,'DAQmxResetDevice',obj.DeviceChannel);
                % Error Check
                obj.CheckErrorStatus(status);
        end


        

       
        function delete(obj)
            % destructor method
            %
            % loop through tasks and clear
            % unload library
            obj.ClearAllTasks();
            if ~libisloaded(obj.LibraryName),
                [pOk,warnings] = unloadlibrary(obj.LibraryName);
            end
            
            % clear all tasks
            
            
        end %delete
            
        
        % function [bool] = IsTaskDone(obj,TaskName)
            
        %     p = libpointer('ulongPtr',0);
        %     th = obj.Tasks.get(TaskName);
        %     if th,
        %          [status,bool] = calllib(obj.LibraryName,'DAQmxIsTaskDone',th,p);
            
        %         % Error Check
        %         obj.CheckErrorStatus(status);
        %     else
        %         bool = 1; % task done b/c doesn't exist
        %     end
        % end
        
        % function [tasks] = GetSysTasks(obj)
        %     task = [];
        %     [status,tasks] = calllib(obj.LibraryName,'DAQmxGetSysTasks',[],0);
            
        %         % Error Check
        %         obj.CheckErrorStatus(status);
        % end
        

            
    end % METHODS
end
