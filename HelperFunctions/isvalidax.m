function tf = isvalidax(ax)
%ISVALIDAX Returns true if input is an axis and is valid
%   Similar to isvalid, but one additional confirmation of axes
assert(~iscell(ax),'arg must be an object or an array of objects');
tf = arrayfun(@(a)isa(a,'matlab.graphics.axis.Axes')&&isvalid(a),ax);
end