function [ center,width, outstruct ] = gaussfit2D( x, y, im, sigma, options )
%GAUSSFIT2D Fit symmetric, centered 2D Gaussian to image with width sigma.
%   Free params: a,b1,b2,c,d (amplitude,x,y,sigma,background)
%   OUTPUT:
%       center: 1x2 double of x,y coords
%       width: scalar double of gaussian sigma parameter
%       outstruct: struct with all outputs of fit function
%           f: fitobject
%           gof: goodness of fit stats
%           output: output struct (contains algorithm info)

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

g=fittype('a*exp(-(x1-b1)^2/2/c^2)*exp(-(x2-b2)^2/2/c^2)+d',...
   'independent',{'x1','x2'},'dependent',{'y'},'coefficients',{'a','b1','b2','c','d'});
opt = fitoptions(g);
bg = median(im(:));
opt.StartPoint = [max(im(:))-bg mean(xlim) mean(ylim) sigma bg];
opt.Lower = [0 min(xlim) min(ylim) 0  min(im(:))];
opt.Upper = [Inf max(xlim) max(ylim) max( [diff(xlim),diff(ylim)] ) max(im(:))];
f = fieldnames(options);
for i = 1:length(f)
    opt.(f{i}) = options.(f{i});
end
[x,y] = meshgrid(x,y);
[f, gof, output] = fit([x(:), y(:)],im(:),g,opt);
center = [f.b1,f.b2];
width = f.c;
outstruct.f = f;
outstruct.gof = gof;
outstruct.output = output;
end