function [peakmap] = NVScanPeak(dim)
amp = 2;
wid = 2;
center = [randi([1+2*wid,dim(1)-2*wid]),randi([1+2*wid,dim(2)-2*wid])];
[X,Y] = meshgrid(1:dim(1),1:dim(2));
peakmap = amp*exp(-((X-center(1)).^2+(Y-center(2)).^2)/(2*wid^2));
end