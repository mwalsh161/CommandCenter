function [I,J] = world2sub(im,x,y)
%WORLD2SUB Convert world coordinates to row and column subscripts
%   INPUTS:
%       im: either a smartimage struct or a MATLAB image
%       x: x world coordinate
%       y: y world coordinate
%   OUTPUTS:
%       I: closest row index associated to y world coord
%       J: closest column index associated to x world coord
%
%   Will error if point (x, y) is outside image world coordinates and if x
%   and y aren't the same size.
%
%   See also IND2SUB, SUB2IND, SUB2WORLD.

if isstruct(im) && isfield(im,'ROI') && isfield(im,'image') % smartimage struct
    xlim = im.ROI(1,:);
    ylim = im.ROI(2,:);
    cdat = im.image;
elseif isa(im,'matlab.graphics.primitive.Image')
    xlim = im.XData([1 end]);
    ylim = im.YData([1 end]);
    cdat = im.CData;
else
    error('First argument must be a MATLAB image or a smartimage struct with ROI and image defined.')
end
imsize = size(cdat);
vecsize = size(x);
assert(isequal(vecsize,size(y)),'x and y vectors must be of the same size.')
assert(all(xlim(1) <= x) && all(xlim(2) >= x), 'World X coordinate must be within image limits.')
assert(all(ylim(1) <= y) && all(ylim(2) >= y), 'World Y coordinate must be within image limits.')

x_im = linspace(xlim(1),xlim(2),imsize(2));
y_im = linspace(ylim(1),ylim(2),imsize(1));

[~,I] = min(abs(y_im - y(:)),[],2);
[~,J] = min(abs(x_im - x(:)),[],2);
I = reshape(I,vecsize);
J = reshape(J,vecsize);
end