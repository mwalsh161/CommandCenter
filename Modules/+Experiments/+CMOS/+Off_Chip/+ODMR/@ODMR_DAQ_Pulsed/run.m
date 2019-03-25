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
    
    %%

    % Make sequence
    s = sequence('Pulsed_Freq_Sweep_sequence');
    s.channelOrder = [cLaser,cMWswitch,cDummy];
    
    nloop = node(s.StartNode,'Loop the number of samples for averaging','type','start','delta',0,'units','us');

     %dummy line
     
    n_dummy = node(s.StartNode,cDummy,'delta',0,'units','us');
    n_dummy = node(n_dummy,cDummy,'delta',obj.LaserOnTime + obj.MWTime + obj.DelayTime + 2*obj.dummyTime,'units','us');
    
    % MW gate duration
    n_MW = node(s.StartNode,cMWswitch,'delta',obj.dummyTime,'units','us');
    n_MW_on = node(n_MW,cMWswitch,'delta',obj.MWTime,'units','us');
    
    % Laser duration
    n_LaserStart = node(n_MW_on,cLaser,'delta',obj.DelayTime,'units','us');
    n_LaserEnd = node(n_LaserStart,cLaser,'delta',obj.LaserOnTime,'units','us');
     
    nloop = node(n_LaserEnd,1000,'type','end','delta',0,'units','us');
    s.repeat = 1;
    
    %%
    [program,~] = s.compile;
    
    %% 
    obj.Pulseblaster.stop;
    obj.Pulseblaster.open;
    obj.Pulseblaster.load(program);
    %% grab DAQ
    obj.Ni = Drivers.NIDAQ.dev.instance(obj.deviceName);
    obj.Ni.ClearAllTasks; %if the DAQ had open tasks kill them
    
    obj.Nsamples = (obj.LaserOnTime + obj.MWTime + obj.DelayTime + obj.dummyTime)*1e-6*(obj.DAQSamplingFrequency)*2 ;
    
    t = obj.Ni.CreateTask('pulse');
    t.ConfigurePulseTrainOut(obj.CounterSyncName,obj.DAQSamplingFrequency,obj.Nsamples);
    AI = obj.Ni.CreateTask('Analog In');
    AI.ConfigureVoltageIn(obj.AnalogChannelName,t,obj.Nsamples,[obj.MinVoltage,obj.MaxVoltage]);
    DI = obj.Ni.CreateTask('Digital In');
    DI.ConfigureDigitalIn(obj.DigitalChannelName,t,obj.Nsamples);
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    
    for cur_nAverage = 1:obj.nAverages
        for freq = 1:obj.number_points
            
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            obj.RF.MWFrequency = freq_list(freq);
            
            pause(obj.waitSGSwitch)
            
            AI.Start;
            DI.Start;
            t.Start;
            AI.WaitUntilTaskDone;
            obj.Pulseblaster.start;
            
            d = DI.ReadDigitalIn(obj.Nsamples);
            a = AI.ReadVoltageIn(obj.Nsamples);
            
            timeDomain = (0:obj.Nsamples-1)/obj.DAQSamplingFrequency;
            
            obj.data.raw_data(freq,cur_nAverage) = mean(a);
            
            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
            
            errorbar(freq_list,obj.data.dataVector,obj.data.dataVectorError,'r*--','parent',ax)
            ylabel(ax,'Voltage (V)')
            
            legend(ax,'Data')
            xlim(ax,freq_list([1,end]));
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