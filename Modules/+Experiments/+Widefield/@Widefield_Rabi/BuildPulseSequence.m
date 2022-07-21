function pulseSeq = BuildPulseSequence(obj, MW_Time_us, normalisation)
%BuildPulseSequence builds a pulse sequence
laserChannel =  channel('laser',    'color', 'g', 'hardware', obj.Laser.PBline-1);
camChannel =    channel('camTrig',  'color', 'k', 'hardware', obj.Cam_Trig_Line-1);
MWchannel =     channel('MW',       'color', 'b', 'hardware', obj.SignalGenerator.MW_switch_PB_line-1);

% Pulse sequence for camera trigger
s = sequence('Widefield_Rabi_SingleLaser_Camera');
s.channelOrder = [laserChannel, camChannel, MWchannel];

n = s.StartNode;
n = node(n, laserChannel, 'units', 'us', 'delta', 0); % Initial initialisation
n = node(n, laserChannel, 'units', 'us', 'delta', obj.Laser_Time);
c = node(n, camChannel, 'units', 'us', 'delta', obj.camera_trig_delay); % trigger camera
c = node(c, camChannel, 'units', 'us', 'delta', obj.camera_trig_time);

loop = node(c, 'loop', 'type', 'start', 'delta', 'units', 'us', obj.camera_trig_delay); % start pulse loop

% MW pulse.
if ~normalisation
    m = node(loop, MWchannel, 'units', 'us', 'delta', obj.MW_Pad);
    m = node(m, MWchannel, 'units', 'us', 'delta', MW_Time_us);
end

% Laser pulse
if normalisation
    l = node(loop, laserChannel, 'units', 'us', 'delta', 2*obj.MW_Pad + MW_Time_us); % Delay includes MW time
    l = node(l, laserChannel, 'units', 'us', 'delta', obj.Laser_Time);
else
    l = node(m, laserChannel, 'units', 'us', 'delta', obj.MW_Pad); % Delay only includes MW pad time
    l = node(l, laserChannel, 'units', 'us', 'delta', obj.Laser_Time);
end
node(l, obj.samples, 'units', 'us', 'delta', 0, 'type', 'end');

pulseSeq = s;
end
