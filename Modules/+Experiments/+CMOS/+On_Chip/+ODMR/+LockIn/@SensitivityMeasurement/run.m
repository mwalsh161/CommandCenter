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
    if ~strcmp(obj.ChipControl.Yokogawa_handle.Source_Mode,'Current')
        obj.ChipControl.Yokogawa_handle.off;
        obj.ChipControl.Yokogawa_handle.Source_Mode = 'Current';
        for index = 1:100
            currentDegauss = linspace(10e-3,0,100);
            obj.ChipControl.Yokogawa_handle.Current = currentDegauss(index);
            pause(0.1);
            obj.ChipControl.Yokogawa_handle.Current = -currentDegauss(index);
            pause(0.1);
        end
    end
    
    %% construct current vector
    
    switch lower(obj.MeasurementType)
        case 'linear'
            currentVector = linspace(obj.DCCurrentInitial,obj.DCCurrentFinal,obj.number_points);
            plottingVector = currentVector;
            label = 'Current (A)';
        case  'squarewave'
            timeVector = [0:1/10:obj.number_points];
            currentVector = square(2*pi*0.1.*timeVector);
            currentVector(currentVector == -1) = obj.DCCurrentInitial;
            currentVector(currentVector == 1) = obj.DCCurrentFinal;
            plottingVector = timeVector;
            label = 'time (s)';
    end
    
    %%
    obj.ChipControl.Yokogawa_handle.Current = currentVector(1);
    obj.ChipControl.Yokogawa_handle.on;
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    obj.RF.MWFrequency = obj.MWfreq;
    obj.RF.on;
    pause(3);
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
        end
        obj.Sensitivity = obj.LockIn.getSensitivity;
    else
        obj.LockIn.setSensitivity(obj.Sensitivity)
    end
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(length(currentVector),obj.nAverages);
    obj.data.phase_data = NaN(length(currentVector),obj.nAverages);

    for cur_nAverage = 1:obj.nAverages
        for currentIndex = 1:length(currentVector)
            
            assert(~obj.abort_request,'User aborted');
%             obj.ChipControl.Yokogawa_handle.Current = -currentVector(currentIndex);
%             pause(1);
            obj.ChipControl.Yokogawa_handle.Current = currentVector(currentIndex);
            
            pause(obj.waitSGSwitch)
            
            obj.data.raw_data(currentIndex,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn
            obj.data.phase_data(currentIndex,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel2));%Get current from LockIn

            
            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
            
            obj.data.phaseVector = nanmean(obj.data.phase_data,2);
            obj.data.phaseVectorError = nanstd(obj.data.phase_data,0,2)./sqrt(cur_nAverage);
            
            errorbar(plottingVector,obj.data.dataVector,obj.data.dataVectorError,'r*--','parent',ax)
            switch obj.Mode
                case 'voltage'
                    ylabel(ax,'Voltage (V)')
                case 'current'
                    ylabel(ax,'Current (A)')
                otherwise
                    error('Unknown Mode')
            end
            legend(ax,'Data')
            xlim(ax,sort(plottingVector([1,end])));
            xlabel(ax,label)
            title(ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))

           
            obj.LockIn.AutoScale;
        end
    end
    
catch message
end
%% cleanup
obj.laser.off;
% obj.Clock.off;
% obj.LockIn.reset;
obj.ChipControl.Yokogawa_handle.off;
%%
if ~isempty(message)
    rethrow(message)
end
end