function s = BuildPulseSequence(obj,tauIndex)
%BuildPulseSequence Builds pulse sequence for performing all-optical T1
%characterization given the index (tauIndex) in tauTimes

s = sequence('AllOpticalT1');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
APDchannel = channel('APDgate','color','b','hardware',obj.APDline,'counter','APD1');
s.channelOrder = [repumpChannel, resChannel, APDchannel];
g = node(s.StartNode,repumpChannel,'delta',0);
g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
r = node(g,resChannel,'units','us','delta',obj.resOffset_us);
node(r,APDchannel,'delta',0);
r = node(r,resChannel,'units','us','delta',obj.resPulse1Time_us);
node(r,APDchannel,'delta',0);
r = node(g,resChannel,'units','us','delta',obj.tauTimes(tauIndex));
node(r,APDchannel,'delta',0);
r = node(r,resChannel,'units','us','delta',obj.resPulse2Time_us);
node(r,APDchannel,'delta',0);

end

