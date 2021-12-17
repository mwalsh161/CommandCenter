function s = BuildPulseSequence(obj,tauIndex)
%BuildPulseSequence Builds pulse sequence for performing all-optical T1
%characterization given the index (tauIndex) in tauTimes

<<<<<<< HEAD
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
=======
s = sequence('AllOpticalT1');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
MWChannel = channel('MW', 'color', 'k', 'hardware', obj.MWline - 1);
s.channelOrder = [repumpChannel, resChannel, APDchannel,MWChannel];
g = node(s.StartNode,repumpChannel,'delta',0);
g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
m = node(g,MWChannel, 'units','us','delta',obj.resOffset_us + obj.resPulse1Time_us + obj.tauTimes(tauIndex)/2);
r_s1 = node(g,resChannel,'units','us','delta',obj.resOffset_us);

node(r_s1,APDchannel,'units','us', 'delta',0);
node(r_s1,APDchannel,'units','us','delta',obj.CounterLength_us);
r_e1 = node(r_s1,resChannel,'units','us','delta',obj.resPulse1Time_us);
node(r_e1,APDchannel,'units','us','delta',-obj.CounterLength_us);
node(r_e1,APDchannel,'units','us','delta',0);
r_s2 = node(r_e1,resChannel,'units','us','delta',obj.tauTimes(tauIndex));
node(r_s2,APDchannel,'units','us','delta',0);
node(r_s2,APDchannel,'units','us','delta',obj.CounterLength_us);
r_e2 = node(r_s2,resChannel,'units','us','delta',obj.resPulse2Time_us);
node(r_e2,APDchannel,'units','us','delta',0);
node(r_e2,APDchannel,'units','us','delta',-obj.CounterLength_us);
m = node(r_e2,MWChannel, 'units','us','delta',0);
g = node(r_e2,repumpChannel,'units','us','delta',0);
>>>>>>> 094219f62f8291bc6e2c3d6ced0637af339a0e5a

end

