function scanfit = SlowScanFit(slow,varargin)
%SlowScanFit takes in a scan object with fields freqs and counts, and fits
%this to N gaussians.
% INPUTS
%   slow = a slowscan struct with at least fields freqs and counts
%   promthresh = optional input argument for significance of peak
%       prominence in determining how many peaks to fit in the model
%   SNRthresh = optional input argument for how high SNR a peak needs to be
%       after fitting in order to be returned by the fit function
% OUTPUTS
%   scanfit = struct with fields
%       fit = fit object 
%       gof = goodness of fit
%       amps = amplitudes of located peaks in fit model
%       wids = widths of located peaks
%       locs = frequency centers of located peaks
%       snrs = signal-to-noise of located peaks

if nargin < 2
    promthresh = 3;
else
    promthresh = varargin{1};
end
if nargin < 3
    SNRthresh = NaN;
else
    SNRthresh = varargin{2};
end

x = slow.freqs;
y = slow.counts;

% x measured from wavemeter, so not gurantee they are strictly increasing, as needed for findpeaks
[x,I] = sort(x);
y = y(I);
mask = find(diff(x)==0);
x(mask) = [];
y(mask) = [];
freqstep = min(diff(x));

try %findpeaks is finicky; if it fails or errors, just assume data unparsable and no peaks
    [~, locs, wids, proms] = findpeaks(y,x);
    [f,xi] = ksdensity(proms);
    [~, prom_locs, prom_wids, prom_proms] = findpeaks(f,xi);
    [~,I] = sort(prom_proms,'descend');
    sortwids = prom_wids(I);
    sortlocs = prom_locs(I);
    thresh = sortlocs(1)+promthresh*sortwids(1); %threshold is promthresh number of wids away from most prominent peak
    
    prommask = proms > thresh;
    widmask = wids > freqstep; %mask by width of at least one pixel
    peakmask = and(prommask,widmask);
    i = sum(peakmask);
catch err
    warning(err.message); %throw error as warning
    i = 0;
end

if i==0
    scanfit.fit = [];
    scanfit.amps = [];
    scanfit.locs = [];
    scanfit.wids = [];
    scanfit.snrs = [];
    return
end

fit_type = gaussN(i);
options = fitoptions(fit_type);

upper_amps = 5*max(y)*ones(1,i);
lower_amps = zeros(1,i);
start_amps = proms(peakmask);

upper_pos = max(x)*ones(1,i);
lower_pos = min(x)*ones(1,i);
start_pos = locs(peakmask);

upper_width = (max(x)-min(x))*ones(1,i);
lower_width = freqstep*ones(1,i);
start_width = wids(peakmask);

options.Upper = [upper_amps upper_pos upper_width max(y)];
options.Lower = [lower_amps lower_pos lower_width 0     ];
options.Start = [start_amps start_pos start_width median(y)];

[f,gof] = fit(x',y',fit_type,options);

fitcoeffs = coeffvalues(f);
amps = fitcoeffs(1:i);
locs = fitcoeffs(i+1:2*i);
wids = fitcoeffs(2*i+1:3*i);
noise = std(f(x)-y'); %get noise from residuals

widmask = wids < freqstep; %find peaks that are too narrow
if ~isnan(SNRthresh) %if an SNR threshold has been specified
    noisemask = amps/noise < SNRthresh; %find peaks that aren't above SNR
    mask = or(widmask,noisemask);
else
    mask = widmask;
end
amps(mask) = []; %if too narrow or below SNR (if specified), remove
locs(mask) = [];
wids(mask) = [];

scanfit.fit = f;
scanfit.gof = gof;
[scanfit.amps, I] = sort(amps,'descend'); %sort in descending order, and hold onto index!
scanfit.locs = locs(I); %reorder to be in descending magnitude
scanfit.wids = wids(I);
scanfit.snrs = scanfit.amps/noise;

end