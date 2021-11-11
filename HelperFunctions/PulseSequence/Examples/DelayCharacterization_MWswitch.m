obj.RF_Amp = 10;
obj.RF_Freq = 2.889e9;


obj.RF = Drivers.SMIQ03B.instance;
obj.RF.reset
obj.RF.Amplitude = obj.RF_Amp;
obj.RF.Frequency = obj.RF_Freq;
% obj.RF.FrequencyMode = 'FIX';
obj.RF.setAmplitude();
obj.RF.setFrequencyModeCW();
obj.RF.setFrequency();
obj.RF.setRFOn();
%% Setup Pulse Sequence to cahracterize delay between MW and Laser+Apd-gating

cLaser = channel('laser','color','r','hardware',0,'offset',900);
% cSGtrig = channel('SGtrig','color','b','offset',0,'hardware',1);
cAPDgate = channel('pbAPDgate','color','g','hardware',2,'offset',130,'counter','APD1');
cMWswitch = channel('MWswitch','color','b','hardware',3,'offset',100);

cDummy = channel('Dummy', 'color','k', 'hardware',9, 'offset',0);


LaserInitializeDuration = 2000; %ns
LaserReadoutDuration = 4000; %ns
LaserQuiteDuration = 2000; %ns

APDmeasDuration = 300; %ns
APDnormDuration = 300; %ns
APDquiteDuration = 2000; %ns

MWswitchDuration = 300; % ns
MWswitchInitialStart = 3500; 
MWswitchFinalStart = 4500; %ns
% LaserPulseDuration = 200; %ns
% DelayBTWLaserAndAPD = 1000; % ns
% TotalLoopDuration = 2*MWswitchDuration+2*DelayBTWLaserAndAPD+LaserPulseDuration;
% FinalStartDelayAPD = 2000; %ns
% TotalLoopDuration = 10000;

nOfStep = 21;
xFactor = (MWswitchFinalStart-MWswitchInitialStart)/(nOfStep-1);


s = sequence('Laser - MWswitch delay calib');

nS = node(s.StartNode,'n','type','start','delta',0,'units','ns');  % can't start at zero, so 2 ns after start of pulse sequence

nD = node(nS,cDummy,'delta',0,'units','ns'); %start transition (low to high) of a dummy pulse
nD = node(nD,cDummy,'delta',20,'units','ns'); %stop transition (high to low) of dummy pulse after 2 ns

% MW
x = sym('n');
f(x) = sym('f(x)');
f(x) = xFactor*(x-1)+MWswitchInitialStart; 
n = node(nD,cMWswitch,'delta',f,'dependent',{'n'},'units','ns');
n = node(n,cMWswitch,'delta',MWswitchDuration,'units','ns'); % set duration of APD gate

% laser
n = node(nD, cLaser, 'delta',0,'units','ns'); 
n = node(n, cLaser, 'delta',LaserInitializeDuration,'units','ns');
nR = node(n, cLaser, 'delta',LaserQuiteDuration,'units','ns');
n = node(nR, cLaser, 'delta',LaserReadoutDuration,'units','ns');

% APD gate
n = node(nR, cAPDgate, 'delta',0,'units','ns'); 
n = node(n, cAPDgate, 'delta',APDmeasDuration,'units','ns'); 
n = node(n, cAPDgate, 'delta',APDquiteDuration,'units','ns');
n = node(n, cAPDgate, 'delta',APDnormDuration,'units','ns');

n = node(n,nOfStep,'type','end','delta',2000,'units','ns');

s.channelOrder = [cLaser,cAPDgate,cMWswitch,cDummy];
s.draw;

sum(cellfun(@(x)(length(x)),s.compile))
s.repeat = 1e7

sum(cellfun(@(x)(length(x)),s.compile))
%% Run experiment
ni = Drivers.NIDAQ.dev.instance('Dev1');
pb = Drivers.PulseBlaster.instance('localhost');
APDpseq = Drivers.APDPulseSequence.instance(ni,pb,s);

% create a line object
figure
dataObj = plot(NaN,NaN)
APDpseq.start(1e3);
APDpseq.stream(dataObj)

pb.stop
obj.RF.setRFOff();

%%  Analyze data
% DataAll = zeros(2,nOfStep,s.repeat);
% % DataAll = zeros(length(dataObj.YData)/s.repeat,s.repeat);
% DataAll(:) = dataObj.YData;
% NormDataAll = squeeze(DataAll(1,:,:)./DataAll(2,:,:));
% NormDataAll(NormDataAll==Inf) = NaN;
% 
% NormDataAll = mean(DataAll,3,'omitnan')
% NormDataAll
% 
% xx = 1:nOfStep;
% delayTimes = f(xx);
% figure;
% plot(delayTimes/1000,mean(NormDataAll,2,'omitnan'))
% xlabel('Delay Time (\mus)')
% ylabel('Counts')

DataAll = zeros(2,nOfStep,s.repeat);
% DataAll = zeros(length(dataObj.YData)/s.repeat,s.repeat);
DataAll(:) = dataObj.YData;
% NormDataAll = squeeze(DataAll(1,:,:)./DataAll(2,:,:));
% NormDataAll(NormDataAll==Inf) = NaN;

MeanData = mean(DataAll,3,'omitnan');
NormData = MeanData(1,:)./MeanData(2,:);

xx = 1:nOfStep;
delayTimes = f(xx);
figure;
plot(delayTimes/1000,NormData)
xlabel('Delay Time (\mus)')
ylabel('Counts')

%%
% % Michael example test sequence
% % 
% % 
% c1 = channel('c1','color','r','offset',0.5,'hardware',0);
% c2 = channel('c2','color','b','offset',0,'hardware',1);
% c3 = channel('Trigger','color','g','hardware',2);
% 
% % Make sequence
% s = sequence('Test');
% 
% % Start adding some nodes
% n = node(s.StartNode,'n','type','start','delta',1,'units','us');
% 
% n = node(n,c1,'delta',1,'units','us');
% n = node(n,c1,'delta',2,'units','us');
% x = sym('n');
% f(x) = sym('f(x)');
% f(x) = x;
% n = node(n,c2,'delta',f,'dependent',{'n'},'units','us');
% n = node(n,c2,'delta',1,'units','us');
% n = node(n,2,'type','end','delta',1,'units','us');
% n = node(s.StartNode,c2,'delta',10,'units','us');
% 
% n = node(s.StartNode,c3,'units','us');
% n = node(n,c3,'delta',0.5,'units','us');
% 
% s.channelOrder = [c1,c2,c3];
% s.draw;
