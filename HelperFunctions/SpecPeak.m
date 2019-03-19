function varargout = SpecPeak(spec,lower_pos,upper_pos)

x = spec.x;
y = spec.y;

smooth_nm = 2; %rolling average smoothing window size in nm
smooth_wind = round(smooth_nm/median(diff(x))); %smoothing window size in pixels

if nargin < 3
    upper_pos = max(x);
    if nargin < 2
        lower_pos = min(x);
    end
end

y = y-smooth(y,smooth_wind); %filter
[pks, locs, wids, proms] = findpeaks(y,x);
peakmask = proms < median(proms)+4*std(proms); %exclude if insufficient prominence
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
    y(mask) = [];
    
    fit_type = gaussN(i);
    lwidthbound = (max(x)-min(x))/length(x);
    options = fitoptions(fit_type);
    
    start_offset = median(y);
    
    upper_amps = 5*max(y)*ones(1,i);
    lower_amps = zeros(1,i);
    start_amps = pks'-start_offset;
    
    upper_pos = upper_pos*ones(1,i); %these limits are hardcoded for the NV and laser - peaks outside of here are not NVs
    lower_pos = lower_pos*ones(1,i);
    start_pos = locs';
    
    upper_width = 3*wids';
    lower_width = lwidthbound*ones(1,i);
    start_width = wids';
    
    options.Upper = [upper_amps upper_pos upper_width max(y)      ];
    options.Lower = [lower_amps lower_pos lower_width min(y)      ];
    options.Start = [start_amps start_pos start_width start_offset];
    
    [f,gof] = fit(x,y,fit_type,options);
    
    fitcoeffs = coeffvalues(f);
    peakamps = fitcoeffs(1:i);
    peaklocs = fitcoeffs(i+1:2*i);
    
    [peakamps, I] = sort(peakamps,'descend'); %sort in descending order, and hold onto index!
    peaklocs = peaklocs(I); %reorder to be in descending magnitude
end
varargout = {peaklocs, peakamps, f, gof};
varargout = varargout(1:nargout);
end