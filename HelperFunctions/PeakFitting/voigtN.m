function [ fit_type ] = voigtN(n , bg)
    %VOIGTN Creates fittype of n(>1) Pseudo-Voigt approximation functions with one optional y-offset
    %   Default is to include offset
    %   https://en.wikipedia.org/wiki/Voigt_profile

    assert(n==round(n), 'n must be an integer.')
    assert(isnumeric(n)&&n>0, 'n must be greater than 0.')
    % bg specifies including background offset
    if nargin < 2
        bg = true;
    end
    
    % a = amplitude,
    % b = center,
    % c = compsite width f,
    % e = lorentzian/gaussian ratio eta
    subEQ = @(n)sprintf('a%i*(e%i./(1+(2*(x-b%i)/c%i).^2)+(1-e%i)*exp(-2*(sqrt(2*log(2))*(x-b%i)/c%i).^2))',n,n,n,n,n,n,n);

    eq = cell(1,n);
    for i=1:n
        eq{i} = subEQ(i);
    end
    if bg
        eq{end+1} = 'd';
    end
    eq = strjoin(eq,' + ');

    fit_type = fittype(eq);
end