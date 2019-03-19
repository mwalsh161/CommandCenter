function [amps, wids, cents, nums] = NVpull(NVfuncs,NVIndex,freqs)
if isnan(NVfuncs(NVIndex).amps)
    NVfuncs(NVIndex).nums = poissrnd(1);
    if NVfuncs(NVIndex).nums==0;
        NVfuncs(NVIndex).amps = 0;
        NVfuncs(NVIndex).wids = 0;
        NVfuncs(NVIndex).cents = 0;
    else
        for i=1:NVfuncs(NVIndex).nums
            NVfuncs(NVIndex).amps(i) = abs(40+20*randn); %gaussian random amplitude, centered about 50%
            NVfuncs(NVIndex).wids(i) = 0.1e9+1e9*abs(randn+1); %width is 1 GHz plus some gaussian random amount
            NVfuncs(NVIndex).cents(i) = mean(freqs)+range(freqs)/5*randn;
        end
    end
end
amps = NVfuncs(NVIndex).amps;
wids = NVfuncs(NVIndex).wids;
cents = NVfuncs(NVIndex).cents;
nums = NVfuncs(NVIndex).nums;
end