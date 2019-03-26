function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
    
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    %turn on all control channels
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    freq_list = obj.determine_freq_list;
    obj.RF.MWFrequency = freq_list(1);
    pause(5);% let SG warm up
    
    %% grab Laser Handle
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
    
     %% get hw lines for different pieces of equipment(subtract 1 because PB is indexed from 0)
    laser_hw = obj.laser.PBline-1;
    MW_switch_hw = obj.RF.MW_switch_PB_line-1;
    if strcmpi(obj.MWPulsed,'no')
        dummy_hw = MW_switch_hw; %if you dont want to pulse the MW set it to the dummy 
        MW_switch_hw = 10;
    else
        dummy_hw = 10;
    end
    %% setup pulseblaster
    assert(~obj.abort_request,'User aborted');
    obj.Pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
       
    % Make some channels
    cLaser = channel('laser','color','g','hardware',laser_hw);
    cMWswitch = channel('MWswitch','color','k','hardware',MW_switch_hw);
    cDummy = channel('dummy','color','b','hardware',dummy_hw');
    
    %% setup sequence
    
    [program,s] = obj.setupSequence; %setup pulseblaster sequence

    %% grab DAQ
    obj.Ni = Drivers.NIDAQ.dev.instance(obj.deviceName);
    obj.Ni.ClearAllTasks; %if the DAQ had open tasks kill them
    
    obj.Nsamples = round((obj.LaserOnTime + obj.MWTime + obj.DelayTime + obj.dummyTime)*1e-6*(obj.DAQSamplingFrequency)) ;
    
    obj.Ni.ClearAllTasks;
    t = obj.Ni.CreateTask('pulse');
    t.ConfigurePulseTrainOut(obj.CounterSyncName,obj.DAQSamplingFrequency,obj.Nsamples);
    AI = obj.Ni.CreateTask('Analog In');
%     AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples,[obj.MinVoltage,obj.MaxVoltage]);
    AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples);
    DI = obj.Ni.CreateTask('Digital In');
    DI.ConfigureDigitalIn(obj.DigitalChannelName,t,obj.Nsamples);
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    obj.data.norm_data = obj.data.raw_data;
    timeDomain = (0:obj.Nsamples-1)/obj.DAQSamplingFrequency;
    freq_list(2:2:end) = [];
    
    for cur_nAverage = 1:obj.nAverages
        for freq = 1:obj.number_points
            
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            %% do data frequency

            obj.RF.MWFrequency = freq_list(freq);
           
            pause(obj.waitSGSwitch)

            obj.Ni.ClearAllTasks;
            t = obj.Ni.CreateTask('pulse');
            t.ConfigurePulseTrainOut(obj.CounterSyncName,obj.DAQSamplingFrequency,obj.Nsamples);
            AI = obj.Ni.CreateTask('Analog In');
            AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples);
            DI = obj.Ni.CreateTask('Digital In');
            DI.ConfigureDigitalIn(obj.DigitalChannelName,t,obj.Nsamples);
            
           
            obj.Pulseblaster.start;
            AI.Start;
            DI.Start;
            t.Start;
            AI.WaitUntilTaskDone;
            
            pause((obj.LaserOnTime + obj.MWTime + obj.DelayTime + obj.dummyTime)*1e-6)
            
            d = DI.ReadDigitalIn(obj.Nsamples);
            a = AI.ReadVoltageIn(obj.Nsamples);
            
            obj.Pulseblaster.stop;

            obj.data.raw_data(freq,cur_nAverage) = mean(a);
            
%             %% do normalization frequency
%             
%             obj.RF.MWFrequency = freq_list(freq + 1); 
%             pause(obj.waitSGSwitch)
%             
%             obj.Ni.ClearAllTasks;
%             t = obj.Ni.CreateTask('pulse');
%             t.ConfigurePulseTrainOut(obj.CounterSyncName,obj.DAQSamplingFrequency,obj.Nsamples);
%             AI = obj.Ni.CreateTask('Analog In');
%             AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples);
%             DI = obj.Ni.CreateTask('Digital In');
%             DI.ConfigureDigitalIn(obj.DigitalChannelName,t,obj.Nsamples);
%             
%             AI.Start;
%             DI.Start;
%             t.Start;
%             AI.WaitUntilTaskDone;
%             obj.Pulseblaster.start;
%             
%             d = DI.ReadDigitalIn(obj.Nsamples);
%             a = AI.ReadVoltageIn(obj.Nsamples);
%             
%             obj.data.norm_data(freq,cur_nAverage) = mean(a);
             obj.data.norm_data(freq,cur_nAverage) = 1;
            %% do data analysis

            obj.data.dataVector = nanmean(obj.data.raw_data./obj.data.norm_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data./obj.data.norm_data,0,2)./sqrt(cur_nAverage);
            
            errorbar(freq_list./1e9,obj.data.dataVector,obj.data.dataVectorError,'r*--','parent',ax)
            ylabel(ax,'Voltage (V)')
            
            legend(ax,'Data')
            xlim(ax,[obj.start_freq,obj.stop_freq]./1e9);
            xlabel(ax,'Microwave Frequency (GHz)')
            title(ax,sprintf('Performing Average %i of %i and frequency %i of %i',cur_nAverage,obj.nAverages,freq,obj.number_points))
            
            obj.Pulseblaster.stop;
        end
        
    end
    
catch message
end
%% cleanup
t.Clear;
DI.Clear;
AI.Clear;
obj.laser.off;
     
            
%%
if ~isempty(message)
    rethrow(message)
end
end