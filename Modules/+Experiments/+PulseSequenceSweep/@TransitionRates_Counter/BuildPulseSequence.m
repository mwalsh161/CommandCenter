function s = BuildPulseSequence(obj)
% BuildPulseSequence Builds pulse sequence for Transition Rates Measurement
% Disconnect APD and resonant laser from pulse blaster (APD readout from
% DAQ, resonant laser always on)

% nCounters = obj.nCounterBins;

s = sequence('TransitionRatesMeasurement');
repumpChannel = channel('repump','color','g','hardware',obj.repumpLaser.PB_line-1);
% resChannel = channel('resonant','color','r','hardware',obj.resLaser.PB_line-1);
% MWChannel = channel('MWChannel','color','r','hardware',obj.MW_line-1);
% APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
s.channelOrder = [repumpChannel];
g = node(s.StartNode, repumpChannel, 'units', 'us', 'delta', obj.resOffset_us);
g = node(g, repumpChannel, 'units','us','delta', obj.repumpTime_us);

% s.draw()
end
