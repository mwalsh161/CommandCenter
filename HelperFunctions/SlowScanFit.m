function scanfit = SlowScanFit(slow,SNRThresh)
SNRThresh = 3.5;
x = slow.freqs;
y = slow.counts;
z = slow.volts;

% x measured from wavemeter, so not gurantee they are increasing (for findpeaks)
% Furthermore, it has to be strictly increasing
[x,I] = sort(x);
y = y(I);
z = z(I);
mask = find(diff(x)==0);
x(mask) = [];
y(mask) = [];
z(mask) = [];

[pks, locs, wids, proms] = findpeaks(y,x);
sortproms = sort(proms);
sortproms = sortproms(1:round(.9*end));
peakmask = proms > median(sortproms)+4*std(sortproms);
pos = locs(peakmask);
i = sum(peakmask);

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
freqstep = min(diff(x));

upper_amps = 5*max(y)*ones(1,i);
lower_amps = zeros(1,i);
start_amps = pks(peakmask);

upper_pos = max(x)*ones(1,i);
lower_pos = min(x)*ones(1,i);
start_pos = pos;

upper_width = (max(x)-min(x))*ones(1,i);
lower_width = freqstep*ones(1,i);
start_width = wids(peakmask);

options.Upper = [upper_amps upper_pos upper_width max(y)];
options.Lower = [lower_amps lower_pos lower_width 0     ];
options.Start = [start_amps start_pos start_width median(y)];

[f,~] = fit(x',y',fit_type,options);

fitcoeffs = coeffvalues(f);
amps = fitcoeffs(1:i);
locs = fitcoeffs(i+1:2*i);
wids = fitcoeffs(2*i+1:3*i);
noise = std(f(x)-y'); %get noise from residuals

widmask = wids < 2*freqstep; %find peaks that are too narrow
noisemask = amps/noise < SNRThresh; %find peaks that aren't above SNR
mask = and(widmask,noisemask);
amps(mask) = []; %if both too narrow and not above SNR, remove
locs(mask) = [];
wids(mask) = [];

scanfit.fit = f;
[scanfit.amps, I] = sort(amps,'descend'); %sort in descending order, and hold onto index!
scanfit.locs = locs(I); %reorder to be in descending magnitude
scanfit.wids = wids(I);
scanfit.snrs = scanfit.amps/noise;

end