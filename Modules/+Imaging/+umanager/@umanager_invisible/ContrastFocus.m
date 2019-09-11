function metric = ContrastFocus(obj,Managers )
DEBUG = true;
%CONTRASTDETECTION Summary of this function goes here
%   Detailed explanation goes here
stageManager = Managers.Stages;
stageHandle = stageManager.modules{1};
% xlen = obj.resolution(1);  % Could have huge speed up with smaller ROI
% ylen = obj.resolution(2);
xlen = (obj.ROI(1,2)-obj.ROI(1,1))/obj.binning; % take into account ROI
ylen = (obj.ROI(2,2)-obj.ROI(2,1))/obj.binning;
searchRange = [-1 1]*20;  % Range to find maximum
stepSize = 0.25;          % um (size of each step)
n = 4;  % Number of points to be sure of slope
dx = 7;
dy = dx;
xrange = (dx+1):(xlen-dx);
yrange = (dy+1):(ylen-dy);
startPos = stageHandle.position;
limits = searchRange+startPos(3);
if DEBUG
    f = findall(0,'name',mfilename);
    if isempty(f) || ~isvalid(f)
        f=figure('name',mfilename);
    else
        clf(f)
        f.Visible = 'on';
    end
    newAx = axes('parent',f);
    p = plot(newAx,0,0);
    hold on;
    p2 = plot(newAx,[0 0],[0 0]+obj.focusThresh,'r--');
    xlabel('Z Position (um)')
    ylabel('Focus metric')
end
% If we don't have a landscape of focus peaks, do one large scan first
if isempty(obj.focusPeaks)
    data = [];
    pos_track = [];
    for zpos = startPos(3) + (-7:stepSize:7)
        stageHandle.move(startPos(1),startPos(2),zpos);
        stageManager.waitUntilStopped;
        frame = obj.snapImage(3); % Specify binning to be 3
        d = contrast_detection(frame,dx,dy,xrange,yrange);
        pos_track(end+1) = zpos;
        data(end+1) = d;
        if DEBUG
            title(newAx,'Acquiring landscape')
            set(p,'xdata',pos_track,'ydata',data);
            set(p2,'xdata',[min(pos_track),max(pos_track)])
            drawnow;
        end
    end
    [~,locs] = findpeaks(data,'MinPeakProminence',500);
    if numel(locs) > 1
        obj.focusPeaks = pos_track(locs(2:end))-pos_track(locs(1));
    else
        obj.focusPeaks = 0;
    end
end
% Find a peak
data = [];
pos_track = [];
increasing_flag = false;
%for zpos = startPos(3) + (start:stepSize:stop)
% Init at current spot
zpos = startPos(3);
frame = obj.snapImage(obj.binning); % Keep original binning
d = contrast_detection(frame,dx,dy,xrange,yrange);
pos_track(end+1) = zpos;
data(end+1) = d;
direction = -1;
while true
    zpos = zpos + direction*stepSize;
    assert(zpos>min(limits) && zpos<max(limits),'Failed to find peak in search range.')
    stageHandle.move(startPos(1),startPos(2),zpos);
    stageManager.waitUntilStopped;
    frame = obj.snapImage(obj.binning); % Specify binning to be 3
    d = contrast_detection(frame,dx,dy,xrange,yrange);
    pos_track(end+1) = zpos;
    data(end+1) = d;
    if DEBUG
        title(newAx,'Quick search')
        set(p,'xdata',pos_track,'ydata',data);
        set(p2,'xdata',[min(pos_track),max(pos_track)])
        drawnow;
    end
    if numel(data)>=n
        if prod(diff(data(end-n+1:end)) < 0)  % If vals are decreasing
            direction = 1;
            if increasing_flag
                % Means we found a peak
                break
            end
        else
            increasing_flag = true;
        end
        
    end
end
[metric,index] = max(data);
if metric < obj.focusThresh && obj.focusThresh ~= 0
    % Assume the first time you focus you do it right!
    % Now, we do a more robust search +/- 5 um
    for zpos = pos_track(index) + (-25:stepSize:25)
        stageHandle.move(startPos(1),startPos(2),zpos);
        stageManager.waitUntilStopped;
        frame = obj.snapImage(3); % Specify binning to be 3
        d = contrast_detection(frame,dx,dy,xrange,yrange);
        pos_track(end+1) = zpos;
        data(end+1) = d;
        if DEBUG
            title(newAx,'Long search')
            set(p,'xdata',pos_track,'ydata',data);
            set(p2,'xdata',[min(pos_track),max(pos_track)])
            drawnow;
        end
    end
    [metric,index] = max(data);
end
stageHandle.move(startPos(1),startPos(2),pos_track(index))
% Check other known peaks
flag = true;
if ~isempty(obj.focusPeaks) && sum(obj.focusPeaks) % Make sure exists and not 0
    % Just check the closest one (will work unless symetric)!
    for i = [-1 1]
        zpos = min(obj.focusPeaks)*i + pos_track(end);
        stageHandle.move(startPos(1),startPos(2),zpos);
        stageManager.waitUntilStopped;
        frame = obj.snapImage(3); % Specify binning to be 3
        d = contrast_detection(frame,dx,dy,xrange,yrange);
        if d > metric
            % Repeat from this new location
            obj.ContrastFocus(Managers);
            flag = false;
            break
        end
    end
end
if flag
    % Need to undo the check
    % Only do this if the above clause did not recursively call
    stageHandle.move(startPos(1),startPos(2),pos_track(index))
end
if DEBUG
    f.Visible = 'off';
end
stageManager.waitUntilStopped;
end

function data = contrast_detection(frame,dx,dy,xrange,yrange)
frame = double(frame);
image = frame(yrange,xrange);
imagex = frame(yrange,xrange+dx);
imagey = frame(yrange+dy,xrange);
dI = (imagex-image).^2+(imagey-image).^2;
data = mean2(dI);
end
