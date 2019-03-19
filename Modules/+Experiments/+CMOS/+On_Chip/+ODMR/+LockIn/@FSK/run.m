function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
    panel = ax.Parent;
    delete(ax)
    ax(1) = subplot(1,2,1,'parent',panel);
    ax(2) = subplot(1,2,2,'parent',panel);
    %% grab power meter
    if strcmpi(obj.PowerMeter,'yes')
        obj.powerMeter = Drivers.PM100.instance;
        obj.powerMeter.set_wavelength('532');
        obj.opticalPower = obj.powerMeter.get_power('MW');
    else
        obj.opticalPower = NaN;
    end
    %% get switch
    modules = managers.Sources.modules;
    obj.Switch = obj.find_active_module(modules,'Photodiode');
    
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    
    %% setup SG1
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    freq_list = obj.determine_freq_list;
    obj.RF.MWFrequency = freq_list(1)-obj.ModulationDeviation;
    obj.RF.on; %turn on SG but not the switch
    pause(5);
    
    %% setup SG2
    assert(~obj.abort_request,'User aborted');
    obj.RF2 = obj.find_active_module(modules,'CG635ClockGenerator');
    obj.RF2.ClockFrequency = (freq_list(1) + obj.ModulationDeviation)/obj.RF.PLLDivisionRatio;
    obj.RF2.on; %turn on SG but not the switch
    pause(5);
    
    %% set LockIn values
    assert(~obj.abort_request,'User aborted');
    obj.LockIn =  Drivers.SR865_LockInAmplifier.instance('lockIn');
    obj.LockIn.setSignalMode(obj.Mode)%chris
    obj.LockIn.setRefSource('external')
    obj.LockIn.setExtRefTrigImp(obj.ExtRefTrigImp)
    obj.LockIn.setCurrentGain(obj.CurrentGain)
    obj.LockIn.setTriggerMode('ttl-pos')
    obj.LockIn.setDetectionHarmonic(obj.DetectionHarmonic)
    obj.LockIn.setTimeConstant(obj.TimeConstant)
    obj.LockIn.setSlope(str2num(obj.Slope))
    obj.LockIn.setSync(obj.Sync)
    obj.LockIn.setGroundingType(obj.GroundingType)
    obj.LockIn.setChannelMode(str2num(obj.Channel),obj.ChannelMode)
    %% get hw lines for different pieces of equipment(subtract 1 because PB
    % is indexed from 0)
    Switch_hw = obj.Switch.PBline-1;
    dummy_hw = obj.dummyLine - 1;

    % setup pulseblaster
    assert(~obj.abort_request,'User aborted');
    obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
       
    % Make some channels
    cSwitch = channel('switch','color','g','hardware',Switch_hw);
    cDummy = channel('dummy','color','b','hardware',dummy_hw');

    %% Make sequence

    s = sequence('Pulsed_Freq_Sweep_sequence');
    s.channelOrder = [cSwitch,cSwitch,cDummy];
   
    %start lockIn Trigger
    
%     n_dummy = node(s.StartNode,cDummy,'delta',0,'units','ns');
%     n_dummy = node(s.StartNode,cDummy,'delta',0,'units','ns');

    SwitchonTime = 1/obj.frequency*1e6/2; %convert to us
    
    
    nloop = node(s.StartNode,'Loop the number of samples for averaging','type','start','delta',0,'units','ns');

    % MW gate duration
    n_switch = node(nloop,cSwitch,'delta',0,'units','us');
    n_switch_on = node(n_switch,cSwitch,'delta',SwitchonTime ,'units','us');
    
   
    %close loop
    nloop = node(n_switch_on,obj.innerLoopNumber,'type','end','delta',SwitchonTime,'units','us');
    
    n_switch = node(nloop,cSwitch,'delta',0,'units','ns');
    n_switch_on = node(n_switch,cSwitch,'delta',s.minDuration ,'units','ns');
    
    s.repeat = obj.loops;
    
    %%
    [program,~] = s.compile;
    
    %% 
    obj.pulseblaster.stop;
    obj.pulseblaster.open;
    obj.pulseblaster.load(program);
 
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    obj.data.phase_data = NaN(obj.number_points,obj.nAverages);
    obj.pulseblaster.start; %start continually running measurement
    obj.LockIn.AutoScale;

    for cur_nAverage = 1:obj.nAverages
        for freq = 1:obj.number_points
            
            assert(~obj.abort_request,'User aborted');
            
            MWFrequency = freq_list(freq);
            obj.RF.MWFrequency = MWFrequency-obj.ModulationDeviation;
            obj.RF2.ClockFrequency = (MWFrequency + obj.ModulationDeviation)/obj.RF.PLLDivisionRatio;
            
            pause(obj.waitSGSwitch)
            obj.data.raw_data(freq,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn
            obj.data.phase_data(freq,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel2));%Get current from LockIn

            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
            
            obj.data.phaseVector = nanmean(obj.data.phase_data,2);
            obj.data.phaseVectorError = nanstd(obj.data.phase_data,0,2)./sqrt(cur_nAverage);
            
            plot(freq_list,obj.data.dataVector,'r*--','parent',ax(1))
            hold(ax(1),'on')
            plot(freq_list(freq),obj.data.dataVector(freq),'b*','MarkerSize',10,'parent',ax(1))
            hold(ax(1),'off')
            switch obj.Mode
                case 'voltage'
                    ylabel(ax(1),'Voltage (V)')
                case 'current'
                    ylabel(ax(1),'Current (A)')
                otherwise
                    error('Unknown Mode')
            end
            legend(ax(1),'Data')
            xlim(ax(1),freq_list([1,end]));
            xlabel(ax(1),'Microwave Frequency (GHz)')
            title(ax(1),sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
           
            errorbar(freq_list,obj.data.phaseVector,obj.data.phaseVectorError,'b*--','parent',ax(2))
            ylabel(ax(2),'Phase (degrees)')
            legend(ax(2),'Data')
            xlim(ax(2),freq_list([1,end]));
            xlabel(ax(2),'Microwave Frequency (GHz)')
            title(ax(2),sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
            
        end
       
        pause(3)
    end
     obj.pulseblaster.stop;
catch message
end
%% cleanup
obj.pulseblaster.stop;
delete(obj.listeners);
%%
if ~isempty(message)
    rethrow(message)
end
end