function pulseSeq = BuildPulseSequence(obj,ind)
%BuildPulseSequence Builds pulse sequence at single frequency point for
%slow scan
%   greentime = duration of green pulse in us
%   redtime = duration of red pulse in us
%   averages = number of repetitions (limited to 2^20 = 1048576)
freq = obj.freq_list(ind);
obj.SignalGenerator.frequency = freq / obj.SignalGenerator.freqUnit2Hz;

assert(obj.MWPulseTime <= obj.tau_us-obj.MW_buffer_time,'MW Pulse (including buffer) cannot be longer than tau.')

repumpTime = obj.repumpTime;
resOffset = obj.resOffset;
resPulse1Time = obj.resPulse1Time;
resPulse2Time = obj.resPulse2Time;
resPulse1Counter1 = obj.resPulse1Counter1;
resPulse1Counter2= obj.resPulse1Counter2;
resPulse2Counter1 = obj.resPulse2Counter1;
resPulse2Counter2 = obj.resPulse2Counter2;

samples = obj.samples;

repumpLine = obj.repumpLaser.PB_line-1;% need to  fix 532_PB
resLine = obj.resLaser.PB_line-1;
APDline = obj.APDline-1;


s = sequence('AllOpticalT1');
repumpChannel = channel('repump','color','g','hardware',repumpLine);
resChannel = channel('resonant','color','r','hardware',resLine);
APDchannel = channel('APDgate','color','k','hardware',APDline,'counter','APD1'); %hard coded gate and APD
MWchannel = channel('MW','color','b','hardware',obj.SignalGenerator.PB_line-1);
s.channelOrder = [repumpChannel, resChannel, APDchannel,MWchannel];

g = node(s.StartNode,repumpChannel,'delta',0);
g = node(g,repumpChannel,'units','us','delta',repumpTime);

r = node(g,resChannel,'units','us','delta',resOffset);
node(r,APDchannel,'delta',0);
node(r,APDchannel,'units','us','delta',resPulse1Counter1);
node(r,APDchannel,'units','us','delta',resPulse1Time-resPulse1Counter2);
node(r,APDchannel,'units','us','delta',resPulse1Time);
r = node(r,resChannel,'units','us','delta',resPulse1Time);

n = node(r,MWchannel,'units','us','delta',obj.MW_buffer_time);
node(n,MWchannel,'units','us','delta',obj.MWPulseTime);

r = node(r,resChannel,'units','us','delta',obj.tau_us);
node(r,APDchannel,'delta',0);
node(r,APDchannel,'units','us','delta',resPulse2Counter1);
node(r,APDchannel,'units','us','delta',resPulse2Time-resPulse2Counter2);
node(r,APDchannel,'units','us','delta',resPulse2Time);
r = node(r,resChannel,'units','us','delta',resPulse2Time);

s.repeat = samples;
pulseSeq = s;
end
