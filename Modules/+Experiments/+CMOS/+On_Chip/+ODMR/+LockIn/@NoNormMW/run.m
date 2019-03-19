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
    %% get laser
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
    obj.laser.on;
    
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    freq_list = obj.determine_freq_list;
    obj.RF.MWFrequency = freq_list(1);
    obj.RF.on;
    pause(3);
    %% set LockIn values
    assert(~obj.abort_request,'User aborted');
    obj.LockIn =  Drivers.SR865_LockInAmplifier.instance('lockIn');
%     obj.LockIn.reset;
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
    %% setup clock
    assert(~obj.abort_request,'User aborted');
    obj.Clock = obj.find_active_module(modules,'CG635ClockGenerator');
    obj.Clock.ClockFrequency = obj.frequency;
    obj.Clock.Voltage = obj.GateVoltage;
    obj.Clock.on;
    %% AutoScale
    if strcmpi(obj.AutoScale,'yes')
        for index10 = 1:10
            obj.LockIn.AutoScale;
            obj.LockIn.AutoRange;
            obj.LockIn.getDataChannelValue(str2num(obj.DataChanel1));%Get current from LockIn
            pause(1)
            assert(~obj.abort_request,'User aborted');
            
        end
        obj.Sensitivity = obj.LockIn.getSensitivity;
    else
        obj.LockIn.setSensitivity(obj.Sensitivity)
    end
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    obj.data.phase_data = NaN(obj.number_points,obj.nAverages);
    pause(5)
    for cur_nAverage = 1:obj.nAverages
        for freq = 1:obj.number_points
            
            assert(~obj.abort_request,'User aborted');
            
            obj.RF.MWFrequency = freq_list(freq);
            
            pause(obj.waitSGSwitch)
            
            meas = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn
            obj.data.phase_data(freq,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel2));%Get current from LockIn
            
%             obj.RF.MWFrequency = 2.65e9;
%             
%             pause(obj.waitSGSwitch)
%             
%             normMeas = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));
            
            obj.data.raw_data(freq,cur_nAverage) = meas;
            
            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
            
            obj.data.phaseVector = nanmean(obj.data.phase_data,2);
            obj.data.phaseVectorError = nanstd(obj.data.phase_data,0,2)./sqrt(cur_nAverage);
            
            plot(freq_list,obj.data.dataVector,'r*--','parent',ax(1))
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
            
            obj.LockIn.AutoScale;
        end
    end
    
catch message
end
%% cleanup
obj.laser.off;
delete(obj.listeners);
% obj.Clock.off;
% obj.LockIn.reset;
%%
if ~isempty(message)
    rethrow(message)
end
end