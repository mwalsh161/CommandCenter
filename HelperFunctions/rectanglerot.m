function h = rectanglerot( parent,position, varargin )
%RECTANGLEROT Rotatable rectangle
%   Drawn from 4 lines
h = hggroup('parent',parent,'tag',mfilename,'HitTest','off');
x = [position(1) position(1)+position(3)];
y = [position(2) position(2)+position(4)];
%line(x,[y(1) y(1)],'parent',h,varargin{:});
%line(x,[y(2) y(2)],'parent',h,varargin{:});
%line([x(1) x(1)],y,'parent',h,varargin{:});
%line([x(2) x(2)],y,'parent',h,varargin{:});
x = [x(1) x(1) x(2) x(2)];
y = [y(1) y(2) y(2) y(1)];
z = [0 0 0 0];
patch(x,y,z,varargin{:},'parent',h);
end