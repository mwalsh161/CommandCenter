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
r1 = node(r1,resChannel,'units','us','delta',obj.resPulse1Time_us);

r2 = node(r1,resChannel,'units','us','delta',obj.tauTimes(tauIndex));
r2 = node(r2,resChannel,'units','us','delta',obj.resPulse2Time_us);

node(gstart,EMCCDchannel,'units','us','delta',obj.sequenceduration);

end

