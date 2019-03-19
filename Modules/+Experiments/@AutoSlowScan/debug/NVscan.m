function [image] = NVscan(dim)
NVnum = randi([5, 20]) %random number of NVs between 1 and 10
image = rand(dim);
for i=1:NVnum
    image = image + NVScanPeak(dim);
end
end

