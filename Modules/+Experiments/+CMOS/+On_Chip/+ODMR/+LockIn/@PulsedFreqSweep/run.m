function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
    %% grab power meter
    if strcmpi(obj.PowerMeter,'yes')
        obj.powerMeter = Drivers.PM100.instance;
        obj.powerMeter.set_wavelength('532');
        obj.opticalPower = obj.powerMeter.get_power('MW');
    else
        obj.opticalPower = NaN;
    end
    %% get laser
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
    %% get photodiode
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.Photodiode = obj.find_active_module(modules,'Photodiode');
    obj.Photodiode.on;
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    freq_list = obj.determine_freq_list;
    obj.RF.MWFrequency = freq_list(1);
    obj.RF.SGref.on; %turn on SG but not the switch
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
    laser_hw = obj.laser.PBline-1;
    photodiode_hw = obj.Photodiode.PBline-1;
    MW_switch_hw = obj.RF.MW_switch_PB_line-1;
    dummy_hw = 10;
    %% setup pulseblaster
    assert(~obj.abort_request,'User aborted');
    obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
       
    % Make some channels
    cLaser = channel('laser','color','g','hardware',laser_hw);
    cMWswitch = channel('MWswitch','color','k','hardware',MW_switch_hw');
    cDummy = channel('dummy','color','b','hardware',dummy_hw');
    cPhotodiode = channel('PD','color','r','hardware',photodiode_hw');
    
    %%

    % Make sequence
    s = sequence('Pulsed_Freq_Sweep_sequence');
    s.channelOrder = [cLaser,cMWswitch,cPhotodiode,cDummy];
    
    nloop = node(s.StartNode,'Loop the number of samples for averaging','type','start','delta',0,'units','us');

    % MW gate duration
    n_MW = node(s.StartNode,cMWswitch,'delta',0,'units','ns');
    n_MW_on = node(n_MW,cMWswitch,'delta',obj.MWonTime,'units','ns');
    
    % Laser duration
    n_LaserStart = node(n_MW_on,cLaser,'delta',0,'units','ns');
    n_LaserEnd = node(n_LaserStart,cLaser,'delta',obj.LaseronTime,'units','ns');
    
%     %Photodiode duration
%     n_PD = node(n_LaserStart,cPhotodiode,'delta',50,'units','ns');
%     n_PD = node(n_PD,cPhotodiode,'delta',obj.LaseronTime + obj.padding,'units','ns');
%     n_PD = node(n_PD,cPhotodiode,'delta',obj.LaseronTime + obj.padding,'units','ns');
%     n_PD = node(n_PD,cPhotodiode,'delta',obj.LaseronTime + obj.padding,'units','ns');
% 
%     %dummy line
% %     
%     n_dummy = node(s.StartNode,cDummy,'delta',0,'units','ns');
%     n_dummy = node(n_PD,cDummy,'delta',obj.LaseronTime + obj.padding + 10000,'units','ns');
%     
    nloop = node(n_LaserEnd,1000,'type','end','delta',0,'units','us');
    s.repeat = 1e6;
    
    %%
    [program,~] = s.compile;
    
    %% 
    obj.pulseblaster.stop;
    obj.pulseblaster.open;
    obj.pulseblaster.load(program);
    %% AutoScale
    obj.pulseblaster.start;
    for index10 = 1:10
        pause(obj.waitSGSwitch)
        obj.LockIn.AutoScale;
        obj.LockIn.AutoRange;
        obj.LockIn.getDataChannelValue(str2num(obj.DataChanel1));%Get current from LockIn
        assert(~obj.abort_request,'User aborted');
        
    end
    obj.pulseblaster.stop;
    obj.Sensitivity = obj.LockIn.getSensitivity;
    
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    obj.data.phase_data = NaN(obj.number_points,obj.nAverages);
    obj.pulseblaster.start;
    for cur_nAverage = 1:obj.nAverages
         
        for freq = 1:obj.number_points
            
            assert(~obj.abort_request,'User aborted');
            
            obj.RF.MWFrequency = freq_list(freq);
            pause(0.1)
            pause(obj.waitSGSwitch)
            obj.data.raw_data(freq,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn

            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
           
            
            plot(freq_list,obj.data.dataVector,'r*--','parent',ax)
            hold(ax,'on')
            plot(freq_list(freq),obj.data.dataVector(freq),'b*','MarkerSize',10,'parent',ax)
            hold(ax,'off')
            switch obj.Mode
                case 'voltage'
                    ylabel(ax,'Voltage (V)')
                case 'current'
                    ylabel(ax,'Current (A)')
                otherwise
                    error('Unknown Mode')
            end
            legend(ax,'Data')
            xlim(ax,freq_list([1,end]));
            xlabel(ax,'Microwave Frequency (GHz)')
            title(ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
            
        end
    end
    
catch message
end
%% cleanup
obj.pulseblaster.stop;
obj.laser.off;
delete(obj.listeners);
%%
if ~isempty(message)
    rethrow(message)
end
end