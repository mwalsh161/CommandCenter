function s0 = LLPIC
    mc = Drivers.Conex_CC.instance('COM8');

    ms = Sources.Msquared.instance;
    ni =  Drivers.NIDAQ.dev.instance('dev1');
    pm =  Drivers.PM100.instance;
    hwp = Drivers.APTMotor.instance(83844218, [-Inf, Inf]);
    qwp = Drivers.APTMotor.instance(83830539, [-Inf, Inf]);
    
    pm.wavelength = 620;
    pmp = pm.get_meta_pref('power');
    
    wl = ms.get_meta_pref('setpoint_');
    ep = ms.get_meta_pref('etalon_percent');
    wm = ms.get_meta_pref('VIS_wavelength');
    ev = ms.get_meta_pref('etalon_voltage');
    
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

    N = 11;
    M = 38;
    
%     N = 3;
%     M = 1;
    
    p = .02;
    d = .005;
%     sweep = 10:-p:0;
    sweep = 0:p:10;
    s0 = Base.Sweep({mm}, {mp(1)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
%     s01= Base.Sweep({mm}, {mp(1)}, {sweep2}, struct('shouldOptimizeAfter', 1), d);
    s1 = Base.Sweep({mm}, {mp(2)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
    s2 = Base.Sweep({mm}, {mp(3)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
    s3 = Base.Sweep({mm}, {mp(4)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
%     s4 = Base.Sweep({mm}, {hwpp}, {0:5:90}, struct('shouldOptimizeAfter', 1), .5, 'APD Optimization Over HWP');
%     s5 = Base.Sweep({mm}, {qwpp}, {0:5:90}, struct('shouldOptimizeAfter', 1), .5, 'APD Optimization Over QWP');

    f = figure;

    Base.SweepViewer(s0, subplot(2, 3, 1, 'parent', f))
%     Base.SweepViewer(s01, subplot(1, 2, 2, 'parent', f))
    Base.SweepViewer(s1, subplot(2, 3, 2, 'parent', f))
    Base.SweepViewer(s2, subplot(2, 3, 4, 'parent', f))
    Base.SweepViewer(s3, subplot(2, 3, 5, 'parent', f))
%     Base.SweepViewer(s5, subplot(2, 3, 3, 'parent', f))
%     Base.SweepViewer(s4, subplot(2, 3, 6, 'parent', f))
    
%     s0.measure();
%     return

    f2 = figure;
    
    m1 = Base.Sweep({wm, ev, mm, pmp, mm, pmp, t}, {ep, wl}, {10:8:90, 601:.25:603}, struct('shouldReturnToInitial', 0), .2);
    Base.SweepViewer(m1, subplot(1, 3, 1, 'parent', f2))
    m2 = Base.Sweep({wm, ev, mm, pmp, mm, pmp, t}, {ep, wl}, {10:8:90, 618:.25:620}, struct('shouldReturnToInitial', 0), .2);
    Base.SweepViewer(m2, subplot(1, 3, 2, 'parent', f2))
    m3 = Base.Sweep({wm, ev, mm, pmp, mm, pmp, t}, {ep, wl}, {10:8:90, 636:.25:638}, struct('shouldReturnToInitial', 0), .2);
    Base.SweepViewer(m3, subplot(1, 3, 3, 'parent', f2))
    
    for jj = 2:M
        for ii = 1:N
            y = 30*(ii-1) + 570*(jj-1);
            
            mc.position = 25e3 - 30 - y;
            
            tosave = struct();
            
            s0.reset();
%             s0.measure();
            tosave.opt0 = s0.measure();
            s1.reset();
            tosave.opt1 = s1.measure();
            s2.reset();
            tosave.opt2 = s2.measure();
            s3.reset();
            tosave.opt3 = s3.measure();
            
            m1.reset();
            tosave.m1 = m1.measure();
            m2.reset();
            tosave.m2 = m2.measure();
            m3.reset();
            tosave.m3 = m3.measure();
%             s4.reset();
%             tosave.opt4 = s4.measure();
%             s5.reset();
%             tosave.opt5 = s5.measure();

            save([num2str(jj) '_' num2str(ii) '.mat'], 'tosave')
        end
    end
end