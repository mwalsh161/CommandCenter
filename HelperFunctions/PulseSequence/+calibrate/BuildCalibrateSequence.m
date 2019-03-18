function [ varargout ] = BuildCalibrateSequence(laserLine,laserTime,apdLine,apdTime,delay,averages)
%BuildPulseSequence Builds pulse sequence to callibrate laser delay
%   laserLine = hw line for the laser being calibrated
%   laserTime
%   apdLine = hw line for the APD being used
%   apdTime = 
%   delay = time in us between start of the laser pulse and start of the
%   APD
%   averages = number of averages to take at each delay point

s = sequence('LaserCalibrate');
laserchannel = channel('Laser','color','r','hardware',laserLine,'offset',[0,0]);
APDchannel = channel('APDgate','color','b','hardware',apdLine,'counter','APD1','offset',[0,0]);
s.channelOrder = [laserchannel, APDchannel];

if laserTime > 0
    l = node(s.StartNode,laserchannel,'delta',0);
    a = node(l,APDchannel,'units','us','delta',delay);
    node(l,laserchannel,'units','us','delta',laserTime);
    node(a,APDchannel,'units','us','delta',apdTime); %APD window should be as small as possible to get highest resolution - 10 ns
else %if ontime <= 0, then no laser, so just APD
    a = node(s.StartNode,APDchannel,'units','us','delta',delay);
    node(a,APDchannel,'units','us','delta',0.1); %APD window should be as small as possible to get highest resolution - 10 ns
    l = node.empty(0);
end
s.minDuration = max(laserTime*10^3,1e2); %HACK, (ns) This prevents sequence from running faster than nidaq can write by making last command at least minDuration long, and also prevents bleeding over experiment
s.repeat = averages;
varargout = {s, l, a};
end

