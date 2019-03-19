function run(obj,statusH,managers,ax)
%% initialize some values
try
    
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
    panel = ax.Parent;
    ax(1) = subplot(1,3,1,'parent',panel);
    ax(2) = subplot(1,3,2,'parent',panel);
    ax(3) = subplot(1,3,3,'parent',panel);
    
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
    
    %% get CalibrationMatrix 
    
    if strcmpi(obj.Calibrate,'yes')
        if isempty(obj.calibrationMatrix)
            obj.calibrationMatrix = importdata(obj.filename);
        end
    end
    
    if strcmpi(obj.Calibrate,'no')
        obj.calibrationMatrix = [];
    end
    
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
    
    %% setup SG
    
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    obj.RF.MWFrequency = obj.freq1;
    obj.RF.serial.setModulationDeviation(obj.FMChannel,obj.ModulationDeviation./obj.RF.PLLDivisionRatio,'Hz');
    obj.RF.serial.setModulationFreq(1,obj.frequency,'Hz');
    obj.RF.serial.setLFOutputVoltage(obj.OutputVoltage)
    obj.RF.serial.outputModulationFreq()
    obj.RF.serial.turnModulationOn(obj.FMChannel);
    obj.RF.serial.turnModulationOnAll;
    
    freq_list = [obj.freq1,obj.freq2,obj.freq3];
    
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
    pause(1)
    obj.data.raw_data = NaN(3,obj.number_points);
    obj.data.phase_data = NaN(3,obj.number_points);
    data = NaN(3,obj.number_points);
    obj.data.flipped = obj.data.raw_data;
    obj.data.FM_data = obj.data.flipped;
    compensation = [obj.meanValue1,obj.meanValue2,obj.meanValue3];
    
    for cur_Point = 1:obj.number_points
        
        for freq = 1:numel(freq_list)
            
            assert(~obj.abort_request,'User aborted');
            
            obj.RF.serial.setFreqCW(freq_list(freq)./obj.RF.PLLDivisionRatio);
            
            pause(obj.waitSGSwitch)
            
            rawData = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel1));%Get current from LockIn
            phaseData= obj.LockIn.getDataChannelValue(str2double(obj.DataChanel2));%Get current from LockIn
            
            if phaseData > obj.PhaseTransition
                FMData = rawData;
                obj.data.flipped(freq,cur_Point) = 1;
            else
                FMData = -rawData;
                obj.data.flipped(freq,cur_Point) = -1;
            end
%             rawData = rawData - compensation(freq);
            obj.data.raw_data(freq,cur_Point) = rawData;
            obj.data.phase_data(freq,cur_Point) = phaseData;
            obj.data.FM_data(freq,cur_Point) = FMData - compensation(freq) ;
            
        end
        
        timeVector = 1:obj.number_points;
        if strcmpi(obj.Calibrate,'yes')
            data = (obj.calibrationMatrix)^-1*obj.data.FM_data;
        else
            data =  obj.data.FM_data;
        end
  
        plot(timeVector,data(1,:),'parent',ax(1))
        xlim(ax(1),timeVector([1,end]));
        ylim(ax(1),[-20 20]);
        grid (ax(1),'on');
        plot(timeVector,data(2,:),'parent',ax(2))
        xlim(ax(2),timeVector([1,end]));
        ylim(ax(2),[-20 20]);
        grid (ax(2),'on');
        plot(timeVector,data(3,:),'parent',ax(3))
        xlim(ax(3),timeVector([1,end]));
        ylim(ax(3),[-20 20]);
        grid (ax(3),'on');
        
        xlabel(ax(1),'Time (A.U.)')
        xlabel(ax(2),'Time (A.U.)')
        xlabel(ax(3),'Time (A.U.)')
        
        if strcmpi(obj.Calibrate,'yes')
            ylabel(ax(1),'Bx (\muT)')
            ylabel(ax(2),'By (\muT)')
            ylabel(ax(3),'Bz (\muT)')
        else
            data =  obj.data.FM_data;
            switch obj.Mode
                case 'voltage'
                    ylabel(ax(1),'Vx')
                    ylabel(ax(2),'Vy')
                    ylabel(ax(3),'Vz')
                    
                case 'current'
                    ylabel(ax(1),'Ax')
                    ylabel(ax(2),'Ay')
                    ylabel(ax(3),'Az')
                    
                otherwise
                    error('Unknown Mode')
            end
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