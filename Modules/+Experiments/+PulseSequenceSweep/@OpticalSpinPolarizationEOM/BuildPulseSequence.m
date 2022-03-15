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

if obj.invert_MW_line
    node(g,MWChannel,'units','us','delta',0);
end

g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
resStart = node(g,resChannel,'units','us','delta',obj.resOffset_us);
resStop = node(resStart,resChannel,'units','us','delta',obj.resTime_us);
node(resStart,MWChannel,'units','us','delta',0);
node(resStop,MWChannel,'units','us','delta',0);


for n = 1:nCounters
    counterStart = node(resStart,APDchannel,'units','us','delta',(n-1)*(obj.counterDuration+obj.counterSpacing));
    node(counterStart,APDchannel,'units','us','delta',obj.counterDuration);
end

end
