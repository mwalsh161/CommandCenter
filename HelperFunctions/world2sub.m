function [I,J] = world2sub(im,x,y)
%WORLD2SUB Convert world coordinate to row and column subscripts
%   INPUTS:
%       im: either a smartimage struct or a MATLAB image
%       x: x world coordinate
%       y: y world coordinate
%   OUTPUTS:
%       I: closest row index associated to y world coord
%       J: closest column index associated to x world coord
%
%   Will error if point (x, y) is outside image world coordinates
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
assert(xlim(1) <= x && xlim(2) >= x, 'World X coordinate must be within image limits.')
assert(ylim(1) <= y && ylim(2) >= y, 'World Y coordinate must be within image limits.')

x_im = linspace(xlim(1),xlim(2),imsize(2));
y_im = linspace(ylim(1),ylim(2),imsize(1));

[~,I] = min(abs(y_im - y));
[~,J] = min(abs(x_im - x));
end