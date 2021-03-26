wm_emm = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', 7, false);
wm_sol = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', 6, false);

samples = 5000;

time = nan(1,samples);
freqs_emm = nan(1,samples);
freqs_solstis = nan(1,samples);
freqs_diff = nan(1,samples);

figure;
subplot(3,1,1)
p1 = plot(time, freqs_emm);
ylabel('EMM Frequency [THz]', 'interpreter', 'latex')

hold on;
subplot(3,1,2)
p2 = plot(time, freqs_solstis);
ylabel('SolsTiS Frequency [THz]', 'interpreter', 'latex')

subplot(3,1,3)
p3 = plot(time, freqs_diff);
ylabel('MIR Frequency [THz]', 'interpreter', 'latex')
xlabel('Time Since Start [s]', 'interpreter', 'latex')
hold off;
t = tic;

for ii = 1:samples
    freqs_emm(ii) = wm_emm.getFrequency;
    freqs_solstis(ii) = wm_sol.getFrequency;
    freqs_diff(ii) = freqs_emm(ii) - freqs_solstis(ii);
    
    time(ii) = toc(t);
    
    p1.XData = time;
    p1.YData = freqs_emm;
    
    p2.XData = time;
    p2.YData = freqs_solstis;
    
    p3.XData = time;
    p3.YData = freqs_diff;
    
    drawnow;
%     pause(0.1)
end