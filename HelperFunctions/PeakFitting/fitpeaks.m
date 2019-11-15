function [vals,confs,fit_results,gofs,init,stop_condition] = fitpeaks(x,y,varargin)
%FITPEAKS Takes in x, y pair and fits n peaks or optimizes some metric.
% The metrics can be r^2_adj, \chi^2_red or a simple prominence threshold
% r^2_adj == adjrsquared == r == adjusted R squared
% \chi^2_red == redchisquared == chi == reduced Chi squared
% Inputs; brackets indicate name,value optional pair:
%   x: vector of x values Nx1
%   y: vector of y values Nx1
%   [FitType]: "gauss" or "lorentz" (default "gauss")
%   [Span]: The span of the moving average used to calculate "init" (default 5)
%   [Width]: FWHM width limits to impose on the fitted peak properties.
%       Default [2.*min(diff(x)), (max(x)-min(x))] (min FWHM spanning 3 points)
%   [Amplitude]: Amplitude limits to impose on the fitted peak properties.
%       Default: [0, Inf].
%   [Locations]: Location limits in x to impose on the fitted peak properties.
%       Default: [min(x) max(x)]
%   [ConfLevel]: confidence interval level (default 0.95)
%   [n]: fit exactly n peaks (n > 0). Not compatible with AmplitudeSensitivity or StopMetric.
%   [AmplitudeSensitivity]: Number of standard deviations above median prominence.
%       Specifying a prominence threshold will fit the number of peaks > than
%       the calculated threshold. Not compatible with n or StopMetric.
%   [StopMetric]: a string indicating what metric to check for stopping options (case insensitive):
%       r: only use rsquared (this means there can't be a test for no peaks
%       chi: only use chisquared (assuming poisson noise)
%       rANDchi (default): use both rsquared or chisquared at every step
%       FirstChi: use chisquared to check the first peak against no peaks,
%          then rsquared for the rest
%       Not compatible with AmplitudeSensitivity or n.
%   [NoiseModel]: a function handle that takes inputs: x, y, modeled_y
%       where are of the current fit. Output must be a vector in the same shape of y.
%       Or one of the default built-ins named as a string (this is used in calculating \chi^2_red):
%           "empirical" (default): uses the variance of the residuals for all values
%           "shot": use val for each val in y
% Outputs (each field is Mx1, M being number of peaks fit):
%   vals: struct with "locations", "amplitudes", "widths", "SNRs" of fit results
%   confs: struct with same field as vals with symmetric confidence interval for given conf_level
%   fit_results: MATLAB cfit objects (M+1x1 cell) produced by the "fit" function; one
%       for each attempt (0 -> M peaks).
%   gofs: (M+1x1) array of gofs for each fit_results (with added chisquared
%      assuming shot noise)
%   init: the raw output of findpeaks used to prime the fit
%   stop_condition: 0 if chisquared, 1 if rsquared, NaN if "n" specified
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

p = inputParser;
validNumericArray = @(x) isnumeric(x) && ismatrix(x);
validColumnArray = @(x) size(x,2)==1;
validLimit = @(x)assert(validNumericArray(x)&&length(x)==2,...
                 'Limit should be numeric array with [lower,upper]');
addRequired(p,'x',@(x)validNumericArray(x)&&validColumnArray(x))
addRequired(p,'y',@(x)validNumericArray(x)&&validColumnArray(x))
parse(p,x,y);
% Order data and remove NaNs in y
[x,I] = sort(x);
y = y(I);
remove = isnan(y);
x(remove) = [];
y(remove) = [];
% Prepare input for findpeaks (strictly increasing)
[xp,~,idx] = unique(x,'stable');
yp = accumarray(idx,y,[],@mean); % Mean of duplicate points in x
dx = min(diff(xp));
assert(dx>0,'dx calculated to be <= 0');

addParameter(p,'FitType','gauss',@(x)any(validatestring(x,{'gauss','lorentz'})));
addParameter(p,'Span',5,@(x)isnumeric(x) && isscalar(x) && (x >= 0));
addParameter(p,'Width',[2*dx, (max(x)-min(x))],validLimit);
addParameter(p,'Amplitude',[0 Inf],validLimit);
addParameter(p,'Location',[min(x) max(x)],validLimit);
addParameter(p,'ConfLevel',0.95,@(x)numel(x)==1 && x < 1 && x > 0);
addParameter(p,'n',1,@(x)isnumeric(x) && isscalar(x) && (x >= 0));
addParameter(p,'AmplitudeSensitivity',1,@(x)isnumeric(x) && isscalar(x) && (x >= 0));
addParameter(p,'StopMetric','rANDchi',@(x)any(validatestring(x,{'r','chi','firstchi','randchi'})));
addParameter(p,'NoiseModel','empirical');
parse(p,x,y,varargin{:});
% Validate compatibility
not_compatible = {'n','StopMetric','AmplitudeSensitivity'};
pSpecified = setdiff(p.Parameters,p.UsingDefaults); % Get parameters specified
mask = ismember(not_compatible, pSpecified);
if sum(mask) > 1
    not_compatible = not_compatible(mask);
    fmted = cellfun(@(a)sprintf('''%s''',a),not_compatible,'uniformoutput',false);
    error('Cannot specify %s and %s together.',strjoin(fmted(1:end-1),', '),fmted{end});
end

p = p.Results;
% Further validation
assert(length(x)==length(y),'x and y must be same length');
% Case insensitive stuff
p.StopMetric = lower(p.StopMetric);
p.FitType = lower(p.FitType);
% Setup limits struct
limits.amplitudes = p.Amplitude;
limits.widths = p.Width;
limits.locations = p.Location;
limits.background = [0 max(y)];
% Setup noise model if string specified
if ~isa(p.NoiseModel,'function_handle')
    switch lower(p.NoiseModel)
        case 'shot'
            p.NoiseModel = @shot_noise;
        case 'empirical'
            p.NoiseModel = @empirical_noise;
    end
end
switch lower(p.FitType)
    case 'gauss'
        fit_function = @gaussfit;
    case 'lorentz'
        fit_function = @lorentzfit;
end

yp_smooth = smooth(yp,p.Span);
xp_extend = [x(1)-dx; xp; x(end)+dx];
yp_extend = [min(yp_smooth); yp_smooth; min(yp_smooth)];
[~, init.locations, init.widths, init.amplitudes] = findpeaks(yp_extend,xp_extend);
[init.amplitudes,I] = sort(init.amplitudes,'descend');
init.locations = init.locations(I);
init.widths = init.widths(I);
init.background = median(y);

usingN = ismember('n',pSpecified);
if ismember('AmplitudeSensitivity',pSpecified)
    usingN = true;
    % Calculate n
    [~, ~, ~, proms] = findpeaks(yp,xp); %get list of prominences
    [f,xi] = ksdensity(proms);
    [~, prom_locs, prom_wids, prom_proms] = findpeaks(f,xi); %find most prominent prominences
    [~,I] = sort(prom_proms,'descend');
    sortwids = prom_wids(I);
    sortlocs = prom_locs(I);
    thresh = sortlocs(1)+p.AmplitudeSensitivity *sortwids(1); %assume most prominent prominence corresponds to noise
    p.n = sum(init.amplitudes >= thresh);
end

fit_results = {[]};
% Initial gof will be the case of just an offset and no peaks (a flat line whose best estimator is median(y))
f = median(y)*ones(size(y));
se = (y-f).^2; % square error
dfe = length(y) - 1; % degrees of freedom
noise = noise_model(x,y,f,p.NoiseModel);
gofs = struct('sse',sum(se),'redchisquare',sum(se./noise)/dfe,'dfe',dfe,...
              'rmse',sqrt(mean(se)),'rsquare',NaN,'adjrsquare',NaN); % can't calculate rsquared for flat line
if usingN
    stop_condition = NaN;
    n = p.n;
    if n == 0 % No peaks
        vals = struct('amplitudes',[],'locations',[],'widths',[],'SNRs',[]);
        confs = struct('amplitudes',[],'locations',[],'widths',[],'SNRs',[]);
        return
    end
    [f,new_gof,output] = fit_function(x, y, n, init, limits);
    noise = noise_model(x,y,f(x),p.NoiseModel);
    new_gof.redchisquare = sum(output.residuals.^2./noise)/new_gof.dfe; % Assume shot noise
    fit_results{end+1} = f;
    gofs(end+1) = new_gof;
else
    stop_condition = NaN;
    for n = 1:length(init.amplitudes)
        [f,new_gof,output] = fit_function(x, y, n, init, limits);
        noise = noise_model(x,y,f(x),p.NoiseModel);
        new_gof.redchisquare = sum(output.residuals.^2./noise)/new_gof.dfe; % Assume shot noise
        if (strcmp(p.StopMetric,'chi') || strcmp(p.StopMetric,'randchi') || (strcmp(p.StopMetric,'firstchi')&&n>1)) &&...
                abs(1-gofs(end).redchisquare) < abs(1-new_gof.redchisquare) % further from 1 than last
            stop_condition = 0;
            break
        end
        if (strcmp(p.StopMetric,'r') || strcmp(p.StopMetric,'randchi') || strcmp(p.StopMetric,'firstchi')) &&...
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
end
fit_result = fit_results{end};
% get noise from residuals to calculate SNR
noise = std(fit_result(x)-y);

fitcoeffs = coeffvalues(fit_result);
vals.amplitudes = fitcoeffs(1:n);
vals.locations = fitcoeffs(n+1:2*n);
vals.widths = fitcoeffs(2*n+1:3*n);
vals.SNRs = vals.amplitudes./noise;

fitconfs = diff(confint(fit_result,p.ConfLevel))/2;
confs.amplitudes = fitconfs(1:n);
confs.locations = fitconfs(n+1:2*n);
confs.widths = fitconfs(2*n+1:3*n);
confs.SNRs = confs.amplitudes./noise;
end

function noise = noise_model(x,y,modeled_y,fn)
% Just to validate the function
noise = fn(x,y,modeled_y);
assert(isequal(size(noise),size(y)),sprintf('Noise model function returned a matrix of size: %i,%i',size(noise,1),size(noise,2)));
end
function noise = empirical_noise(~,observed_y,modeled_y)
    residuals = observed_y - modeled_y;
    noise = var(residuals)*ones(size(residuals));
end
function noise = shot_noise(~,~,modeled_y)
    noise = modeled_y;
end
