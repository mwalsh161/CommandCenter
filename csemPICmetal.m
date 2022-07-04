function s0 = csemPICmetal
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
    
    resetPiezo(0, 5)
%     return
    
    p = .02;
    d = .005;
%     sweep = 10:-p:0;
    sweep = 0:p:10;
%     sweep = 2.5:p:7.5;
%     sweepx = 3:p:7;
    sweepx = sweep;
    optx = false;
    s0 = Base.Sweep({mm}, {mp(1)}, {sweepx}, struct('shouldOptimizeAfter', optx), d);
    s1 = Base.Sweep({mm}, {mp(3)}, {sweepx}, struct('shouldOptimizeAfter', optx), d);
    s2 = Base.Sweep({mm}, {mp(2)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
    s3 = Base.Sweep({mm}, {mp(4)}, {sweep}, struct('shouldOptimizeAfter', 1), d);
    s4 = Base.Sweep({mm, pmp}, {hwpp}, {0:5:90}, struct('shouldOptimizeAfter', 1), .5, 'APD Optimization Over HWP');
    s5 = Base.Sweep({mm, pmp}, {qwpp}, {0:5:90}, struct('shouldOptimizeAfter', 1), .5, 'APD Optimization Over QWP');


    f = figure;

    Base.SweepViewer(s0, subplot(2, 3, 1, 'parent', f))
%     Base.SweepViewer(s01, subplot(1, 2, 2, 'parent', f))
    Base.SweepViewer(s1, subplot(2, 3, 2, 'parent', f))
    Base.SweepViewer(s2, subplot(2, 3, 4, 'parent', f))
    Base.SweepViewer(s3, subplot(2, 3, 5, 'parent', f))
    Base.SweepViewer(s5, subplot(2, 3, 3, 'parent', f))
    Base.SweepViewer(s4, subplot(2, 3, 6, 'parent', f))
    
    base = 200;
    drift = 0;
    
%     [737, 700, 780, 720, 760, 800, 710:20:790] %
    
%     for wl = [619, 637, 601, 650, 581, 590, 610, 630, 585:10:655]
    for wl = [737, 700, 780, 760, 800]
        ms.setpoint_ = wl;
        
        wlname = ['wl=' num2str(wl)];
        
        ii = 1;
        
        while ii < 5 && pmp.read() < 1e-4
            disp(['Attempt ' num2str(ii) ' for ' wlname])
            ms.setpoint_ = wl;
            ii = ii+1;
        end
        
        if pmp.read() < 1e-5
            disp(['Skipping ' wlname])
            continue
        end
        
        mc.position = 0;
        while abs(mc.get_position() - mc.position) > 2; pause(.1); end
        
        drift = 0;
        z = 5;
        
        offset = [0 125 150 275:25:350];
        
        for ii = 1:18
            for jj = 1:length(offset)
                mc.position = base + 475*(ii-1) + offset(jj) + drift;
                resetPiezo(0, z)
                while abs(mc.get_position() - mc.position) > 2; pause(.1); end

%                 return
                
                if true
                    tf = measure((ii == 1 && jj == 1) || (ii == 18 && jj == length(offset)), ['csem_' wlname '_metalloss_' num2str(ii) '_' num2str(jj)]);

                    center = (mp(1).read() + mp(3).read() - 10);
                    center = min(center, .25);
                    center = max(center, -.25);

                    dz = ((mp(1).read() + mp(3).read())/2) - z;
                    dz = min(dz, .25);
                    dz = max(dz, -.25);

                    if tf
                        disp('Allowed to optimize')
                        drift = drift - center*.5
                        z = z + dz*.5
                    end
                end
            end
        end

%         drift = 0;
%         z = 5;
%         
%         for jj = 1:17
%             if jj == 2
%                 drift = 0;
%                 z = 5;
%             end
%             for ii = 1:8
%                 mc.position = base + 3420 + 30*(ii-1) + 420*(jj-1) - 30*(jj > 1) + 30*(jj > 4) + 30*(jj > 8) + 30*(jj > 12) + 30*(jj > 16) + drift;
%                 resetPiezo(0, z)
%                 while abs(mc.get_position() - mc.position) > 2; pause(.1); end
% %                 return
%                 
%                 measure(true, [wlname '_pol_' num2str(ii) '_' num2str(jj)], true, (ii == 1));
% 
%                 center = (mp(1).read() + mp(3).read() - 10);
%                 center = min(center, .25);
%                 center = max(center, -.25);
% 
%                 drift = drift - center*.5;
% 
%                 dz = ((mp(1).read() + mp(3).read())/2) - z;
%                 dz = min(dz, .5);
%                 dz = max(dz, -.5);
% 
%                 z = z + dz*.5;
%             end
%         end
        
%         for jj = 1:6
%             for ii = 1:17
%                 for pp = [-1 1]
%                     mc.position = base + 60*(ii-1) + 1050*(jj-1) + pp*5 + drift;
%                     resetPiezo(pp, z)
%                     while abs(mc.get_position() - mc.position) > 2; pause(.1); end
% 
%                     measure((ii == 1 && jj == 1 && pp == -1) || (ii == 17 && jj == 6 && pp == -1), [wlname '_dc_' num2str(pp) '_' num2str(ii) '_' num2str(jj)]);
%                 
%                     center = (mp(1).read() + mp(3).read() - 10);
%                     center = min(center, .25);
%                     center = max(center, -.25);
%                     
%                     drift = drift - center*.5;
%                     
%                     dz = ((mp(1).read() + mp(3).read())/2) - z;
%                     dz = min(dz, .25);
%                     dz = max(dz, -.25);
%                     
%                     z = z + dz;
%                 end
%             end
%         end
    end
    
    function resetPiezo(sign, z)
        V = [5+sign*2.5, z, 5-sign*2.5, z];
        
        for kk = 1:4
            mp(kk).writ(0);
            pause(.5)
            mp(kk).writ(V(kk));
        end
    end
    
    function tf = measure(pol, name, hwponly, addqwp)
        if nargin < 3
            hwponly = false;
        end
        
        tosave = struct();
        
        tosave.tstart = now;
        ms.getFrequency();
        tosave.wavelength = ms.VIS_wavelength;
        tosave.position = mc.get_position();
        
        tosave.v1i = mp(1).read();
        tosave.v2i = mp(2).read();
        tosave.v3i = mp(3).read();
        tosave.v4i = mp(4).read();
        tosave.hwpi = hwpp.read();
        tosave.qwpi = qwpp.read();

        s2.reset();
        tosave.opt2 = s2.measure();
        s3.reset();
        tosave.opt3 = s3.measure();
        s1.reset();
        tosave.opt1 = s1.measure();
        s0.reset();
        tosave.opt0 = s0.measure();
                
        tf = max(tosave.opt0.m1_pfi10.dat) > 1e5;

        if pol
            s4.reset();
            tosave.opt4 = s4.measure();
            
            if ~hwponly || addqwp
                s5.reset();
                tosave.opt3 = s5.measure();
            end

            if ~hwponly
                s2.reset();
                tosave.opt2p = s2.measure();
                s3.reset();
                tosave.opt3p = s3.measure();
                s1.reset();
                tosave.opt1p = s1.measure();
                s0.reset();
                tosave.opt0p = s0.measure();
                
                tf = max(tosave.opt0p.m1_pfi10.dat) > 1e5;
            end
        end
        
        tosave.norm = pmp.read();
        
        tf = tosave.norm > 1e-5 && tf;
        
        tosave.v1 = mp(1).read();
        tosave.v2 = mp(2).read();
        tosave.v3 = mp(3).read();
        tosave.v4 = mp(4).read();
        tosave.hwp = hwpp.read();
        tosave.qwp = qwpp.read();
        
        tosave.drift = drift;
        tosave.z = z;

        tosave.tend = now;
        
        save([name '.mat'], 'tosave')
        drawnow
    end
end