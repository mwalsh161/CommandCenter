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
    s0 = Base.Sweep({mm}, {mp(4)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
%     s01= Base.Sweep({mm}, {mp(1)}, {sweep2}, struct('shouldOptimizeAfter', 1), d);
    s1 = Base.Sweep({mm}, {mp(3)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
    s2 = Base.Sweep({mm}, {mp(2)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
    s3 = Base.Sweep({mm}, {mp(1)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
    s4 = Base.Sweep({mm}, {hwpp}, {0:5:90}, struct('shouldOptimizeAfter', 1), .5, 'APD Optimization Over HWP');
    s5 = Base.Sweep({mm}, {qwpp}, {0:5:90}, struct('shouldOptimizeAfter', 1), .5, 'APD Optimization Over QWP');


    f = figure;

    Base.SweepViewer(s0, subplot(2, 3, 1, 'parent', f))
%     Base.SweepViewer(s01, subplot(1, 2, 2, 'parent', f))
    Base.SweepViewer(s1, subplot(2, 3, 2, 'parent', f))
    Base.SweepViewer(s2, subplot(2, 3, 4, 'parent', f))
    Base.SweepViewer(s3, subplot(2, 3, 5, 'parent', f))
    Base.SweepViewer(s5, subplot(2, 3, 3, 'parent', f))
    Base.SweepViewer(s4, subplot(2, 3, 6, 'parent', f))

%     return
    
%     s0.measure();
%     return

%     f2 = figure;
%     
%     m1 = Base.Sweep({wm, ev, mm, pmp, mm, pmp, t}, {ep, wl}, {10:8:90, 601:.25:603}, struct('shouldReturnToInitial', 0), .2);
%     Base.SweepViewer(m1, subplot(1, 3, 1, 'parent', f2))
%     m2 = Base.Sweep({wm, ev, mm, pmp, mm, pmp, t}, {ep, wl}, {10:8:90, 618:.25:620}, struct('shouldReturnToInitial', 0), .2);
%     Base.SweepViewer(m2, subplot(1, 3, 2, 'parent', f2))
%     m3 = Base.Sweep({wm, ev, mm, pmp, mm, pmp, t}, {ep, wl}, {10:8:90, 636:.25:638}, struct('shouldReturnToInitial', 0), .2);
%     Base.SweepViewer(m3, subplot(1, 3, 3, 'parent', f2))
    
    base = 4000;
    
    for wl = [581, 601, 619, 637, 660]
        ms.setpoint_ = wl;
        
        wlname = ['wl=' num2str(wl)];
        
        mc.position = base - 1000;
        while abs(mc.get_position() - mc.position) > 2; pause(.1); end
        
        resetPiezo()
        
%         for ii = 1:4
%             mc.position = base + 30*(ii-1);
%             while abs(mc.get_position() - mc.position) > 2; pause(.1); end
% 
%             measure(ii == 1, [wlname '_ang=' num2str(15*(5-ii))]);
%         end
%         
%         for ii = 1:12
%             offlist = [0, 390, 420];
%             for jj = 1:3
%                 mc.position = base + 540 + 810*(ii-1) + offlist(jj);
%                 resetPiezo()
%                 while abs(mc.get_position() - mc.position) > 2; pause(.1); end
%                 
%                 measure(false, [wlname '_unclad_' num2str(ii) '_' num2str(jj)]);
%             end
%         end
%         
%         resetPiezo()
        
        for ii = 9:19
            offlist = [0, 30, 240, 270, 300];
            for jj = 1:5
                mc.position = base + 10230 + 510*(ii-1) + offlist(jj);
                while abs(mc.get_position() - mc.position) > 2; pause(.1); end
                
                measure(ii == 1 || ii == 19, [wlname '_clad_' num2str(ii) '_' num2str(jj)]);
            end
        end
    end
    
    function resetPiezo()
        for kk = 1:4
            mp(kk).writ(0);
            pause(.5)
            mp(kk).writ(5);
        end
    end
    
    function measure(pol, name)
        tosave = struct();
        
        tosave.tstart = now;
        ms.getFrequency();
        tosave.wavelength = ms.VIS_wavelength;
        tosave.position = mc.get_position();

        s0.reset();
        tosave.opt0 = s0.measure();
        s1.reset();
        tosave.opt1 = s1.measure();
        s2.reset();
        tosave.opt2 = s2.measure();
        s3.reset();
        tosave.opt3 = s3.measure();

        if pol
            s4.reset();
            tosave.opt4 = s4.measure();
            s5.reset();
            tosave.opt3 = s5.measure();

            s0.reset();
            tosave.opt0p = s0.measure();
            s1.reset();
            tosave.opt1p = s1.measure();
            s2.reset();
            tosave.opt2p = s2.measure();
            s3.reset();
            tosave.opt3p = s3.measure();
        end
        
        tosave.norm = pmp.read();
        
        tosave.v1 = mp(1).read();
        tosave.v2 = mp(2).read();
        tosave.v3 = mp(3).read();
        tosave.v4 = mp(4).read();
        tosave.hwp = hwpp.read();
        tosave.qwp = qwpp.read();

        tosave.tend = now;
        
        save([name '.mat'], 'tosave')
        drawnow
    end
end