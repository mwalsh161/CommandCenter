function [ scan ] = SurveyScan(obj,averages,points,axx)
%SlowScan Builds sequence and runs a slow scan while updating ax
%   averages = number of repetitions per frequency point
%   points = number of frequency points
%   axx = axis on which to plot scan data

obj.logger.log(sprintf('SurveyScan: avg: %i, points: %i',averages,points))

%Build the pulse sequence and associated objects
assert(isvalid(axx),'Slow scan requires valid axes for plotting.')
s = obj.BuildPulseSequence(obj.greentime,obj.redtime,averages); %builds sequence object
apdPS = APDPulseSequence(obj.nidaq,obj.pb,s);
f = figure('visible','off','name',mfilename);
a = axes('Parent',f);
p = plot(NaN,'Parent',a);

%Allocate memory and build data structure
percents = linspace(0, 100, points); %survey scans should scan full 0 to 100 range
volts = NaN(1,points);
freqs = NaN(1,points);
counts = NaN(1,points);
stds = NaN(1,points);

%Run sequence
ax = plotyy(axx,percents,counts,percents,freqs);  % Keeps original ax, and makes second one
hold(ax(1),'on'); hold(ax(2),'on');
upperError = plot(ax(1),percents,counts+stds,'color',[1 .5 0],'LineStyle','--');
lowerError = plot(ax(1),percents,counts-stds,'color',[1 .5 0],'LineStyle','--');
upperShot = plot(ax(1),percents,counts+stds,'b--');
lowerShot = plot(ax(1),percents,counts-stds,'b--');
dat = plot(ax(1),percents,counts,'color','b');
freqsH = plot(ax(2),percents,freqs,'color','r');
ylabel(ax(1),'Counts');
ylabel(ax(2),'Frequency (THz)');
xlabel(ax(1),'Piezo Percentage');
hold(ax(1),'off'); hold(ax(2),'off');
set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')

err = [];
try
%Turn off Track Mode
obj.rl.serial.TrackMode = 'off';
%Turn off wavemeter PID tracking
obj.wavemeter.setPIDstatus(false);

for i = 1:points
    assert(~obj.abort_request,'User aborted');
    obj.rl.LaserOffset(percents(i));
    apdPS.start(1000);
    apdPS.stream(p);
    assert(~sum(isnan(p.YData)),'Failed to read all APD samples.')
    counts(i) = nanmean(p.YData);
    stds(i) = nanstd(p.YData)/sqrt(s.repeat);
    freqs(i) = obj.wavemeter.getFrequency;
    volts(i) = obj.wavemeter.getDeviationVoltage;
    
    freqsH.YData = freqs;
    upperError.YData = counts + stds;
    lowerError.YData = counts - stds;
    upperShot.YData = counts + sqrt(counts)/sqrt(s.repeat);
    lowerShot.YData = counts - sqrt(counts)/sqrt(s.repeat);
    dat.YData = counts;
    drawnow;
end
catch err
end
delete(f);

scan.percents = percents;
scan.volts = volts;
scan.freqs = freqs;
scan.counts = counts;
scan.stds = stds;
scan.averages = averages;
scan.ScanFit = [];

%reset piezo to 50%
obj.rl.LaserOffset(50);

end

