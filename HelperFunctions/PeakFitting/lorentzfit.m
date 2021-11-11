function [f,gof,output] = lorentzfit(x, y, n, init, limits)
% LORENTZFIT Fit N lorentzians to x and y data
%   Apply lorentzN model to data given an initial guess
%   INPUT:
%   x - vector of x-data (same shape as "fit" takes)
%   y - vector of y-data (same shape as "fit" takes)
%   n - number (N) of peaks to fit
%   init - struct with fields (each are Nx1 except background which is 1x1):
%       amplitudes - amplitude guesses
%       locations - x-location guesses
%       widths - FWHM guesses
%       background
%   limits - similar to init (same field names), but each is Nx2 to specify [min max]
%   OUTPUT: first 3 outputs of "fit"

    fit_type = lorentzN(n);
    options = fitoptions(fit_type);

    upper_amps = limits(2,1).*ones(n,1);
    lower_amps = limits(1,1).*ones(n,1);
    start_amps = init(1:n,1);
    
    upper_pos = limits(2,2).*ones(n,1);
    lower_pos = limits(1,2).*ones(n,1);
    start_pos = init(1:n,2);
    
    upper_width = limits(2,3).*ones(n,1);
    lower_width = limits(1,3).*ones(n,1);
    start_width = init(1:n,3);
    
    options.Upper = [upper_amps; upper_pos; upper_width; limits(2,4)];
    options.Lower = [lower_amps; lower_pos; lower_width; limits(1,4)];
    options.Start = [start_amps; start_pos; start_width; init(1:n,4)     ];
    [f,gof,output] = fit(x,y,fit_type,options);
end