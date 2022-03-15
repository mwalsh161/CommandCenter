function s = BuildPulseSequence(obj,tauIndex)
%BuildPulseSequence Builds pulse sequence for performing all-optical T1
%characterization given the index (tauIndex) in tauTimes
s = sequence('AllOpticalT1');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
MWChannel = channel('MW', 'color', 'k', 'hardware', obj.MWline - 1);
s.channelOrder = [repumpChannel, resChannel, APDchannel,MWChannel];

%repump
g = node(s.StartNode,repumpChannel,'delta',0);
g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);

%resonant and APD bins
r_s1 = node(g,resChannel,'units','us','delta',obj.resOffset_us);
node(r_s1,APDchannel,'units','us', 'delta',0);
node(r_s1,APDchannel,'units','us','delta',obj.CounterLength_us);
r_e1 = node(r_s1,resChannel,'units','us','delta',obj.resPulse1Time_us);
% node(r_e1,APDchannel,'units','us','delta',-obj.CounterLength_us);
% node(r_e1,APDchannel,'units','us','delta',0);
r_s2 = node(r_e1,resChannel,'units','us','delta',obj.resOffset_us);
node(r_s2,APDchannel,'units','us','delta',0);
node(r_s2,APDchannel,'units','us','delta',obj.CounterLength_us);
r_e2 = node(r_s2,resChannel,'units','us','delta',obj.resPulse2Time_us);
node(r_e2,APDchannel,'units','us','delta',obj.resOffset_us);
node(r_e2,APDchannel,'units','us','delta',obj.resOffset_us+obj.CounterLength_us);
r_s3 = node(r_e2,resChannel,'units','us','delta',obj.resOffset_us);
r_e3 = node(r_s3,resChannel,'units','us','delta',obj.resPulse2Time_us);
node(r_e3,APDchannel,'units','us','delta',obj.tauTimes(tauIndex));
node(r_e3,APDchannel,'units','us','delta',obj.CounterLength_us+obj.tauTimes(tauIndex));
r_s4 = node(r_e3,resChannel,'units','us','delta',obj.tauTimes(tauIndex));
r_e4 = node(r_s4,resChannel,'units','us','delta',obj.resPulse2Time_us);

%MW bins
mw_start = node(r_e1,MWChannel,'units','us','delta',obj.resOffset_us/2);
mw_stop = node(r_e2,MWChannel, 'units','us','delta',obj.resOffset_us/2);


% if tauIndex==1
%     s.draw
% end

end

