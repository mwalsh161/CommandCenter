function slow = SlowScan(NVfuncs,ScanRange, averages, points,NVIndex,SNRThresh)
    freqs = linspace(ScanRange(1),ScanRange(2),points);
    [amps,wids,cents,nums] = NVpull(NVfuncs, NVIndex,freqs);
    if nums~=0
        counts = zeros(1,length(freqs));
        for i = 1:nums
            counts = counts + amps(i)*exp(-(freqs-cents(i)).^2/(2*wids(i)^2));
        end
    else
        counts = zeros(1,length(freqs));
    end
    
    noisycounts = counts+abs(500*(randn([1,length(freqs)]))/sqrt(averages));
    slow.freqs = freqs;
    slow.counts = noisycounts;
    slow.aves = averages;
    slow.ScanFit = SlowScanFit(slow,SNRThresh); %fit slow scan
end