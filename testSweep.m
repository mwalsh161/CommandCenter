function s = testSweep
%     83844218
%     83830539

%     ni = Drivers.NIDAQ.dev.instance('dev1')
    pr = Base.PrefRegister.instance;
    mp = pr.register{1}.prefs.ao2;
    mp1 = pr.register{1}.prefs.ao0;
    
    mr = Base.MeasurementRegister.instance;
    mm = mr.register(1).Drivers_NIDAQ_in;
    
    s = Base.Sweep({mm}, {mp, mp1}, {5:.01:6, 3:.01:4}, struct(), .01);
end