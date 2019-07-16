function [f,gof,output] = gaussfit(x, y, n, init, limits)
% GAUSSFIT Fit N lorentzians to x and y data
%   Apply lorentzN model to data given an initial guess
%   INPUT:
%   x - vector of x-data (same shape as "fit" takes)
%   y - vector of y-data (same shape as "fit" takes)
%   n - number (N) of peaks to fit
%   init - struct with fields (each are Nx1 except background which is 1x1):
%       amplitudes - amplitude guesses
%       locations - x-location guesses
%       widths - FWHM* guesses
%       background
%   limits - similar to init (same field names), but each is Nx2 to specify [min max]
%   OUTPUT: first 3 outputs of "fit"
%
%   * Yes, input is FWHM, but output will be gaussian parameters, so width
%   will be in sigma.

    FWHM_factor = 2*sqrt(2*log(2));
    fit_type = gaussN(n);
    options = fitoptions(fit_type);

    upper_amps = limits.amplitudes(2).*ones(n,1);
    lower_amps = limits.amplitudes(1).*ones(n,1);
    start_amps = init.amplitudes(1:n);
    
    upper_pos = limits.locations(2).*ones(n,1);
    lower_pos = limits.locations(1).*ones(n,1);
    start_pos = init.locations(1:n);
    
    upper_width = limits.widths(2).*ones(n,1)./FWHM_factor;
    lower_width = limits.widths(1).*ones(n,1)./FWHM_factor;
    start_width = init.widths(1:n)./FWHM_factor;
    
    options.Upper = [upper_amps; upper_pos; upper_width; limits.background(2)];
    options.Lower = [lower_amps; lower_pos; lower_width; limits.background(1)];
    options.Start = [start_amps; start_pos; start_width; init.background     ];
    [f,gof,output] = fit(x,y,fit_type,options);
end