function varargout = SpecPeak(spec,peak_range,cutoff,filt_range)
%SpecPeak Takes in a spectrum object and optional fit arguments, and
%outputs peak information
% Inputs:
% spec = spectrum struct (as in that returned by spectrumload)
% (optional) peak_range = [2x1] double, need not be ordered, range of wavelengths for peakfinding - defaults to full range
% (optional) cutoff = double, threshold for peakfinding - defaults to 3 stds
% (optional) filtering range = [2x1] double, need not be ordered, bounds for frequency space filtering - defaults to DC filtering
% Outputs (varargout):
% peaklocs = [nx1] double, locations of fit peaks; descending by peak amplitude
% peakamps = [nx1] double, amplitudes of fit peaks; descending by peak amplitude
% f = fit object
% gof = goodness of fit

x = spec.x;
y = spec.y;

if nargin < 2
    upper_pos = max(x);
    lower_pos = min(x);
else
    lower_pos = min(peak_range);
    upper_pos = max(peak_range);
end
if nargin < 3
    cutoff = 3;
end
if nargin < 4
    lower_filt = 1e-10;
    upper_filt = max(x)-min(x);
else
    lower_filt = min(filt_range);
    upper_filt = max(filt_range);
end

[x,I] = sort(x); %sort in preparation for peakfinding, etc.
y = y(I);

y_filt = imgaussfilt(y,lower_filt/median(diff(x))) - imgaussfilt(y,upper_filt/median(diff(x)));
[pks, locs, wids, proms] = findpeaks(y_filt,x);
peakmask = proms < median(proms)+cutoff*std(proms); %exclude if insufficient prominence
pks(peakmask) = [];
locs(peakmask) = [];
wids(peakmask) = [];
proms(peakmask) = [];

rangeMask = or(locs<lower_pos,locs>upper_pos); %exclude out of range 
pks(rangeMask) = [];
locs(rangeMask) = [];
wids(rangeMask) = [];
proms(rangeMask) = [];

i = length(pks);

if i==0
    peaklocs = [];
    peakamps = [];
    f = NaN;
    gof = NaN;
else
    mask = or(x<lower_pos, x>upper_pos); %crop
    x(mask) = [];
    y_filt(mask) = [];
    
    fit_type = gaussN(i);
    lwidthbound = (max(x)-min(x))/length(x);
    options = fitoptions(fit_type);
    
    start_offset = median(y_filt);
    
    upper_amps = 5*(max(y_filt)-start_offset)*ones(1,i);
    lower_amps = zeros(1,i);
    start_amps = pks'-start_offset;
    
    upper_pos = upper_pos*ones(1,i); %these limits are hardcoded for the NV and laser - peaks outside of here are not NVs
    lower_pos = lower_pos*ones(1,i);
    start_pos = locs';
    
    upper_width = 3*wids';
    lower_width = lwidthbound*ones(1,i);
    start_width = wids';
    
    options.Upper = [upper_amps upper_pos upper_width max(y_filt) ];
    options.Lower = [lower_amps lower_pos lower_width min(y_filt) ];
    options.Start = [start_amps start_pos start_width start_offset];
    
    [f,gof] = fit(x,y_filt,fit_type,options);
    
    fitcoeffs = coeffvalues(f);
    peakamps = fitcoeffs(1:i);
    peaklocs = fitcoeffs(i+1:2*i);
    
    [peakamps, I] = sort(peakamps,'descend'); %sort in descending order, and hold onto index!
    peaklocs = peaklocs(I); %reorder to be in descending magnitude
end
varargout = {peaklocs, peakamps, f, gof};
varargout = varargout(1:nargout);
end