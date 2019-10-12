function [x,y] = sub2world(im,I,J)
%SUB2WORLD Convert row and column subscripts to world coordinates
%   INPUTS:
%       im: either a smartimage struct or a MATLAB image
%       I: row index
%       J: column index
%   OUTPUTS:
%       x: x world coordinate associated to column index
%       y: y world coordinate associated to row index
%
%   Will error if point (J, I) is greater than image size and if J and I
%   aren't the same size. If (J, I) is not an integer, it will be rounded
%   to nearest integer.
%
%   NOTE: this won't be exactly reciprocal to WORLD2SUB because of
%   rounding the indices.
%
%   See also IND2SUB, SUB2IND, WORLD2SUB.

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
vecsize = size(I);
assert(isequal(vecsize,size(J)),'row and column vectors must be of the same size.')
I = round(I);
J = round(J);
assert(all(1 <= I) && all(imsize(1) >= I), 'Row index must be within image limits.')
assert(all(1 <= J) && all(imsize(2) >= J), 'Column index must be within image limits.')

x_im = linspace(xlim(1),xlim(2),imsize(2));
y_im = linspace(ylim(1),ylim(2),imsize(1));

x = x_im(J(:));
y = y_im(I(:));
x = reshape(x,vecsize);
y = reshape(y,vecsize);
end