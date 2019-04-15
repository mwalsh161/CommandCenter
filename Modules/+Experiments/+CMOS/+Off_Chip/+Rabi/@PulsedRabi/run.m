function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
  
    %% get laser
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
 
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    obj.RF.MWFrequency = obj.CW_freq;
    pause(5);
    
    %% grab DAQ
    assert(~obj.abort_request,'User aborted');
    obj.Ni = Drivers.NIDAQ.dev.instance(obj.deviceName);
    obj.Ni.ClearAllTasks; %if the DAQ had open tasks kill them
    
    %% start get time list
    time_list = obj.determine_time_list;
   
    %% run ODMR experiment
    assert(~obj.abort_request,'User aborted');
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    obj.data.norm_data = obj.data.raw_data;
    timeDomain = (0:obj.Nsamples-1)/obj.DAQSamplingFrequency;
        
    for cur_nAverage = 1:obj.nAverages
       
        for timeIndex = 1:obj.number_points
            
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            %% data
            
            [s1,program1] = obj.updatePulseSequence(time_list(timeIndex),true); %this steps the MW time on and loads sequence into pulseblaster

            t = obj.Ni.CreateTask('pulse');
            t.ConfigurePulseTrainOut(obj.CounterSyncName,obj.DAQSamplingFrequency,obj.Nsamples);
            AI = obj.Ni.CreateTask('Analog In');
            AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples,[obj.MinVoltage,obj.MaxVoltage]);
          
            AI.Start;%start DAQ first
            t.Start;
            obj.pulseblaster.start;
            AI.WaitUntilTaskDone;%holding action till DAQ has correct number of samples
            obj.pulseblaster.stop;
            
            a = AI.ReadVoltageIn(obj.Nsamples);%read out DAQ channel
            
            %clear tasks from DAQ
            t.Clear;
            AI.Clear;
            
            obj.data.raw_data(timeIndex,cur_nAverage) = sum(a(a<mean(a)));
            
            %% normalization
            
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            [s2,program2] = obj.updatePulseSequence(time_list(timeIndex),false); %this turns off the MW for normalization but keeps the sequence the same otherwise

            t = obj.Ni.CreateTask('pulse');
            t.ConfigurePulseTrainOut(obj.CounterSyncName,obj.DAQSamplingFrequency,obj.Nsamples);
            AI = obj.Ni.CreateTask('Analog In');
            AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples,[obj.MinVoltage,obj.MaxVoltage]);
          
            AI.Start;%start DAQ first
            t.Start;
            obj.pulseblaster.start;
            AI.WaitUntilTaskDone; %holding action till DAQ has correct number of samples
            obj.pulseblaster.stop;
            
            a = AI.ReadVoltageIn(obj.Nsamples); %read out DAQ channel
            
            %clear tasks from DAQ
            t.Clear;
            AI.Clear;
            
            obj.data.norm_data(timeIndex,cur_nAverage) = sum(a(a<mean(a)));
            
            %% data analysis
            
            obj.data.dataVector = nanmean(obj.data.raw_data./obj.data.norm_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data./obj.data.norm_data,0,2)./sqrt(cur_nAverage);
           
            plot(time_list,obj.data.dataVector,'r*--','parent',ax)
            hold(ax,'on')
            plot(time_list(timeIndex),obj.data.dataVector(timeIndex),'b*','MarkerSize',10,'parent',ax)
            hold(ax,'off')
            ylabel(ax,'Voltage (V)')
            legend(ax,'Data')
            xlim(ax,time_list([1,end]));
            xlabel(ax,'Time (ns)')
            title(ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
            
        end
    end
    
catch message
end

%% cleanup
obj.laser.off;
obj.pulseblaster.stop;

%%
if ~isempty(message)
    rethrow(message)
end
end