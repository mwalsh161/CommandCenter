function [delay, ontime] = CalibrateDelay(laserLine,apdLine,NIDAQ_dev,PB_ip)
%CalibrateDelay Builds sequence and runs a slow scan while updating ax
%   laserline = hardware line for laser being calibrated (0 indexed)
%   APDline = hardware line for APD being used for calibration

apdBin = 0.1; %resolution of APD bin in us
maxDelay = 10; %maximum expeceted delay in us
maxCounts = 1e2;
nidaq = Drivers.NIDAQ.dev.instance(NIDAQ_dev);
pb = Drivers.PulseBlaster.instance(PB_ip);

% Note, BuildCalibrateSequence resets offsets to [0,0]

SNR = 6; %averages will be increased until SNR on counts is this

% First, figure out the number of averages needed to get desired SNR
s = calibrate.BuildCalibrateSequence(laserLine,2*maxDelay,apdLine,apdBin,maxDelay,1000); %builds sequence object
apdPS = APDPulseSequence(nidaq,pb,s);
f = figure('visible','on','name',mfilename);
ax = axes('Parent',f);
p = plot(NaN,'Parent',ax);
runFlag = 0;
datSNR = 0;
while ~runFlag || isnan(datSNR) || datSNR < SNR
    if runFlag
        if ~isnan(datSNR)
            avgs = round(s.repeat*(SNR/datSNR)^2);
        else
            % Why would it get here?
            avgs = round(s.repeat*10);
        end
        s.repeat = avgs;
    end
    if s.repeat > 1e6
        error('Failed calibration of laser delay; unable to reach requested SNR.');
    end
    apdPS.start(maxCounts);
    title(ax,sprintf('Determining averages: %i',s.repeat));
    apdPS.stream(p);
    countsON = p.YData;
    datSNR = nanmean(countsON)/(nanstd(countsON)/sqrt(s.repeat));
    runFlag = 1;
end

%get reference laser off measurement
s = calibrate.BuildCalibrateSequence(laserLine,0,apdLine,apdBin,0,s.repeat); %if laserTime = 0, then just APD, no laser pulse
apdPS = APDPulseSequence(nidaq,pb,s);
apdPS.start(maxCounts);
title(ax,sprintf('Determining off reference. Using %i avgs.',s.repeat))
apdPS.stream(p);
countsOFF = p.YData;

meanON = nanmean(countsON);
stderrON = nanstd(countsON)/sqrt(s.repeat);
meanOFF = nanmean(countsOFF);
stderrOFF = nanstd(countsOFF)/sqrt(s.repeat);

%get reference zero delay measurement
[s, ~, a] = calibrate.BuildCalibrateSequence(laserLine,maxDelay,apdLine,apdBin,0,s.repeat);
apdPS = APDPulseSequence(nidaq,pb,s);
apdPS.start(maxCounts);
title(ax,sprintf('Determining off reference. Using %i avgs.',s.repeat))
apdPS.stream(p);
mean0 = nanmean(p.YData);

%determine necessary search directions
searchDir = [];
searchBound = [];
if mean0 >= meanOFF+stderrOFF
    searchDir = [searchDir -1]; %must search in negative direction
    searchBound = [searchBound meanOFF+stderrOFF]; %bound for negative direction search
end
if mean0 <= meanON-stderrON
    searchDir = [searchDir 1]; %must search in positive direction
    searchBound = [searchBound meanON-stderrON]; %bound for positive direction search
end

counts = mean0;
delays = 0;
debug = figure('name','Searching');
debugax = axes('Parent',debug);
while ~isempty(searchDir)
    a.delta = 0;
    while sum(searchDir(1)*(searchBound(1) - counts) <= 0) < 10
        %loop through increasing delta in each direction until have at
        %least 10 points on either side of rising edge
        a.delta  = a.delta + searchDir(1)*100; %shift by 10 ns each time - this could be more intelligent
        apdPS.start(maxCounts);
        apdPS.stream(p);
        counts(end+1) = mean(p.YData);
        delays(end+1) = a.delta;
        plot(debugax,delays,counts);
        hold(debugax,'on');
        plot(debugax,delays,searchBound(1)*ones(1,length(delays)),'g--');
        hold(debugax,'off');
        title(debugax,sprintf('searchDir: %s, counts: %i',num2str([1,2],'%i,'),sum(searchDir(1)*(searchBound(1) - counts) <= 0)))
        s.draw;
        drawnow
    end
    searchDir(1) = [];
    searchBound(1) = [];
end

%perform fit to error function (convolution of gaussian and heaviside)
[~,I] = min(abs(mean([meanON,meanOFF])-counts));
[~,start] = min(abs(0.1*(meanON-meanOFF)+meanOFF-counts));
[~,stop] = min(abs(0.9*(meanON-meanOFF)+meanOFF-counts));
c0 = [meanON, delays(I), abs(delays(stop)-delays(start)), meanOFF];
fit = @(c,x) c(1)*(0.5+0.5*erf((x-c(2))/(c(3)*sqrt(2))))+c(4);
c = lsqcurvefit(fit,c0,delays,counts);
hold(debugax,'on');
plot(debugax,delays,fit(c,delays),'r');
hold(debugax,'off');

%set hardware line delay and ontime
delay = c(2);
ontime = 3*c(3); %3 sigma is >99.9% contrast
channel('Laser','hardware',laserLine,'offset',[delay ontime]);
