function [ center,width,gof ] = GaussFit2D( im, sigma )
%GAUSSFIT Fit symmetric, centered 2D Gaussian to image with width sigma.
%   Free params: b1,b2,c (x,y,sigma)

% Normalize
im = im - min(im(:));
im = im/max(im(:));
[x,y] = meshgrid(1:size(im,2),1:size(im,1));

g=fittype('exp(-(x1-b1)^2/2/c^2)*exp(-(x2-b2)^2/2/c^2)',...
    'independent',{'x1','x2'},'dependent',{'y'},'coefficients',{'b1','b2','c'});
opt = fitoptions(g);
opt.StartPoint = [size(im,2)/2 size(im,1)/2 sigma];
opt.Lower = [1 1 0];
opt.Upper = [size(im,2) size(im,1) max(size(im))];

im = reshape(im,[],1);
[f, gof]=fit([reshape(x,[],1),reshape(y,[],1)],im,g,opt);
center = [f.b1,f.b2];
width = f.c;
end