function [ center,width, outstruct ] = gaussfit2D( x, y, im, sigma, options )
%GAUSSFIT2D Fit symmetric, centered 2D Gaussian to image with width sigma.
%   Free params: b1,b2,c (x,y,sigma)

if numel(x) == 2
    x = linspace(x(1),x(end),size(im,2));
end
if numel(y) == 2
    y = linspace(y(1),y(end),size(im,1));
end
xlim = x([1 end]);
ylim = y([1 end]);
if ~exist('fitoptions','var')
    options = struct();
else
    assert(isstruct(options),'fitoptions must be a struct.');
end
if ~exist('sigma','var')
    sigma = min(diff(xlim)/2,diff(ylim)/2);
end

% Normalize
im = im - min(im(:));
im = im/max(im(:));
[x,y] = meshgrid(x,y);

g=fittype('exp(-(x1-b1)^2/2/c^2)*exp(-(x2-b2)^2/2/c^2)',...
    'independent',{'x1','x2'},'dependent',{'y'},'coefficients',{'b1','b2','c'});
opt = fitoptions(g);
opt.StartPoint = [mean(xlim) mean(ylim) sigma];
opt.Lower = [min(xlim) min(ylim) 0];
opt.Upper = [max(xlim) max(ylim) max( [diff(xlim),diff(ylim)] )];
f = fieldnames(options);
for i = 1:length(f)
    opt.(f{i}) = options.(f{i});
end

[f, gof, output]=fit([x(:), y(:)],im(:),g,opt);
center = [f.b1,f.b2];
width = f.c;
outstruct.f = f;
outstruct.gof = gof;
outsturct.output = output;
end