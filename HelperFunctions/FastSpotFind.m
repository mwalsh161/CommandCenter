function [ pos,rs ] = FastSpotFind( im,r,eccentricity_thresh )
%FASTSPOTFIND Finds circular spots in im
%   Sweeps through different thresholded BW images to find circular spots.
%   If r is a range, will keep within range.
%   If r is scalar, will keep regions < r.
%   Will keep all regions < eccentricity_thresh (default is 0.2).

% Scale down if r is big enough (want scaled down r to be > 2 pixels)
factor = 1;
% if min(r) > 4  % doesn't save much time
%     factor = 2;
%     r = r/factor;
%     im = imresize(im,1/factor);
% end

debug = false;
if debug
    f = findall(0,'name',mfilename);
    if isempty(f) || ~isvalid(f)
        f = figure('name',mfilename);
    else
        clf(f);
        f.Visible = 'on';
    end
    ax = axes('parent',f);
end

if nargin < 3
    eccentricity_thresh = 0.8;
end
if length(r) < 2
    r = [2 r];
end

% Get rid of outliers
temp = im;
im_mean = mean(im(:));
im_std = std(im(:));
temp(temp>im_mean+im_std*10)=NaN;
start = max(temp(:));
stop = im_mean;
threshs = linspace(start,stop,100);
clear temp; % Free up memory

pos = NaN(0,2);
rs = [];
% For adding to global list, must be growing size of regions
for th = threshs
    % Convert to binary image
    BW = im;
    BW(im<th) = 0;
    BW = logical(BW);
    if debug
        hold(ax,'off'); imagesc(BW,'parent',ax); 
        colormap(ax,'gray');hold(ax,'on');axis(ax,'image');
    end
    st = regionprops(BW,'EquivDiameter','Centroid','Eccentricity');
    
    % Filter on eccentricity
    sel = [st.Eccentricity] <= eccentricity_thresh;
    st = st(sel);
    % Filter on radius
    sel = [st.EquivDiameter] <= r(2)*2;
    st = st(sel);
    sel = [st.EquivDiameter] >= r(1)*2;
    st = st(sel);
    % Add to global list
    c = cat(1,st.Centroid);
    d = [st.EquivDiameter]';
    if isempty(st) && ~isempty(pos)
        break
    end
    if isempty(pos)
        pos = c;
        rs = d/2;
        continue;
    end
    [~,dist] = knnsearch(pos,c,'K',1);  % Get distance to nearest neighbor for every c
    % Keep only ones that are separated to nearest neighbor by more than
    % their diameter, d
    pos = [pos; c(dist>d,:)];
    rs = [rs; d(dist>d)/2];
    if debug
        viscircles(ax,pos,rs,'edgecolor','r');
        viscircles(ax,c,d/2,'edgecolor','g');
        drawnow; %input('Enter');
    end
end
if debug
    hold off; imagesc(im); hold on;
end
% Box around detected emitter
edge = round(-r(2)):round(r(2));
% Only do fit in center of image
xlim = round([1/3 2/3]*size(im,2));
ylim = round([1/3 2/3]*size(im,1));
im_cropped = im;
for i = 1:size(pos,1)
    if pos(i,1) > xlim(1) && pos(i,1) < xlim(2) && pos(i,2) > ylim(1) && pos(i,2) < ylim(2)
        x = round(pos(i,1)) + edge;
        y = round(pos(i,2)) + edge;
        im_cropped(y,x) = NaN;
    end
end
% Go through and get rid of ones not a std dev above mean
im_cropped = im_cropped(ylim(1):ylim(2),xlim(1):xlim(2));
im_mean = nanmean(im_cropped(:));
im_std = nanstd(im_cropped(:));
remove = [];
for i = 1:size(pos,1)
    if im(round(pos(i,2)),round(pos(i,1))) < im_mean + im_std*3
        remove(end+1) = i;
    end
end
if debug
    plot(ax,pos(:,1),pos(:,2),'r*');
end
pos(remove,:) = [];
rs(remove) = [];
if debug
    plot(ax,pos(:,1),pos(:,2),'g*');
    f.Visible='off';
end
% Scale back up (account for indexing at 1)
pos = (pos-1)*factor+1;
rs = (rs-1)*factor+1;
end