function pulseSeq = BuildPulseSequence(obj,ind)
%BuildPulseSequence builds a pulse sequence
assert(obj.APD_Time <= obj.Laser_Time,'APD Time must be <= Laser Time');

MW_Times_us = obj.MW_Times_vals(ind);
s = sequence('Rabi_singleLaser');

laserChannel =  channel('laser',    'color', 'g', 'hardware', obj.Laser.PBline-1);
APDchannel =    channel('APDgate',  'color', 'k', 'hardware', obj.APD_Gate_line-1, 'counter', obj.APD_line);
MWchannel =     channel('MW',       'color', 'b', 'hardware', obj.SignalGenerator.MW_switch_PB_line-1);

s.channelOrder = [laserChannel, APDchannel, MWchannel];

n = s.StartNode;
% Laser pulse, with APD bin at the beginning.
l = node(n, laserChannel,   'units', 'us', 'delta', 0);
n = node(l, APDchannel,     'units', 'us', 'delta', obj.APD_Offset);
    node(n, APDchannel,     'units', 'us', 'delta', obj.APD_Time);
l = node(l, laserChannel,   'units', 'us', 'delta', obj.Laser_Time);
% MW pulse.
n = node(l, MWchannel,      'units', 'us', 'delta', obj.MW_Pad);
n = node(n, MWchannel,      'units', 'us', 'delta', MW_Times_us);
% Laser pulse, with APD bin at the beginning.
l = node(n, laserChannel,   'units', 'us', 'delta', obj.MW_Pad);
n = node(l, APDchannel,     'units', 'us', 'delta', obj.APD_Offset);
    node(n, APDchannel,     'units', 'us', 'delta', obj.APD_Time);
    node(l, laserChannel,   'units', 'us', 'delta', obj.Laser_Time);

s.repeat = obj.samples;
pulseSeq = s;
end
