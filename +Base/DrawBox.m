function [ varargout ] = DrawBox( xlim,ylim,zlim, varargin )
%DRAWBOX Draws wire box specified by xlim, ylim, zlim
%   xlim, ylim and zlim are a 2x1 array
%   varargin goes directly to the plot3 function. Specify parent if
%   necessary! Handy fact - if a 4th element for color is specified, it is
%   the transparency of the lines.
%   Return handle to the plots

% Upper box
x1 = [xlim(1) xlim(1) xlim(2) xlim(2) xlim(1) xlim(1)];
y1 = [ylim(1) ylim(2) ylim(2) ylim(1) ylim(1) ylim(1)];
z1 = [zlim(1) zlim(1) zlim(1) zlim(1) zlim(1) zlim(2)];

% Lower box and vertical lines
x2 = [xlim(1) xlim(1) xlim(1)  xlim(2) xlim(2) xlim(2)  xlim(2) xlim(2) xlim(2) xlim(1)];
y2 = [ylim(2) ylim(2) ylim(2)  ylim(2) ylim(2) ylim(2)  ylim(1) ylim(1) ylim(1) ylim(1)];
z2 = [zlim(2) zlim(1) zlim(2)  zlim(2) zlim(1) zlim(2)  zlim(2) zlim(1) zlim(2) zlim(2)];

if nargout ~= 1
    varargout = {[x1 x2],[y1 y2],[z1 z2]};
else
    varargout{1} = plot3([x1 x2],[y1 y2],[z1 z2],varargin{:});
end
end

