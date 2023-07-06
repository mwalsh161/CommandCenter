function s = BuildPulseSequence(obj,~)
%BuildPulseSequence Builds pulse sequence for performing Optical Spin
%Polarization measurements

nCounters = obj.nCounterBins;

s = sequence('OpticalSpinPolarization');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
s.channelOrder = [repumpChannel, resChannel, APDchannel];

g = node(s.StartNode,repumpChannel,'delta',0);
r_s1 = node(g,resChannel,'units','us','delta',obj.repumpTime_us/2);

g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
r_s1 = node(r_s1, resChannel,'units','us','delta',obj.repumpTime_us/2);
r_s1 = node(r_s1, resChannel,'units','us','delta',obj.resOffset_us);

r_s2 = node(r_s1, resChannel,'units','us','delta',obj.resTime_us);
gateStart = node(r_s1, APDchannel,'units','us','delta',0);
node(gateStart, APDchannel,'units','us','delta',obj.resTime_us);

% figure();
% s.draw
end
