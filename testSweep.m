function s = testSweep
%     83844218
%     83830539

    ms = Sources.Msquared.instance;
    ni =  Drivers.NIDAQ.dev.instance('dev1');
    pm =  Drivers.PM100.instance;
    hwp = Drivers.APTMotor.instance(83844218, [-Inf, Inf]);
    qwp = Drivers.APTMotor.instance(83830539, [-Inf, Inf]);
    
    pm.wavelength = 620;
    pmp = pm.get_meta_pref('power');
    
    wl = ms.get_meta_pref('setpoint_');
    wm = ms.get_meta_pref('VIS_wavelength');
    
%     hwp.home()
%     qwp.home()
    
    hwpp = hwp.get_meta_pref('Position');
    qwpp = qwp.get_meta_pref('Position');
    
    pr = Base.PrefRegister.instance;
    mp = [pr.register{2}.prefs.ao0 pr.register{2}.prefs.ao1 pr.register{2}.prefs.ao2 pr.register{2}.prefs.ao3];
%     mp1 = pr.register{1}.prefs.ao0;
    
    mr = Base.MeasurementRegister.instance;
    mm = mr.register(1).Drivers_NIDAQ_in;
    
    t = Prefs.Time;
    
    opt = false;
    
    
    s = Base.Sweep({mm, pmp}, {t}, {1:100}, struct('isContinuous', 1), 1);
    Base.SweepViewer(s, [])
    return
    
    if opt
        p = .01;
        d = .002;
%         sweep = 0:p:10;
        sweep = 10:-p:0;
        s0 = Base.Sweep({mm}, {mp(1)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
        s1 = Base.Sweep({mm}, {mp(2)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
        s2 = Base.Sweep({mm}, {mp(3)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
        s5 = Base.Sweep({mm}, {mp(4)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
        s4 = Base.Sweep({mm}, {hwpp}, {0:5:90}, struct('shouldOptimizeAfter', 1), .5, 'APD Optimization Over HWP');
        s3 = Base.Sweep({mm}, {qwpp}, {0:5:90}, struct('shouldOptimizeAfter', 1), .5, 'APD Optimization Over QWP');

        f = figure;

        Base.SweepViewer(s0, subplot(2, 3, 1, 'parent', f))
        Base.SweepViewer(s1, subplot(2, 3, 2, 'parent', f))
        Base.SweepViewer(s2, subplot(2, 3, 4, 'parent', f))
        Base.SweepViewer(s5, subplot(2, 3, 5, 'parent', f))
        Base.SweepViewer(s3, subplot(2, 3, 3, 'parent', f))
        Base.SweepViewer(s4, subplot(2, 3, 6, 'parent', f))
    else
%         s = Base.Sweep({mm, pmp, wm, t}, {wl}, {618:.05:622}, struct(), 1);
%         Base.SweepViewer(s, [])
        s = Base.Sweep({mm}, {t}, {1:100}, struct('isContinuous', 1), 1);
        Base.SweepViewer(s, [])
    end

%     s = Base.Sweep({mm, pmp, hwpp}, {qwpp}, {0:.01:10}, struct(), .001);
%     s = Base.Sweep({mm, pmp, hwpp, t}, {hwpp}, {0:2:90}, struct(), 1);
    
%     s = Base.Sweep({mm, pmp, wm, t}, {wl}, {618:.1:622}, struct(), 1);

%     profile on
%     Base.SweepViewer(s, [])
%     profile off
%     profile viewer
end