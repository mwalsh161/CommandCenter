function run(obj,statusH,managers,ax)
%% initialize some values
try
    message = [];
    obj.panel = ax.Parent;
    obj.abort_request = false;
    obj.ax(1) = subplot(1,2,1,'parent',obj.panel);
    obj.ax(2) = subplot(1,2,2,'parent',obj.panel);
    %% grab power meter
    if strcmpi(obj.PowerMeter,'yes')
        obj.powerMeter = Drivers.PM100.instance;
        obj.powerMeter.set_wavelength('532');
        obj.opticalPower = obj.powerMeter.get_power('MW');
    else
        obj.opticalPower = NaN;
    end
    %% get laser
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
    ip = obj.laser.ip;
    obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(ip);
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    obj.ChipControl.off;
    obj.ChipControl.DriverBias = obj.DriverBias;
    obj.ChipControl.CTIA_Bias = obj.PhotoDiodeBias;  %temporary
    %turn on all control channels
    obj.ChipControl.on;
    %% set LockIn values
    obj.LockIn =  Drivers.SR865_LockInAmplifier.instance('lockIn');
    obj.LockIn.reset;
    obj.LockIn.setSignalMode('current')%chris
    obj.LockIn.setRefSource('external')
    obj.LockIn.setExtRefTrigImp(obj.ExtRefTrigImp)
    obj.LockIn.setCurrentGain(obj.CurrentGain)
    obj.LockIn.setTriggerMode('ttl-pos')%chris
    obj.LockIn.setDetectionHarmonic(obj.DetectionHarmonic)
    obj.LockIn.setTimeConstant(obj.TimeConstant)
    obj.LockIn.setSlope(str2num(obj.Slope))
    obj.LockIn.setSync(obj.Sync)
    obj.LockIn.setGroundingType(obj.GroundingType)
    obj.LockIn.setChannelMode(str2num(obj.Channel),obj.ChannelMode)
%   
    %%
    obj.Ni = Drivers.NIDAQ.dev.instance('dev1');
    obj.data = [];
    obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,0);
    %% make sequence
    claser = channel('laser','color','r','hardware',obj.laser.PBline-1); 
    cdummy = channel('xxx','color','y','hardware',obj.PBDummyLine); 
    
    s = sequence('ODMR LockIN');
    s.channelOrder = [claser, cdummy];
        
    period = 1 / obj.frequency  * 1e6 ; % in microsecond
    
    
    n_laser = node(s.StartNode,claser,'delta',0,'units','us');
    n_laser = node(n_laser,claser,'delta',obj.dutyCycle  * period,'units','us');
    
    dummy = node(s.StartNode,cdummy,'delta',0,'units','us');
    dummy = node(dummy,cdummy,'delta', period, 'units','us');
    % %% Sequence Load
    [program,se] = s.compile;
   
    %% repeat endlessly
    
    string = program{end-1}; 
    strings = strsplit(string,',');
    minDuration = ', 10.00 ns';
    strings = [strings(1:end-1),minDuration];
    stringsNew = [];
    for index = 1:numel(strings)
        stringsNew = [stringsNew,strings{index}];
    end
    program{end-1} = stringsNew;
    %% load board
    
    obj.pulseblaster.open;
    obj.pulseblaster.load(program);
    obj.pulseblaster.stop;
    %% AutoScale
    if strcmpi(obj.AutoScale,'yes')
        obj.pulseblaster.start;
        pause(1)
        for index10 = 1:10
            obj.LockIn.AutoScale;
            obj.LockIn.AutoRange;
            obj.LockIn.getDataChannelValue(str2num(obj.DataChanel));%Get current from LockIn
            pause(1)
        end
        obj.pulseblaster.stop;
        
    else
        obj.LockIn.setSensitivity(obj.Sensitivity)
        
    end
    %% run ODMR experiment
    obj.start_experiment_CW;
catch message
end
%% cleanup
obj.laser.off;
obj.ChipControl.off;
obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,0);
obj.LockIn.reset;

%%
if ~isempty(message)
    rethrow(message)
end
end