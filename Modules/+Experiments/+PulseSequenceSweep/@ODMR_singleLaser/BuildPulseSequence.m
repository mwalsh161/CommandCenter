function pulseSeq = BuildPulseSequence(obj,ind)
%BuildPulseSequence builds a pulse sequence
assert(obj.APD_Time_us <= obj.Laser_Time_us,'APD Time must be <= Laser Time');

obj.SignalGenerator.frequency = obj.freq_list(ind) / obj.SignalGenerator.freqUnit2Hz;

s = sequence('ODMR_singleLaser');

laserChannel =  channel('laser',    'color', 'g', 'hardware', obj.Laser.PB_line-1);
APDchannel =    channel('APDgate',  'color', 'k', 'hardware', obj.APD_Gate_line-1, 'counter', obj.APD_line);
MWchannel =     channel('MW',       'color', 'b', 'hardware', obj.SignalGenerator.PB_line-1);

s.channelOrder = [laserChannel, APDchannel, MWchannel];

n = s.StartNode;
% Laser pulse, with APD bin at the beginning.
l = node(n, laserChannel,   'units', 'us', 'delta', 0);
n = node(l, APDchannel,     'units', 'us', 'delta', obj.APD_Offset_us);
    node(n, APDchannel,     'units', 'us', 'delta', obj.APD_Time_us);
l = node(l, laserChannel,   'units', 'us', 'delta', obj.Laser_Time_us);
% MW pulse.
n = node(l, MWchannel,      'units', 'us', 'delta', obj.MW_Pad_us);
n = node(n, MWchannel,      'units', 'us', 'delta', obj.MW_Time_us);
% Laser pulse, with APD bin at the beginning.
l = node(n, laserChannel,   'units', 'us', 'delta', obj.MW_Pad_us);
n = node(l, APDchannel,     'units', 'us', 'delta', obj.APD_Offset_us);
    node(n, APDchannel,     'units', 'us', 'delta', obj.APD_Time_us);
    node(l, laserChannel,   'units', 'us', 'delta', obj.Laser_Time_us);

s.repeat = obj.samples;
pulseSeq = s;
end
