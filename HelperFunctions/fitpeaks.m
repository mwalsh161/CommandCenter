function [vals,confs,fit_results,gofs,init,stop_condition] = fitpeaks(x,y,fit_type,span,userlimits,conf_level,stop_metric)
%FITPEAKS Takes in x, y pair and fits peaks optimizing r^2_adj and \chi^2_red
% r^2_adj == adjrsquared == r == adjusted R squared
% \chi^2_red == redchisquared == chi == reduced Chi squared
% Inputs brackets indicate optional:
%   x: vector of x values Nx1
%   y: vector of y values Nx1
%   [fit_type]: "gauss" or "lorentz" (default "gauss")
%   [span]: The span of the moving average used to calculate "init" (default 5)
%   [userlimits]: Any limits to impose on the fitted peak properties. Should be a
%       struct with any combination of fields (each an array of [min max]):
%       amplitudes: default [0, Inf]
%       widths: default [3.*min(diff(x)), (max(x)-min(x))] (min FWHM of 3 points)
%   [conf_level]: confidence interval level (default 0.95)
%   [stop_metric]: a string indicating what metric to check for stopping options (case insensiive):
%       r: only use rsquared (this means there can't be a test for no peaks
%       chi: only use chisquared (assuming poisson noise)
%       rANDchi (default): use both rsquared or chisquared at every step
%       FirstChi: use chisquared to check the first peak against no peaks,
%          then rsquared for the rest
% Outputs (each field is Mx1, M being number of peaks fit):
%   vals: struct with "locations", "amplitudes", "widths", "SNRs" of fit results
%   confs: struct with same field as vals with symmetric confidence interval for given conf_level
%   fit_results: MATLAB cfit objects (M+1x1 cell) produced by the "fit" function; one
%       for each attempt (0 -> M peaks).
%   gofs: (M+1x1) array of gofs for each fit_results (with added chisquared
%      assuming shot noise)
%   init: the raw output of findpeaks used to prime the fit
%   stop_condition: 0 if chisquared, 1 if rsquared
%
% Steps:
%   1) Use findpeaks on smoothed y and extract prominences
%   2) Order peaks by prominences
%   3) Number of peaks = n, where n goes from 1 -> length peaks
%       1) Fit n peaks (primed with pos, amp, wid from findpeaks)
%       2) Stop when \chi^2_adj gets further from 1 OR
%               when r^2_adj gets lower
%   4) Return results (including all fits except the one with diminishing
%   returns)
%
% The chi-squared metric is primarily useful to test the no-peak condition
%
% NOTE: Meaning of widths will depend on lorentz (FWHM) or gauss (sigma)

assert(length(x)==length(y),'x and y must be same length');
assert(ismatrix(x)&&ismatrix(y),'x and y must be matrices (e.g. 2 dimensional)')
assert(size(x,2)==1&&size(y,2)==1,'x and y must be column vectors (Nx1)')
% Order data
[x,I] = sort(x);
y = y(I);
dx = min(diff(x));
if nargin < 7 || isempty(stop_metric)
    stop_metric = 'rANDchi';
end
stop_metric = lower(stop_metric); % Case insensitive
assert(ismember(stop_metric,{'r','chi','firstchi','randchi'}), 'stop_metric must be "r", "chi", "FirstChi", or "rANDchi"');
if nargin < 6 || isempty(conf_level)
    conf_level = 0.95;
end
limits.amplitudes = [0, Inf];
limits.widths = [3*dx, (max(x)-min(x))];
if nargin > 4
    if isfield(userlimits,'amplitudes')
        assert(length(userlimits.amplitudes)==2,'Amplitudes should be array with [lower,upper]')
        limits.amplitudes = userlimits.amplitudes;
    end
    if isfield(userlimits,'widths')
        assert(length(userlimits.widths)==2,'Widths should be array with [lower,upper]')
        limits.widths = userlimits.widths;
    end
end
if nargin < 4 || isempty(span)
    span = 5; % This is also the default for the smooth method that is used
end
if nargin < 3 || isempty(fit_type)
    fit_type = 'gauss';
end
fit_type = lower(fit_type); % Case insensitive
assert(ismember(fit_type,{'gauss','lorentz'}), 'fit_type must be "lorentz" or "gauss"');

proms_y = smooth(y,span);
proms_y = [min(proms_y); proms_y; min(proms_y)];
[~, init.locs, init.wids, init.proms] = findpeaks(proms_y,[x(1)-dx; x; x(end)+dx]);
[init.proms,I] = sort(init.proms,'descend');
init.locs = init.locs(I);
init.wids = init.wids(I);

fit_results = {[]};
% Initial gof will be the case of just an offset and no peaks (a flat line whose best estimator is mean(y))
se = (y-mean(y)).^2; % square error
dfe = length(y) - 1; % degrees of freedom
gofs = struct('sse',sum(se),'redchisquare',sum(se/abs(mean(y)))/dfe,'dfe',dfe,...
              'rmse',sqrt(mean(se)),'rsquare',NaN,'adjrsquare',NaN); % can't calculate rsquared for flat line
stop_condition = NaN;
for n = 1:length(init.proms)
    if strcmp(fit_type,'gauss')
        [f,new_gof,output] = gaussfit(x, y, n, init, limits);
    else % fit_type assert requires this else to be lorentz
        [f,new_gof,output] = lorentzfit(x, y, n, init, limits);
    end
    new_gof.redchisquare = sum(output.residuals.^2./abs(f(x)))/new_gof.dfe; % Assume shot noise
    if (strcmp(stop_metric,'chi') || strcmp(stop_metric,'randchi') || (strcmp(stop_metric,'firstchi')&&n>1)) &&...
            abs(1-gofs(end).redchisquare) < abs(1-new_gof.redchisquare) % further from 1 than last
        stop_condition = 0;
        break
    end
    if (strcmp(stop_metric,'r') || strcmp(stop_metric,'randchi') || strcmp(stop_metric,'firstchi')) &&...
            gofs(end).adjrsquare > new_gof.adjrsquare                    % lower than last
        stop_condition = 1;
        break
    end
    % Otherwise, repeat and update our current best fit
    fit_results{end+1} = f; %#ok<AGROW> (relatively small arrays and unknown number of peaks)
    gofs(end+1) = new_gof; %#ok<AGROW> (relatively small arrays and unknown number of peaks)
end
assert(~isnan(stop_condition),'Good fit not found') % Condition promised never satisfied
if length(fit_results)==1 % No peaks
    vals = struct('amplitudes',[],'locations',[],'widths',[],'SNRs',[]);
    confs = struct('amplitudes',[],'locations',[],'widths',[],'SNRs',[]);
    return
end
n = n - 1; % Last fit was the failed one
fit_result = fit_results{end};

% get noise from residuals to calculate SNR
noise = std(fit_result(x)-y);

fitcoeffs = coeffvalues(fit_result);
vals.amplitudes = fitcoeffs(1:n);
vals.locations = fitcoeffs(n+1:2*n);
vals.widths = fitcoeffs(2*n+1:3*n);
vals.SNRs = vals.amplitudes./noise;

fitconfs = diff(confint(fit_result,conf_level))/2;
confs.amplitudes = fitconfs(1:n);
confs.locations = fitconfs(n+1:2*n);
confs.widths = fitconfs(2*n+1:3*n);
confs.SNRs = confs.amplitudes./noise;
end

function [f,gof,output] = gaussfit(x, y, n, init, limits)
    FWHM_factor = 2*sqrt(2*log(2));
    fit_type = gaussN(n);
    options = fitoptions(fit_type);

    upper_amps = limits.amplitudes(2).*ones(n,1);
    lower_amps = limits.amplitudes(1).*ones(n,1);
    start_amps = init.proms(1:n);
    
    upper_pos = max(x).*ones(n,1);
    lower_pos = min(x).*ones(n,1);
    start_pos = init.locs(1:n);
    
    upper_width = limits.widths(2).*ones(n,1)./FWHM_factor;
    lower_width = limits.widths(1).*ones(n,1)./FWHM_factor;
    start_width = init.wids(1:n)./FWHM_factor;
    
    options.Upper = [upper_amps; upper_pos; upper_width; max(y)];
    options.Lower = [lower_amps; lower_pos; lower_width; 0     ];
    options.Start = [start_amps; start_pos; start_width; median(y)];
    [f,gof,output] = fit(x,y,fit_type,options);
end

function [f,gof,output] = lorentzfit(x, y, n, init, limits)
    fit_type = lorentzN(n);
    options = fitoptions(fit_type);

    upper_amps = limits.amplitudes(2).*ones(n,1);
    lower_amps = limits.amplitudes(1).*ones(n,1);
    start_amps = init.proms(1:n);
    
    upper_pos = max(x).*ones(n,1);
    lower_pos = min(x).*ones(n,1);
    start_pos = init.locs(1:n);
    
    upper_width = limits.widths(2).*ones(n,1);
    lower_width = limits.widths(1).*ones(n,1);
    start_width = init.wids(1:n);
    
    options.Upper = [upper_amps; upper_pos; upper_width; max(y)];
    options.Lower = [lower_amps; lower_pos; lower_width; 0     ];
    options.Start = [start_amps; start_pos; start_width; median(y)];
    [f,gof,output] = fit(x,y,fit_type,options);
end