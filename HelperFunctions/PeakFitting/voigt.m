function y = voigt(x, A, x0, fl, fg)
    [eta, f] = voigtApprox(fl, fg);

    y = A * ( eta ./ (1 + (2*(x - x0)/f).^2) + (1-eta) * exp(- (2 * sqrt(2*log(2)) * (x - x0) / f).^2) );
end