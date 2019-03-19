function surveyRegion(obj,NV)
%takes in an NV object and uses its survey scans to generate scan regions,
%which are then written to the NV structure

scanDevs = 4; %number of standard deviations of clearance to give around peaks
maxRange = 0.06; %max region size in THz

peaks =[];
wids = [];
for i=1:length(NV.survey)
    peaks = [peaks, NV.survey(i).ScanFit.locs];
    wids = [wids, NV.survey(i).ScanFit.wids];
end

%determine regions by sorting and finding overlap (consider making this a
%helper function)
[peaks, I] = sort(peaks);
wids = wids(I); %sorts peaks and keeps associated widths
peakqueue = 1:length(peaks);
while ~isempty(peakqueue)
    start = peakqueue(1);
    stop = start;
    while stop < peakqueue(end) && peaks(stop)+scanDevs*wids(stop) >= peaks(stop+1)-scanDevs*wids(stop+1) &&...
            (peaks(stop+1)+scanDevs*wids(stop+1))-(peaks(start)-scanDevs*wids(start)) <= maxRange
        stop = stop+1;
    end
    NV.region(end+1).span = [peaks(start)-scanDevs*wids(start), peaks(stop)+scanDevs*wids(stop)];
    if diff(NV.region(end).span) > maxRange
        NV.region(end).span = mean(NV.region(end).span) + [-maxRange/2, maxRange/2]; %cap at survey scan range
    end
    NV.region(end).done = false;
    peakqueue(1:(stop-start+1)) = [];
end
end

