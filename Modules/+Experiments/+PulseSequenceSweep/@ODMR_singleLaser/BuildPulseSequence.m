function pulseSeq = BuildPulseSequence(obj,ind)
%BuildPulseSequence builds a pulse sequence

freq = obj.freq_list(ind);
obj.SignalGenerator.MWFrequency = freq;

samples = obj.samples;

s = sequence('ODMR_singleLaser');

laserChannel =  channel('laser',    'color', 'g', 'hardware', obj.laser.PBline-1);
APDchannel =    channel('APDgate',  'color', 'k', 'hardware', obj.APDline-1, 'counter', 'APD1');
MWchannel =     channel('MW',       'color', 'm', 'hardware', obj.SignalGenerator.MW_switch_PB_line-1);
dummyChannel =  channel('Dummy',    'color', 'b', 'hardware', obj.dummyLine-1);

s.channelOrder = [laserChannel APDchannel, MWchannel, dummyChannel];

n = s.StartNode;

    node(n, dummyChannel,   'delta', 0);

% Laser pulse, with two APD bins at the beginning and end.
n = node(n, laserChannel,   'units', 'us', 'delta', obj.MWPad_us);
    
    node(n, APDchannel,     'delta', 0);
    node(n, APDchannel,     'units', 'us', 'delta', obj.APDTime_us);
    node(n, APDchannel,     'units', 'us', 'delta', obj.laserTime_us - obj.APDTime_us);
    node(n, APDchannel,     'units', 'us', 'delta', obj.laserTime_us);
    
n = node(n, laserChannel,   'units', 'us', 'delta', obj.laserTime_us);

% MW pulse.
n = node(n, MWchannel,      'units', 'us', 'delta', obj.MWPad_us);
n = node(n, MWchannel,      'units', 'us', 'delta', obj.MWTime_us);

    node(n, dummyChannel,   'delta', 0);
    
s.repeat = samples;
pulseSeq = s;
end
