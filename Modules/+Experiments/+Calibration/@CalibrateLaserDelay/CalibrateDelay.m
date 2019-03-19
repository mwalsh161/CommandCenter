function [delay, ontime] = CalibrateDelay(obj)
%CalibrateDelay Builds sequence and runs a slow scan while updating ax
%   laserline = hardware line for laser being calibrated
%   APDline = hardware line for APD being used for calibration

assert(~obj.abort_request,'User aborted');

% Note, BuildCalibrateSequence resets offsets to [0,0]

% First, figure out the number of averages needed to get desired SNR
s = obj.BuildCalibrateSequence(2*obj.maxDelay,obj.maxDelay); %builds sequence object
s.repeat = 10;
apdPS = APDPulseSequence(obj.Ni,obj.pulseblaster,s);
runFlag = 0;
datSNR = 0;
p = plot(NaN,NaN,'Parent',obj.ax);

while ~runFlag || isnan(datSNR) || datSNR < obj.SNR
    assert(~obj.abort_request,'User aborted');
    if runFlag
        if ~isnan(datSNR)
            avgs = round(s.repeat*(obj.SNR/datSNR)^2);
        else
            % Why would it get here?
            avgs = round(s.repeat*10);
        end
        s.repeat = avgs;
    end
    if s.repeat > obj.repeatMax
        error('Failed calibration of laser delay; unable to reach requested SNR.');
    end
    apdPS.start(obj.maxCounts);
    title(obj.ax,sprintf('Determining averages: %i',s.repeat));
    apdPS.stream(p);
    countsON = p.YData;
    datSNR = nanmean(countsON)/(nanstd(countsON)/sqrt(s.repeat));
    runFlag = 1;
end


assert(~obj.abort_request,'User aborted');
%get reference laser off measurement
s = obj.BuildCalibrateSequence(0,0); %if laserTime = 0, then just APD, no laser pulse
s.repeat = avgs;
apdPS = APDPulseSequence(obj.Ni,obj.pulseblaster,s);
apdPS.start(obj.maxCounts);
apdPS.stream(p);
countsOFF = p.YData;
%% stop streaming counts to data axis
obj.f = figure('visible','off','name',mfilename);
a = axes('Parent',obj.f);
p = plot(NaN,NaN,'Parent',a);
%% 

meanON = nanmean(countsON);
stderrON = nanstd(countsON)/sqrt(s.repeat);
meanOFF = nanmean(countsOFF);
stderrOFF = nanstd(countsOFF)/sqrt(s.repeat);

%get reference zero delay measurement
[s, ~, a] = obj.BuildCalibrateSequence(obj.maxDelay,0);
s.repeat = avgs;
apdPS = APDPulseSequence(obj.Ni,obj.pulseblaster,s);
title(obj.ax,sprintf('Determining off reference. Using %i avgs.',s.repeat))
apdPS.start(obj.maxCounts);
apdPS.stream(p);
mean0 = nanmean(p.YData);

assert(~obj.abort_request,'User aborted');
%determine necessary search directions
searchDir = [];
searchBound = [];
boundslower = meanOFF + 3*stderrOFF;
boundhigher = meanON-3*stderrON;
if mean0 >= boundslower
    searchDir = [searchDir -1]; %must search in negative direction
    searchBound = [searchBound boundslower]; %bound for negative direction search
end

if mean0 <= boundhigher
    searchDir = [searchDir 1]; %must search in positive direction
    searchBound = [searchBound boundhigher]; %bound for positive direction search
end

counts = mean0;
delays = 0;
while ~isempty(searchDir)
    a.delta = 0;
    while sum(searchDir(1)*(searchBound(1) - counts) <= 0) < 10
        assert(~obj.abort_request,'User aborted');
        %loop through increasing delta in each direction until have at
        %least 10 points on either side of rising edge
        a.delta  = a.delta + obj.stepSize; %shift by 10 ns each time - this could be more intelligent
        apdPS.start(obj.maxCounts);
        apdPS.stream(p);
        counts(end+1) = mean(p.YData);
        delays(end+1) = a.delta;
        plot(obj.ax,delays,counts);
        hold(obj.ax,'on');
        plot(obj.ax,delays,searchBound(1)*ones(1,length(delays)),'g--');
        hold(obj.ax,'off');
        title(obj.ax,sprintf('searchDir: %s, counts: %i',num2str([1,2],'%i,'),sum(searchDir(1)*(searchBound(1) - counts) <= 0)))
        ylabel(obj.ax,'Counts')
        xlabel(obj.ax,'delay (ns)')
        if abs(a.delta) >= obj.maxDelay*1000
            break  %break out of while loop because you have hit the maximum delay
        end
    end
    searchDir(1) = [];
    searchBound(1) = [];
end
assert(~obj.abort_request,'User aborted');
%perform fit to error function (convolution of gaussian and heaviside)
[~,I] = min(abs(mean([meanON,meanOFF])-counts));
[~,start] = min(abs(0.1*(meanON-meanOFF)+meanOFF-counts));
[~,stop] = min(abs(0.9*(meanON-meanOFF)+meanOFF-counts));
c0 = [meanON, delays(I), abs(delays(stop)-delays(start)), meanOFF];
fit = @(c,x) c(1)*(0.5+0.5*erf((x-c(2))/(c(3)*sqrt(2))))+c(4);
c = lsqcurvefit(fit,c0,delays,counts);
hold(obj.image_axes,'on');
plot(obj.image_axes,delays,fit(c,delays),'r');
hold(obj.image_axes,'off');

%set hardware line delay and ontime
delay = c(2);
ontime = 3*c(3); %3 sigma is >99.9% contrast
channel('Laser','hardware',obj.laser.PBline,'offset',[delay ontime]);
msgbox(sprintf('Delay is %d ns and ontime is %d ns',delay,ontime))
end
        