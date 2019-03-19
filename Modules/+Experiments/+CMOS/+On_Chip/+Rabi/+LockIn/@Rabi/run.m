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
    obj.Photodiode.off;
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    obj.RF.MWFrequency = obj.CW_freq;
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
    
    %% start sequence
    time_list = obj.determine_time_list;
   [s,program] = obj.updatePulseSequence(time_list(1));
    %% AutoScale
    obj.pulseblaster.start;
    for index10 = 1:10
        pause(obj.waitTime)
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
    
    for cur_nAverage = 1:obj.nAverages
       
        for timeIndex = 1:obj.number_points
            
            assert(~obj.abort_request,'User aborted');
            
            obj.pulseblaster.stop;
            obj.updatePulseSequence(time_list(timeIndex));
            obj.pulseblaster.start;
            pause(obj.waitTime)
            
            obj.data.raw_data(timeIndex,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn

            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
           
            plot(time_list,obj.data.dataVector,'r*--','parent',ax)
            hold(ax,'on')
            plot(time_list(timeIndex),obj.data.dataVector(timeIndex),'b*','MarkerSize',10,'parent',ax)
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
            xlim(ax,time_list([1,end]));
            xlabel(ax,'Time (ns)')
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