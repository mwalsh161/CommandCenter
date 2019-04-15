function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
    
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control'); %channels should be on
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    freq_list = obj.determine_freq_list;
    obj.RF.MWFrequency = freq_list(1);%SG should be on already
    pause(5);% let SG warm up
    
    %% grab Laser Handle
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
    
    %% setup sequence
    
    [program,s] = obj.setupSequence; %setup pulseblaster sequence

    %% grab DAQ
    assert(~obj.abort_request,'User aborted');
    obj.Ni = Drivers.NIDAQ.dev.instance(obj.deviceName);
    obj.Ni.ClearAllTasks; %if the DAQ had open tasks kill them
    
    %% run ODMR experiment
    assert(~obj.abort_request,'User aborted');
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    obj.data.norm_data = obj.data.raw_data;
    timeDomain = (0:obj.Nsamples-1)/obj.DAQSamplingFrequency;
    
    for cur_nAverage = 1:obj.nAverages
        for freq = 1:obj.number_points
            
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            %% do data frequency

            obj.RF.MWFrequency = freq_list(2*(freq-1) + 1);
           
            pause(obj.waitSGSwitch)

            t = obj.Ni.CreateTask('pulse');
            t.ConfigurePulseTrainOut(obj.CounterSyncName,obj.DAQSamplingFrequency,obj.Nsamples);
            AI = obj.Ni.CreateTask('Analog In');
            AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples,[obj.MinVoltage,obj.MaxVoltage]);
            DI = obj.Ni.CreateTask('Digital In');
            DI.ConfigureDigitalIn(obj.DigitalChannelName,t,obj.Nsamples);
            
            AI.Start;
            DI.Start;
            t.Start;
            obj.Pulseblaster.start;
            AI.WaitUntilTaskDone;
            obj.Pulseblaster.stop;
            
            a = AI.ReadVoltageIn(obj.Nsamples);
            d = DI.ReadDigitalIn(obj.Nsamples);
            
            t.Clear;
            DI.Clear;
            AI.Clear;

            obj.data.raw_data(freq,cur_nAverage) = sum(a(a<mean(a)));
            
            %% do normalization frequency
             
            obj.RF.MWFrequency = freq_list(2*(freq-1) + 2); 
            pause(obj.waitSGSwitch)
            
            t = obj.Ni.CreateTask('pulse');
            t.ConfigurePulseTrainOut(obj.CounterSyncName,obj.DAQSamplingFrequency,obj.Nsamples);
            AI = obj.Ni.CreateTask('Analog In');
            AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples,[obj.MinVoltage,obj.MaxVoltage]);
            DI = obj.Ni.CreateTask('Digital In');
            DI.ConfigureDigitalIn(obj.DigitalChannelName,t,obj.Nsamples);
            
            AI.Start;
            DI.Start;
            t.Start;
            obj.Pulseblaster.start;
            AI.WaitUntilTaskDone;
            obj.Pulseblaster.stop;
            
            a = AI.ReadVoltageIn(obj.Nsamples);
            d = DI.ReadDigitalIn(obj.Nsamples);
            
            t.Clear;
            DI.Clear;
            AI.Clear;

            obj.data.norm_data(freq,cur_nAverage) = sum(a(a<mean(a)));
            
            %% do data analysis

            obj.data.dataVector = nanmean(obj.data.raw_data./obj.data.norm_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data./obj.data.norm_data,0,2)./sqrt(cur_nAverage);
            
            errorbar(freq_list(1:2:end)./1e9,obj.data.dataVector,obj.data.dataVectorError,'r*--','parent',ax)
            ylabel(ax,'Voltage (V)')
            
            legend(ax,'Data')
            xlim(ax,[obj.start_freq,obj.stop_freq]./1e9);
            xlabel(ax,'Microwave Frequency (GHz)')
            title(ax,sprintf('Performing Average %i of %i and frequency %i of %i',cur_nAverage,obj.nAverages,freq,obj.number_points))
            
        end
        
    end
    
catch message
end
%% cleanup
obj.laser.off;
obj.Pulseblaster.stop;
            
%%
if ~isempty(message)
    rethrow(message)
end
end