function  [ varargout ] = BuildCalibrateSequence(obj,laserTime,delay)
%BuildPulseSequence Builds pulse sequence to callibrate laser delay
%   laserTime
%   apdTime =
%   delay = time in us between start of the laser pulse and start of the
%   APD

s = sequence('LaserCalibrate');
laserchannel = channel('Laser','color','r','hardware',obj.laser.PBline-1,'offset',[0,0]);
APDchannel = channel('APDgate','color','b','hardware',obj.apdLine-1,'counter','APD1','offset',[0,0]);
s.channelOrder = [laserchannel, APDchannel];

if laserTime > 0
    l = node(s.StartNode,laserchannel,'delta',0);
    a = node(l,APDchannel,'units','us','delta',delay);
    node(l,laserchannel,'units','us','delta',laserTime);
    node(a,APDchannel,'units','us','delta',obj.apdBin); %APD window should be as small as possible to get highest resolution - 10 ns
else %if ontime <= 0, then no laser, so just APD
    a = node(s.StartNode,APDchannel,'units','us','delta',delay);
    node(a,APDchannel,'units','us','delta',obj.apdBin); %APD window should be as small as possible to get highest resolution - 10 ns
    l = node.empty(0);
end
s.minDuration = max(laserTime*10^3,1e2); %HACK, (ns) This prevents sequence from running faster than nidaq can write by making last command at least minDuration long, and also prevents bleeding over experiment
varargout = {s, l, a};
end
