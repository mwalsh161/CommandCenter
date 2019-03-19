function [spec2wav, gof] = SpecWaveCalibrate(obj,span,points)
%SpecWaveCalibrate generates a mapping between wavemeter and spectrometer 
%   range = 1x2 [start, stop] vector in nanometers
%   points = number of points to take

obj.wavemeter.setDeviationChannel(false);
minRange = 634;
maxRange = 641;
assert(min(span) >= minRange && max(span) <= maxRange,...
    sprintf('SpecWaveCalibrate must take a range between %i nm and %i nm',minRange,maxRange));
setpoints = linspace(span(1),span(2),points);
obj.WinSpec.setExposure('msec');
obj.rl.off;
specloc = NaN(1,points);
waveloc = NaN(1,points);
for i=1:points
    obj.rl.LaserMoveCoarse(obj.c/setpoints(i));
    laserspec = obj.WinSpec.start;
    specpeaks = SpecPeak(laserspec,634,641);
    assert(length(specpeaks) == 1, sprintf('Unable to read laser cleanly on spectrometer (%i peaks)',length(specpeaks)));
    specloc(i) = specpeaks;
    waveloc(i) = obj.wavemeter.getFrequency;
end
fit_type = fittype('a/(x-b)+c');
options = fitoptions(fit_type);
options.Start = [obj.c,0,0];
[spec2wav,gof] = fit(specloc',waveloc',fit_type,options);

%last, a sneaky optomization; since we're at the end of the range and our
%next setting will likely be towards the middle, move to the middle!
obj.serial.Wavelength = mean(span);
end
