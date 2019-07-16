function [ fit_type,eq ] = lorentzN( n,bg )
%LORENTZN Creates fittype of n lorentzians with one optional offset
%   Default is to include offset

% bg specifies including background offset
if nargin < 2
    bg = true;
end

subEQ = @(n)sprintf('a%i*1/2*c%i/((x-b%i)^2+(1/2*c%i)^2)',n,n,n,n);

eq = cell(1,n);
for i=1:n
    eq{i} = subEQ(i);
end
if bg
    eq{end+1} = 'd';
end
eq = strjoin(eq,'+');

fit_type = fittype(eq);
end