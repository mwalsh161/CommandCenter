function [ regions ] = peakRegionBin(peaks,wids,ppp,scanDevs,maxRange)
%peakRegionBin Takes in a list of peaks and widths and generate binned regions
% INPUTS
%   peaks = 1xn list of peak center locations
%   wids = 1xn list of widths associated with each peak in peaks
%   ppp = points per peak, i.e. should have wid/ppp resolution
%   scanDevs = how many widths of clearance to give on either side of peak
%   maxRange = maximum allowed region size
% OUTPUT
%   regions = nxm list of region points

if nargin < 3
    ppp = 10;
end
if nargin < 4
    scanDevs = 5;
end
if nargin < 5
    maxRange = Inf;
end

[peaks, I] = sort(peaks);
wids = wids(I); %sorts peaks and keeps associated widths
bins = [peaks'-scanDevs*wids',peaks'+scanDevs*wids',wids'/ppp];
if ~isempty(bins)
    bins_not_ok = diff(bins(:,[1,2])')>=maxRange;
    if any(bins_not_ok)
        warning('Found %i bins (out of %i) with a range larger than maxRange. Removing!',sum(bins_not_ok),length(bins_not_ok));
        bins(bins_not_ok,:) = [];
    end
end
regions = {};
nodequeue = unique(bins(1:size(bins,1)*2)); %list of all unique "node" locations in order

while ~isempty(nodequeue) %while there are still nodes
    start = nodequeue(1); %start at top of node queue
    peaklist = find(bins(:,1)==start); %find the index of the start node
    nodequeue(1) = []; %pop the top node off the queue
    points = []; %initialize vector of points
    while ~isempty(peaklist) %while we're in a region still covered
        nextnode = nodequeue(1); %grab next node in the queue
        points = [points, start:min(bins(peaklist,3)):nextnode];
        
        %now at the next node, modify peaklist as necessary
        if bins(bins(:,1)==nextnode,2)-points(1) > maxRange %if it's a start node and its associated stop node is further than maxRange from the original start
            nodequeue=nodequeue([2,1,3:end]); %push next node one node down queue;
        else
            peaklist = [peaklist, find(bins(:,1)==nextnode)]; %if it's a start node, add peak to the list
            peaklist(peaklist==find(bins(:,2)==nextnode)) = []; %if it's a stop node, remove peak from the list
            nodequeue(1) = []; %pop top node off the queue
        end
        
        start = nextnode; %nextnode is new start node
    end
    %if hit here, means no peaks spanning current region
    regions{end+1} = unique(points); %use unique because we expect doubles at nodes
end

end