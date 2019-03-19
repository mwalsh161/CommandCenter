function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
    
    %% grab power meter
    if strcmpi(obj.PowerMeter,'yes')
        try
        obj.powerMeter = Drivers.PM100.instance;
        obj.powerMeter.set_wavelength('532');
        obj.opticalPower = obj.powerMeter.get_power('MW');
        catch
           error('No Optical Power Meter connected') 
        end
    else
        obj.opticalPower = NaN;
    end
    %% get laser
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
    obj.laser.on;
    
    %% set the control voltages and Degauss magnet if neccessary
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    if strcmpi(obj.Degauss,'yes')
        obj.ChipControl.Yokogawa_handle.off;
        obj.ChipControl.Yokogawa_handle.Source_Mode = 'Current';
        obj.ChipControl.Yokogawa_handle.on;
        for index = 1:30
            currentDegauss = linspace(50e-3,0,30);
            obj.ChipControl.Yokogawa_handle.Current = currentDegauss(index);
            pause(0.1);
            obj.ChipControl.Yokogawa_handle.Current = -currentDegauss(index);
            pause(0.1);
            assert(~obj.abort_request,'User aborted');
        end
    end
    
    %% construct current vector
    
    timeVector = [0:obj.waitSGSwitch:obj.number_points*obj.waitSGSwitch];
    currentVector = square(2*pi*1/(obj.onTime*2).*timeVector);
    currentVector(currentVector == -1) = obj.DCCurrentInitial;
    currentVector(currentVector == 1) = obj.DCCurrentFinal;
    plottingVector = timeVector;
    label = 'time (s)';
    assert(~obj.abort_request,'User aborted');
    
    %% set up current source for electromagnet
    
    obj.ChipControl.Yokogawa_handle.Current = currentVector(1);
    obj.ChipControl.Yokogawa_handle.on;
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    obj.RF.MWFrequency = obj.MWfreq1;
    obj.RF.serial.setModulationDeviation(obj.FMChannel,obj.ModulationDeviation./obj.RF.PLLDivisionRatio,'Hz');
    obj.RF.serial.setModulationFreq(1,obj.frequency,'Hz');
    obj.RF.serial.setLFOutputVoltage(obj.OutputVoltage)
    obj.RF.serial.outputModulationFreq()
    obj.RF.on;
    obj.RF.serial.turnModulationOn(obj.FMChannel);
    pause(5);
    %% set LockIn values
    assert(~obj.abort_request,'User aborted');
    obj.LockIn =  Drivers.SR865_LockInAmplifier.instance('lockIn');
    obj.LockIn.reset;
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
   
    %% AutoScale
    if strcmpi(obj.AutoScale,'yes')
        for index10 = 1:10
            obj.LockIn.AutoScale;
            obj.LockIn.AutoRange;
            obj.LockIn.getDataChannelValue(str2num(obj.DataChanel1));%Get current from LockIn
            pause(1)
        end
        obj.Sensitivity = obj.LockIn.getSensitivity;
    else
        obj.LockIn.setSensitivity(obj.Sensitivity)
    end
    %% preallocate data vectors
    
    obj.data.raw_data1 = NaN(length(currentVector),obj.nAverages);
    obj.data.phase_data1 = NaN(length(currentVector),obj.nAverages);

    obj.data.raw_data2 = NaN(length(currentVector),obj.nAverages);
    obj.data.phase_data2 = NaN(length(currentVector),obj.nAverages);
    
    %% run experiment
    
    for cur_nAverage = 1:obj.nAverages
        for currentIndex = 1:length(currentVector)
            
            assert(~obj.abort_request,'User aborted');
            
            obj.ChipControl.Yokogawa_handle.Current = currentVector(currentIndex); %set current
            obj.LockIn.AutoScale;
            %% collect data for first MW frequency
            obj.RF.MWFrequency = obj.MWfreq1;
            
            pause(obj.waitSGSwitch)
            
            obj.data.raw_data1(currentIndex,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn
            obj.data.phase_data1(currentIndex,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel2));%Get current from LockIn
            %% collect data for second MW frequency
            obj.RF.MWFrequency = obj.MWfreq2;
            
            pause(obj.waitSGSwitch)
            
            obj.data.raw_data2(currentIndex,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn
            obj.data.phase_data2(currentIndex,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel2));%Get current from LockIn
            %% calculate FM Signal data

            FMData1AmplitudeVector = nanmean(obj.data.raw_data1,2);
            PhaseVector1 = nanmean(obj.data.phase_data1,2);
            FMData1AmplitudeVectorError = nanstd(obj.data.raw_data1,0,2)./sqrt(cur_nAverage);
            phaseVector1Error = nanstd(obj.data.phase_data1,0,2)./sqrt(cur_nAverage);
            FMSignal1 = -real(FMData1AmplitudeVector.*exp(1i.*PhaseVector1./57.3));
            
            
            FMData2AmplitudeVector = nanmean(obj.data.raw_data2,2);
            PhaseVector2 = nanmean(obj.data.phase_data2,2);
            FMData2AmplitudeVectorError = nanstd(obj.data.raw_data2,0,2)./sqrt(cur_nAverage);
            phaseVector2Error = nanstd(obj.data.phase_data2,0,2)./sqrt(cur_nAverage);
            FMSignal2 = -real(FMData2AmplitudeVector.*exp(1i.*PhaseVector2./57.3));
           
            %% save data
            
            obj.data.FMData1AmplitudeVector = FMData1AmplitudeVector;
            obj.data.PhaseVector1 = PhaseVector1;
            obj.data.FMSignal1 = FMSignal1;
            obj.data.FMData1AmplitudeVectorError = FMData1AmplitudeVectorError;
            obj.data.phaseVector1Error = phaseVector1Error;

            obj.data.FMData2AmplitudeVector = FMData2AmplitudeVector;
            obj.data.PhaseVector2 = PhaseVector2;
            obj.data.FMSignal2 = FMSignal2;
            obj.data.FMData2AmplitudeVectorError = FMData2AmplitudeVectorError;
            obj.data.phaseVector2Error = phaseVector2Error;
            
            plot(plottingVector,FMSignal2 - FMSignal1,'r*--','parent',ax)
            switch obj.Mode
                case 'voltage'
                    ylabel(ax,'Lock-In Signal Difference (\Delta V)')
                case 'current'
                    ylabel(ax,'Lock-In Signal Difference (\Delta A)')
                otherwise
                    error('Unknown Mode')
            end
            legend(ax,'Data')
            xlim(ax,sort(plottingVector([1,end])));
            xlabel(ax,label)
            title(ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))

           
        end
    end
    
catch message
end
obj.data.currentVector = currentVector;
obj.data.plottingVector = plottingVector; 
%% cleanup
obj.laser.off;
obj.ChipControl.Yokogawa_handle.off;
obj.RF.serial.turnModulationOff(obj.FMChannel);

%%
if ~isempty(message)
    rethrow(message)
end
end