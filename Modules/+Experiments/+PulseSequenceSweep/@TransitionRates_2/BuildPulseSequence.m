function s = BuildPulseSequence(obj)
%BuildPulseSequence Builds pulse sequence for performing Transition measurements

% nCounters = obj.nCounterBins;

s = sequence('TransitionRates');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
% MWChannel = channel('MWChannel','color','r','hardware',obj.MW_line-1);
APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
s.channelOrder = [repumpChannel, resChannel, APDchannel];
g = node(s.StartNode, repumpChannel, 'units', 'us', 'delta', obj.resOffset_us);
resStart = node(s.StartNode, resChannel, 'units', 'us', 'delta', obj.resOffset_us);
node(resStart,APDchannel,'units','us','delta',0);
resStop = node(resStart,resChannel,'units','us','delta',obj.resTime_us);
node(resStop,APDchannel,'units','us','delta',0);
g = node(resStop, repumpChannel, 'units','us','delta', obj.resTime_us);

% s.draw()

%     for n = 1:nCounters
%         counterStart = node(resStart,APDchannel,'units','us','delta',(n-1)*(obj.counterDuration+obj.counterSpacing));
%         node(counterStart,APDchannel,'units','us','delta',obj.counterDuration);
%     end
end
