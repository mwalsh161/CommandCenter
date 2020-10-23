function s = BuildPulseSequence(obj,tauIndex)
%BuildPulseSequence Builds pulse sequence for performing all-optical T1
%characterization given the index (tauIndex) in tauTimes

repumpTime = obj.repumpTime_us;
resOffset = obj.resOffset_us;
resPulse1Time = obj.resPulse1Time_us;
resPulse2Time = obj.resPulse2Time_us;
resPulse1Counter1 = obj.resPulse1Counter1_us;
resPulse1Counter2= obj.resPulse1Counter2_us;
resPulse2Counter1 = obj.resPulse2Counter1_us;
resPulse2Counter2 = obj.resPulse2Counter2_us;
        
MWbufferTime = obj.MW_buffer_time_us;
sweepTime = obj.tauTimes(tauIndex);
samples = obj.samples;

repumpLine = obj.repumpLaser.PB_line-1;% need to  fix 532_PB
resLine = obj.resLaser.PB_line-1;
APDline = obj.APDline-1;
MWline = obj.SignalGenerator.PB_line-1;

s = sequence('Rabi_opticalPolarization');
repumpChannel = channel('repump','color','g','hardware',repumpLine);
resChannel = channel('resonant','color','r','hardware',resLine);
APDchannel = channel('APDgate','color','b','hardware',APDline,'counter',obj.APDnidaq);
MWchannel = channel('MW','color','b','hardware',MWline);

s.channelOrder = [repumpChannel, resChannel, APDchannel,MWchannel];

g = node(s.StartNode,repumpChannel,'delta',0);
g = node(g,repumpChannel,'units','us','delta',repumpTime);

r = node(g,resChannel,'units','us','delta',resOffset);
node(r,APDchannel,'delta',0);
node(r,APDchannel,'units','us','delta',resPulse1Counter1);
node(r,APDchannel,'units','us','delta',resPulse1Time-resPulse1Counter2);
node(r,APDchannel,'units','us','delta',resPulse1Time);
r = node(r,resChannel,'units','us','delta',resPulse1Time);
% MW pulse of duration sweepTime, buffered on both sides by MWbufferTime
r=node(r,MWchannel,'units','us','delta',MWbufferTime);
r=node(r,MWchannel,'units','us','delta',sweepTime);

r = node(r,resChannel,'units','us','delta',MWbufferTime);
node(r,APDchannel,'delta',0);
node(r,APDchannel,'units','us','delta',resPulse2Counter1);
node(r,APDchannel,'units','us','delta',resPulse2Time-resPulse2Counter2);
node(r,APDchannel,'units','us','delta',resPulse2Time);
r = node(r,resChannel,'units','us','delta',resPulse2Time);

s.repeat = samples;
pulseSeq = s;

end

