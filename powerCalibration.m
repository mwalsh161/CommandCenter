function powerCalibration
    c = Sources.Cobolt_PB.instance();
    m = Sources.Msquared.instance();
    
    ard = Drivers.ArduinoServo.instance('localhost', 2);
    k = Drivers.Keithley2400.instance(16);
    
    pm = Drivers.PM100.instance();
    pm.set_average_count(50)
    pm.set_range(1)
    
    cset = 0:1:80;
    cpow = 0*cset;
    mang = 0:5:180;
    mpow = 0*mang;
    kma = 0:.01:.6;
    kpow = 0*kma;
    
    
    %% Cobolt
    pm.set_wavelength(515)
    c.on
    
    for ii = 1:length(cset)
        ii
        c.power = cset(ii);
        pause(.1)
        cpow(ii) = pm.get_power('MW');
    end
    c.off
    figure
    plot(cset, cpow)
    
    %% M^2
    pm.set_wavelength(620)
    m.on
    
    for ii = 1:length(mang)
        ii
        ard.angle = mang(ii);
        pause(.1)
        mpow(ii) = pm.get_power('MW');
    end
    
    m.off
    figure
    plot(mang, mpow)
    
    save('powerCalibration', 'cset', 'cpow', 'mang', 'mpow');
    
%     %% Blue
%     pm.set_wavelength(405)
%     k.output = true;
%     
%     for ii = 1:length(kma)
%         ii
%         k.current = kma(ii);
%         pause(.1)
%         kpow(ii) = pm.get_power('MW');
%     end
%     k.output = false;
%     figure
%     plot(kma, kpow)
%     
%     save('powerCalibration', 'cset', 'cpow', 'mang', 'mpow', 'kma', 'kpow');
    
end