function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
    panel = ax.Parent;
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
    obj.laser.on;
    
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    %turn on all control channels
    %% set LockIn values
    assert(~obj.abort_request,'User aborted');
    obj.LockIn =  Drivers.SR865_LockInAmplifier.instance('lockIn');
    obj.LockIn.setSignalMode(obj.Mode)%chris
    obj.LockIn.setRefSource('external')
    obj.LockIn.setExtRefTrigImp(obj.ExtRefTrigImp)
    obj.LockIn.setCurrentGain(obj.CurrentGain)
    obj.LockIn.setTriggerMode('sine')%chris
    obj.LockIn.setDetectionHarmonic(obj.DetectionHarmonic)
    obj.LockIn.setTimeConstant(obj.TimeConstant)
    obj.LockIn.setSlope(str2num(obj.Slope))
    obj.LockIn.setSync(obj.Sync)
    obj.LockIn.setGroundingType(obj.GroundingType)
    obj.LockIn.setChannelMode(str2num(obj.Channel),obj.ChannelMode)
    obj.LockIn.setVoltageInputMode(obj.VoltageMode);
    %
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    freq_list = obj.determine_freq_list;
    obj.RF.MWFrequency = freq_list(1);
    obj.RF.serial.setModulationDeviation(obj.FMChannel,obj.ModulationDeviation./obj.RF.PLLDivisionRatio,'Hz');
    obj.RF.serial.setModulationFreq(1,obj.frequency,'Hz');
    obj.RF.serial.setLFOutputVoltage(obj.OutputVoltage)
    obj.RF.serial.outputModulationFreq()
    obj.RF.serial.turnModulationOn(obj.FMChannel);
    obj.RF.serial.turnModulationOnAll;
    pause(5);
    
    %% AutoScale
    assert(~obj.abort_request,'User aborted');
    
    if strcmpi(obj.AutoScale,'yes')
        for index10 = 1:10
            obj.LockIn.AutoScale;
            obj.LockIn.AutoRange;
            obj.LockIn.getDataChannelValue(str2num(obj.DataChanel1));%Get current from LockIn
            pause(1)
            obj.Sensitivity = obj.LockIn.getSensitivity;
            assert(~obj.abort_request,'User aborted');
            
        end
    else
        obj.LockIn.setSensitivity(obj.Sensitivity)
    end
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    obj.data.phase_data = NaN(obj.number_points,obj.nAverages);
    
    for cur_nAverage = 1:obj.nAverages
        for freq = 1:obj.number_points
            
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            obj.RF.MWFrequency = freq_list(freq);
            
            pause(obj.waitSGSwitch)
            
            obj.data.raw_data(freq,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn
            obj.data.phase_data(freq,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel2));%Get current from LockIn
            
            
            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
            
            obj.data.phaseVector = nanmean(obj.data.phase_data,2);
            obj.data.phaseVectorError = nanstd(obj.data.phase_data,0,2)./sqrt(cur_nAverage);
            if strcmpi(obj.willPlot,'yes')
                errorbar(freq_list,obj.data.dataVector,obj.data.dataVectorError,'r*--','parent',ax(1))
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
                title(ax(1),sprintf('Performing Average %i of %i and frequency %i of %i',cur_nAverage,obj.nAverages,freq,obj.number_points))
                
                errorbar(freq_list,obj.data.phaseVector,obj.data.phaseVectorError,'b*--','parent',ax(2))
                ylabel(ax(2),'Phase (degrees)')
                legend(ax(2),'Data')
                xlim(ax(2),freq_list([1,end]));
                xlabel(ax(2),'Microwave Frequency (GHz)')
                title(ax(2),sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
            end
            obj.LockIn.AutoScale;
        end
    end
    
catch message
end
%% cleanup
obj.RF.serial.turnModulationOff(obj.FMChannel);
obj.RF.serial.turnModulationOffAll;
%%
if ~isempty(message)
    rethrow(message)
end
end