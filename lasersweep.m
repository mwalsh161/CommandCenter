percents = 5:.1:95;
freqs = percents * NaN;
etalon_volts = percents * NaN;
time = percents * NaN;

s = Sources.Msquared.instance();
s.TuneSetpoint(406.7);

figure
a = axes;
yyaxis left
p1 = plot(a, percents, freqs);
yyaxis right
p2 = plot(a, percents, etalon_volts);

t = tic;

for ii = 1:length(percents)
    s.resonator_percent = percents(ii);
    
    freqs(ii) = s.getFrequency();
    etalon_volts(ii) = s.etalon_voltage;
    time(ii) = toc(t);
    
    p1.YData = freqs;
    p2.YData = etalon_volts;
    
    drawnow;
end

save('lasersweepdata.mat', 'percents', 'freqs', 'etalon_volts', 'time')