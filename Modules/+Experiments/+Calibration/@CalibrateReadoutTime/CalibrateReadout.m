function [ReadoutTime] = CalibrateReadout(obj)
%CalibrateReadout sweeps a readout time to determine optimum readout time for your laser power 
assert(~obj.abort_request,'User aborted');

%% 

% First, figure out the number of averages needed to get desired SNR. Use
% the initial readoutTime as baseline

readOutVector = obj.determineReadOutVector;
obj.ReadOutTime = readOutVector(1);
s = obj.BuildCalibrateSequence(obj.ReadOutTime); %builds sequence object
s.repeat = 10;
apdPS = APDPulseSequence(obj.Ni,obj.pulseblaster,s);
p = plot(NaN,NaN,'Parent',obj.ax);
runFlag = 0;
datSNR = 0;
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
        error('Failed calibration of readout time; unable to reach requested SNR.');
    end
    apdPS.start(obj.maxCounts);
    title(obj.ax,sprintf('Determining averages: %i',s.repeat));
    apdPS.stream(p);
    countsON = p.YData;
    datSNR = nanmean(countsON)/(nanstd(countsON)/sqrt(s.repeat));
    runFlag = 1;
end
%% calculate background contrast

obj.f = figure('visible','off','name',mfilename);
a = axes('Parent',obj.f);
dataObj = plot(NaN,NaN,'Parent',a);

assert(~obj.abort_request,'User aborted');
s = obj.BuildCalibrateSequence(obj.reInitializationTime);
s.repeat = avgs;
apdPS = APDPulseSequence(obj.Ni,obj.pulseblaster,s);
apdPS.start(obj.maxCounts);
apdPS.stream(dataObj);
obj.background = squeeze(mean(dataObj.YData(1:2:end)))./squeeze(mean(dataObj.YData(2:2:end)));
%% at this point the desired number of repeats have been calculated now to 
%sweep the readoutime

assert(~obj.abort_request,'User aborted');

obj.SG.on;

%initialize some of the parameter
obj.data.contrast_vector = NaN(1,numel(readOutVector));
obj.data.error_vector =  NaN(1,numel(readOutVector));

for time = 1:numel(readOutVector)
    assert(~obj.abort_request,'User aborted');
    obj.ReadOutTime = readOutVector(time); %change the read out time
    s = obj.BuildCalibrateSequence(obj.ReadOutTime); %builds sequence object
    s.repeat = avgs;
    apdPS = APDPulseSequence(obj.Ni,obj.pulseblaster,s);
    apdPS.start(obj.maxCounts);
    apdPS.stream(dataObj);
    
    obj.data.raw_data(time) = squeeze(mean(dataObj.YData(1:2:end)));
    obj.data.raw_var(time) = squeeze(var(dataObj.YData(1:2:end)));
    obj.data.norm_data(time) = squeeze(mean(dataObj.YData(2:2:end)));
    obj.data.norm_var(time) = squeeze(var(dataObj.YData(2:2:end)));
    num_data_bins = length(dataObj.YData)/2;
    
    %transient calculations for current readoutime to get
    %contrast and error
    raw_data_total = squeeze(nanmean(obj.data.raw_data(time)));
    raw_err_total = sqrt(squeeze(nanmean(obj.data.raw_var(time)))/(num_data_bins));
    norm_data_total = squeeze(nanmean(obj.data.norm_data(time)));
    norm_err_total = sqrt(squeeze(nanmean(obj.data.norm_data(time)))/(num_data_bins));
    
    obj.data.contrast_vector(time) = raw_data_total./norm_data_total;
    obj.data.error_vector(time) = obj.data.contrast_vector(time)*...
        sqrt((raw_err_total/raw_data_total)^2+(norm_err_total/norm_data_total)^2);
    obj.plot_data
    title(obj.ax,sprintf('Performing ReadOut %i of %i',time,numel(readOutVector)))
end

%% data has been calculated now determine when the optimal SNR was reached

obj.data.SNR_vec = (obj.background-obj.data.contrast_vector)./obj.data.error_vector; %determine the SNR for each time
[~,maxIndex] = max(obj.data.SNR_vec);
ReadoutTime = readOutVector(maxIndex);
end