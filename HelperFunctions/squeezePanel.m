function squeezePanel(panel,margin,axis)
%SQUEEZEPANEL Squeeze panel in x or y to contents
% margin is in pixels
% axis: axes to make tight
%   x: 0
%   y: 1 [default]
if nargin < 3
    axis = 1;
elseif nargin < 2
    margin = 0;
    axis = 1;
end
assert(axis==0 || axis==1,'Axis must be 0 or 1')

start = Inf;
stop = -Inf;
objs = allchild(panel);
child_pos = NaN(length(objs),4);
for i = 1:length(objs)
    child_pos(i,:) = getpixelposition(objs(i));
    % Update height
    stop_temp = sum(child_pos(i,[1 3]+axis));
    if stop_temp > stop
        stop = stop_temp;
    end
    % Update start
    start_temp = child_pos(i,1+axis);
    if start_temp < start
        start = start_temp;
    end
end
start = start - margin;
stop = stop + margin;
% Update height
pos = getpixelposition(panel);
pos(3+axis) = stop - start;
setpixelposition(panel,pos);
% Go through and shift children
child_pos(:,1+axis) = child_pos(:,1+axis)-start;
for i = 1:length(objs)
    setpixelposition(objs(i),child_pos(i,:))
end
end
