function PLEpowerSweep(managers)
    % Additional OD2.5 on green.
    c = Sources.Cobolt_PB.instance();
    m = Sources.Msquared.instance();
    
    ard = Drivers.ArduinoServo.instance('localhost', 2);
%     k = Drivers.Keithley2400.instance(16);
    
    pm = Drivers.PM100.instance();
    pm.set_average_count(50)
    pm.set_range(1)
    
    cset = [5, 10, 20];
    mang = [0, 80, 180];
    
    e = Experiments.SlowScan.Open.instance();
    
    linewidths = NaN(length(cset), length(mang));
    
    figure;
    img = imagesc(cset, mang, linewidths);
    colorbar
    
    xlabel('Cobolt Power [mW]')
    ylabel('EMM OD Filter Wheel [deg]')
    
    for ii = 1:length(cset)
        c.power = cset(ii);
        for jj = 1:length(mang)
            ard.angle = mang(jj);
            
            disp(['Cobolt power: ' num2str(cset(ii)) ', Msquared wheel angle: ' num2str(mang(jj))])
            
            managers.Experiment.run(managers)
            
            s = fitpeaks(e.data.freqs_measured', e.data.sumCounts');

            try
                linewidths(ii, jj) = s.widths(1);
            end
            img.CData = linewidths;
        end
    end
    
    save('PLEpowerSweep', 'cset', 'mang')
end