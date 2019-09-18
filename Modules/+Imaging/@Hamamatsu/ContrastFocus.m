function metric = ContrastFocus(obj,Managers )
%CONTRASTDETECTION Summary of this function goes here
%   Detailed explanation goes here

    stageManager = Managers.Stages;
    stageHandle = stageManager.modules{1};

    xlen = obj.resolution(1);  % Could have huge speed up with smaller ROI
    ylen = obj.resolution(2);

    searchRange = [-1 1]*6;  % Range to find maximum
    stepSize = 0.5;          % um (size of each step)

    n = 2;  % Number of points to be sure of slope
    dx = 7;
    dy = dx;

    xrange = (dx+1):(xlen-dx);
    yrange = (dy+1):(ylen-dy);

    startPos = stageHandle.position;
    limits = searchRange+startPos(3);

    data = [];
    pos_track = [];

    f=figure('name','Contrast Focus Metric');
    newAx = axes('parent',f);
    p = plot(newAx,0,0);
    xlabel('Z Position (um)')
    ylabel('Focus metric')

    increasing_flag = false;

    zpos = startPos(3);
    frame = obj.snapImage(obj.binning); % Specify binning to be default
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

        %%% DEBUG %%%
        set(p,'xdata',pos_track,'ydata',data);
        drawnow;
        %%% END DEBUG %%%
        
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
    stageHandle.move(startPos(1),startPos(2),pos_track(index))
    stageManager.waitUntilStopped;
    close(f)

end

function data = contrast_detection(frame,dx,dy,xrange,yrange)
frame = double(frame);
image = frame(yrange,xrange);
imagex = frame(yrange,xrange+dx);
imagey = frame(yrange+dy,xrange);
dI = (imagex-image).^2+(imagey-image).^2;
data = mean2(dI);
end
