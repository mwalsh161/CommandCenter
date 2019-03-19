function [ scan ] = SlowScan(obj,averages,points,span,axx)
%SlowScan Builds sequence and runs a slow scan while updating ax
%   averages = number of repetitions per frequency point
%   points = number of frequency points
%   range = 1x2 vector of [start frequency, end frequency] in THz
%   axx = axis on which to plot scan data

obj.logger.log(sprintf('SlowScan: avg: %i, points: %i, span: [%0.2f,%0.2f]',averages,points,span))

%Build the pulse sequence and associated objects
assert(isvalid(axx),'Slow scan requires valid axes for plotting.')
s = obj.BuildPulseSequence(obj.greentime,obj.redtime,averages); %builds sequence object
apdPS = APDPulseSequence(obj.nidaq,obj.pb,s);
f = figure('visible','off','name',mfilename);
a = axes('Parent',f);
p = plot(NaN,'Parent',a);

%Allocate memory and build data structure
freqs = linspace(span(1), span(2), points);
volts = NaN(1,points);
counts = NaN(1,points);
std = NaN(1,points);

%Run sequence
ax = plotyy(axx,freqs,counts,freqs,volts);  % Keeps original ax, and makes second one
hold(ax(1),'on'); hold(ax(2),'on');
upperError = plot(ax(1),freqs,counts+std,'color',[1 .5 0],'LineStyle','--');
lowerError = plot(ax(1),freqs,counts-std,'color',[1 .5 0],'LineStyle','--');
upperShot = plot(ax(1),freqs,counts+std,'b--');
lowerShot = plot(ax(1),freqs,counts-std,'b--');
dat = plot(ax(1),freqs,counts,'color','b');
voltsH = plot(ax(2),freqs,volts,'color','r');
ylabel(ax(1),'Counts');
ylabel(ax(2),'Piezo Voltage (mV)');
xlabel(ax(1),'F');
hold(ax(1),'off'); hold(ax(2),'off');
set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')

err = [];
try
%Center piezo percentage
obj.rl.LaserOffset(50);
%Clear PID History
obj.wavemeter.ClearPIDHistory;

for i = 1:points
    assert(~obj.abort_request,'User aborted');
    try
        obj.rl.LaserSetpoint(freqs(i));
    catch err
        if i > 1 && isnan(counts(i-1))
            rethrow(err)
        else
            continue
        end
    end
    apdPS.start(1000);
    apdPS.stream(p);
    counts(i) = nanmean(p.YData);
    std(i) = nanstd(p.YData)/sqrt(s.repeat);
    volts(i) = obj.wavemeter.getDeviationVoltage;
    
    voltsH.YData = volts;
    upperError.YData = counts + std;
    lowerError.YData = counts - std;
    upperShot.YData = counts + sqrt(counts)/sqrt(s.repeat);
    lowerShot.YData = counts - sqrt(counts)/sqrt(s.repeat);
    dat.YData = counts;
    drawnow;
end
catch err
end
delete(f);

scan.freqs = freqs;
scan.counts = counts;
scan.std = std;
scan.volts = volts;
scan.averages = averages;
scan.ScanFit = [];

%turn PID back off
obj.wavemeter.setPIDstatus(false);
%obj.rl.LaserOffset(50);

if ~isempty(err)
    rethrow(err)
end
end

