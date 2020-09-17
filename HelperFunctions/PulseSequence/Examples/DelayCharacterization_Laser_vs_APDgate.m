

%% Setup Pulse Sequence to cahracterize delay between laser and apd gating

cLaser = channel('laser','color','r','hardware',0,'offset',900);
% cSGtrig = channel('SGtrig','color','b','offset',0,'hardware',1);
cAPDgate = channel('pbAPDgate','color','g','hardware',2,'offset',130,'counter','APD1');
% cMWswitch = channel('MWswitch','color','b','offset',0,'hardware',3);

cDummy = channel('Dummy', 'color','k', 'hardware',9, 'offset',0);

APDgateDuration = 300; % ns
LaserPulseDuration = 300; %ns
DelayBTWLaserAndAPD = 1500; % ns
% TotalLoopDuration = 2*APDgateDuration+2*DelayBTWLaserAndAPD+LaserPulseDuration;
FinalStartDelayAPD = 3000; %ns

TotalLoopDuration = 5000;

nOfStep = 41;
xFactor = FinalStartDelayAPD/(nOfStep-1);


s = sequence('Laser - APDgate delay calib');

nS = node(s.StartNode,'n','type','start','delta',0,'units','ns'); 

nD = node(nS,cDummy,'delta',0,'units','ns'); %start transition (low to high) of a dummy pulse
nD = node(nD,cDummy,'delta',12,'units','ns'); %stop transition (high to low) of dummy pulse after 2 ns

x = sym('n');
f(x) = sym('f(x)');
f(x) = xFactor*(x-1); 
n = node(nD,cAPDgate,'delta',f,'dependent',{'n'},'units','ns');
n = node(n,cAPDgate,'delta',APDgateDuration,'units','ns'); % set duration of APD gate

n = node(nD, cLaser, 'delta',DelayBTWLaserAndAPD+APDgateDuration,'units','ns'); % start Laser pulse (lot to high transition) 400 ns after the end of the dummy pulse
n = node(n, cLaser, 'delta',LaserPulseDuration,'units','ns');% set duration of laser pulse

n = node(nD,nOfStep,'type','end','delta',TotalLoopDuration,'units','ns');

s.channelOrder = [cLaser,cAPDgate,cDummy];
s.draw;

sum(cellfun(@(x)(length(x)),s.compile))
s.repeat = 1e5

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
%%  Analyze data

DataAll = zeros(length(dataObj.YData)/s.repeat,s.repeat);
DataAll(:) = dataObj.YData;

xx = 1:nOfStep;
delayTimes = f(xx);
figure;
plot(delayTimes/1000,sum(DataAll,2,'omitnan'))
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
