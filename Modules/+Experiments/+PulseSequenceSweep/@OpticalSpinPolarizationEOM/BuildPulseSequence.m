<<<<<<< HEAD
function s = BuildPulseSequence(obj,tauIndex)
%BuildPulseSequence Builds pulse sequence for performing all-optical T1
%characterization given the index (tauIndex) in tauTimes

s = sequence('AllOpticalT1emccd');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
EMCCDchannel = channel('triggerCCD','color','k','hardware',obj.EMCCD_trigger_line-1);
s.channelOrder = [repumpChannel, resChannel, EMCCDchannel];
gstart = node(s.StartNode,repumpChannel,'delta',0);
g = node(gstart,repumpChannel,'units','us','delta',obj.repumpTime_us);

r1 = node(g,resChannel,'units','us','delta',obj.resOffset_us);
node(r1,EMCCDchannel,'units','us','delta',0);
r1 = node(r1,resChannel,'units','us','delta',obj.tauTimes(tauIndex));


node(gstart,EMCCDchannel,'units','us','delta',obj.sequenceduration);

end

=======
function s = BuildPulseSequence(obj,~)
%BuildPulseSequence Builds pulse sequence for performing Optical Spin
%Polarization measurements

nCounters = obj.nCounterBins;

s = sequence('OpticalSpinPolarization');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
MWChannel = channel('MWChannel','color','r','hardware',obj.MW_line-1);
APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
s.channelOrder = [repumpChannel, resChannel, MWChannel, APDchannel];
% s.channelOrder = [repumpChannel, resChannel, APDchannel];
g = node(s.StartNode,repumpChannel,'delta',0);

% for n = 1 :ceil(obj.repumpTime_us +obj.resOffset_us)/(obj.counterDuration+obj.counterSpacing)
%     counterStart = node(g, APDchannel, 'units','us','delta', (n -1)*(obj.counterDuration+obj.counterSpacing));
%     node(counterStart, APDchannel, 'units','us','delta', obj.counterDuration)
% end
node(g,MWChannel,'units','us','delta',0);
g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
resStart = node(g,resChannel,'units','us','delta',obj.resOffset_us);
resStop = node(resStart,resChannel,'units','us','delta',obj.resTime_us);
node(resStop,MWChannel,'units','us','delta',0);


for n = 1-2:nCounters-2
    counterStart = node(resStart,APDchannel,'units','us','delta',(n-1)*(obj.counterDuration+obj.counterSpacing));
    node(counterStart,APDchannel,'units','us','delta',obj.counterDuration);
end

end
>>>>>>> 094219f62f8291bc6e2c3d6ced0637af339a0e5a
