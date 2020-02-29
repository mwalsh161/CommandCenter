function [f,gof,output] = voigtfit(x, y, n, init, limits)
% GAUSSFIT Fit N voigt functions to x and y data
%   Apply voigtN model to data given an initial guess
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
%   * This is an approximation given the convoluted nature of the voigt

    FWHM_factor = 2; %to account for there being two widths
    fit_type = voigtN(n);
    options = fitoptions(fit_type);

    upper_amps = limits.amplitudes(2).*ones(n,1);
    lower_amps = limits.amplitudes(1).*ones(n,1);
    start_amps = init.amplitudes(1:n);
    
    upper_pos = limits.locations(2).*ones(n,1);
    lower_pos = limits.locations(1).*ones(n,1);
    start_pos = init.locations(1:n);
    
    upper_width = limits.widths(2).*ones(2*n,1)./FWHM_factor;
    lower_width = limits.widths(1).*ones(2*n,1)./FWHM_factor;
    start_width = init.widths(1:n)./FWHM_factor;
    
    options.Upper = [upper_amps; upper_pos; upper_width; limits.background(2)];
    options.Lower = [lower_amps; lower_pos; lower_width; limits.background(1)];
    options.Start = [start_amps; start_pos; start_width; start_width; init.background     ];
    [f,gof,output] = fit(x,y,fit_type,options);
end