function s = BuildPulseSequence(obj,tauIndex)
%BuildPulseSequence Builds pulse sequence for performing all-optical T1
%characterization given the index (tauIndex) in tauTimes

assert(obj.APDreadouttime_us<=obj.resPulse1Time_us & obj.APDreadouttime_us<=obj.resPulse2Time_us,'APD readout time too short');

s = sequence('AllOpticalT1');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
s.channelOrder = [repumpChannel, resChannel, APDchannel];
g = node(s.StartNode,repumpChannel,'delta',0);
gstop = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
r1start = node(gstop,resChannel,'units','us','delta',obj.resOffset_us);
%node(r,APDchannel,'delta',0);
r1stop = node(r1start,resChannel,'units','us','delta',obj.resPulse1Time_us);
node(r1stop,APDchannel,'units','us','delta',-obj.APDreadouttime_us);
node(r1stop,APDchannel,'units','us','delta',0);
r2start = node(r1stop,resChannel,'units','us','delta',obj.tauTimes(tauIndex));
node(r2start,APDchannel,'units','us','delta',0);
node(r2start,APDchannel,'units','us','delta',obj.APDreadouttime_us);
%node(r,APDchannel,'delta',0);
r2stop = node(r2start,resChannel,'units','us','delta',obj.resPulse2Time_us);
%node(r,APDchannel,'delta',0);

end

