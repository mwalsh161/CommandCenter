function varargout = circle(center,radius,varargin)
%CIRCLE Draw a primitive circle (similar to LINE)
%   Provide a center and radius for the circle to be passed to LINE.
%   All non-used additional inputs are passed directly to LINE.
%   This is much faster than DRAWCIRCLE.
% Inputs: parenths indicate optional positional arg; brackets indicate
%         optional name, value pairs
%   center: 1x2 finite numeric array specifying the circle center in x,y.
%   radius: numeric finite scalar specifying the radius of the circle.
%   (npoints): (1000) Numeric finite scalar of points to make line.
%   [varargin]: straight to LINE
% Outputs:
%   [lH]: handle to line object of circle

assert(isnumeric(center)&&isequal(size(center),[1,2])&&all(isfinite(center)),...
    'Center should be a finite numeric 1x2 vector.')
assert(isnumeric(radius)&&isscalar(radius)&&isfinite(radius),...
    'Radius should be a finite numeric scalar.')
npoints = 1000;
if isnumeric(varargin{1}) % Then def not name,value pair
    arg1 = varargin{1};
    varargin(1) = [];
    assert(isscalar(radius)&&isfinite(radius),...
        'npoints should be a finite numeric scalar.');
    npoints = arg1;
end
dtheta = 2*pi/npoints;
theta = 0:dtheta:2*pi;
x = cos(theta)*radius+center(1);
y = sin(theta)*radius+center(2);

lh = line(x,y,varargin{:});

if nargout
    varargout = {lh};
end
end

