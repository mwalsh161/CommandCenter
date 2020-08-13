function stitchedClosedDAQ(managers)
    dthz = .0075;
    
    % SiV
%     460.5
%     WL = 406.500:dwl:406.900;
%     WL = 406.710:dwl:406.900;
%     WL = [406.740:dwl:406.900 406.500:dwl:406.710];
%     WL = 406.7;

    % NV
%     WL = 470.31:dwl:470.41;

    % GeV
%     WL = [497:(dwl*20):499 497.5:dwl:498.5];
%     THZ = [497.25:dthz:498.25];
%     THZ = [497.5:dthz:498 498.5:dthz:499 498:dthz:498.5];
%     THZ = [497.25:dthz:499.25];
    
%      497.5750
%     THZ = [497.5750:dthz:499.25 497.25:dthz:497.5];
%     THZ = [497.582:dthz:499.25 497.25:dthz:497.5];
%     THZ = [497.859:dthz:499.25 497.25:dthz:497.5];
%     THZ = [497.25:dthz:499.25]; %2020_07_05 ebersin
%     THZ = [497.377:dthz:499.25]; %2020_07_07 ichr
%     THZ = [497.527:dthz:499.25]; %2020_07_08 ichr
%     THZ = [497.25:dthz:499.25]; %2020_07_09 ichr
    THZ = [497.5:dthz:498 498.5:dthz:499 498:dthz:498.5];   % AB, CD, gap, ichr 8/11
%     THZ = [497.5751:dthz:498 498.5:dthz:499 498:dthz:498.5];   % restart of above, ebersin 8/12

    offset = -153.7248;  % Offset between SolsTiS and EMM. Equivalent to fiber laser frequency.


    S = Sources.msquared.SolsTiS.instance;
    delete(S);  % Make sure SolsTiS is not loaded.
    
    pause(2) %MS8.13 1->2 
    
    
    E = Sources.msquared.EMM.instance;
    pause(1);
    E.TuneSetpoint(mean(THZ));              % Set the position of the PPLN and prism to be ~optimal for our tuning range.
%     E.optimizePower();
    pause(1)
    delete(E);                              % Kill the EMM handle and... this is what needs addressing. deleting(E) turns off EMM completely. Same happens when
    %unloading EMM manually from CC interface. Will require rewriting EMM
    %and solstis protocols to get this working.... -ms 
    pause(1)
    S = Sources.msquared.SolsTiS.instance;  % Move to the SolsTiS which is more relaible to commune with.

    pm = Drivers.PM100.instance();
    pm.set_wavelength(602)
    cam = Imaging.PVCAM.instance;
    C = Sources.Cobolt_PB.instance;
    wheel = Drivers.ArduinoServo.instance('localhost', 2); % Which weaves as it wills.
    exp = managers.Experiment.active_module;
    
     
    wm7 = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', 7, true);
    wm7.SetSwitcherSignalState(1);
    
    cam.exposure = 300;
    cam.frames = 1;
    C.power = 10;
    C.arm();
    C.on();
    wheel.angle  = 45;
    
%     url = 'https://hooks.slack.com/services/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';
    
    for thz = THZ 
        fprintf('Frequency = %.3f THz!\n', thz)
        try
            S.TuneSetpoint(thz + offset);
            pause(1);
        catch err
            warning(err.message)
        end
        pause(.5)
        fprintf(    'Percent = %.3f%%\n!', S.GetPercent)
        
        while abs(S.GetPercent - 50) > 5
            try
                S.TuneSetpoint(thz + offset + 2*dthz);
                pause(3);
                S.TuneSetpoint(thz + offset + (rand-.5)*dthz/40);
                pause(3);
            catch err
                warning(err.message)
            end
            pause(.5)
            fprintf('    Percent = %.3f%%!\n', S.GetPercent)
            
            if abs(S.GetPercent - 50) > 5 && abs(S.GetPercent - 50) < 10
                try
                    fprintf('        Percent close enough to 50%% to attempt to TunePercent.\n')
                    S.lock_wavelength("off")
                    S.TunePercent(50);
                	pause(3);
                    fprintf('    Percent = %.3f%%!\n', S.GetPercent)    
                catch err
                    warning(err.message)
                end
            end
            
            wm7.SetSwitcherSignalState(1);
            cur = wm7.getFrequency();
%             cur = S.getFrequency();
            
            fprintf('    [getFrequency = %.3f THz ?= %.3f THz] == %i because abs(dif) == %.3f > %.3f!\n', cur, thz, abs(cur - thz) <= 10*dthz, abs(cur - thz), 10*dthz)
        
            if abs(cur - thz) > 10*dthz    %  This should catch inf issues??
                disp('++++Trying to fix error?');
%                 S.ready
%                 S.updateStatus  % Try to fix the error.
%                 S.ready
                pause(.5)
                
                try
                    S.TuneSetpoint(thz + offset + 2*dthz);
                    pause(3);
                    S.TuneSetpoint(thz + offset + (rand-.5)*dthz/40);
                    pause(3);
                catch err
                    warning(err.message)
                end
                pause(.5)
                fprintf('    Percent = %.3f%%!\n', S.GetPercent)
                
                wm7.SetSwitcherSignalState(1);
                cur = wm7.getFrequency();
            
                fprintf('    [getFrequency = %.3f ?= %.3f THz] == %i because abs(dif) == %.3f > %.3f!\n', cur, thz, abs(cur - thz) > 10*dthz, abs(cur - thz), 10*dthz)
        
                if abs(cur - thz) > 10*dthz

                    disp(S.getFrequency())
                    disp(cur)
                    disp(thz)
%                     SlackNotification(url,'Laser is freaking out!','@ichr',':robot_face:','cRoMi')
%                     SlackNotification(url,'Laser is freaking out!','@ebersin',':robot_face:','cRoMi')
                    error('Laser is freaking out.')
                end
            end
        end

        C.off
        exp.resLaser = S;
        
        try
            exp.resLaser.on;
            lockPower(0.0015, pm, wheel); % lock power to ~1.5 uW
        catch
            disp('Power setting failed; proceeding anyway.');
        end
        
        S.lock_wavelength("off")
        managers.Experiment.run()
                
        if managers.Experiment.aborted
            error('User aborted.');
        end
    end
    
%     SlackNotification(url,'Experiment Finished!','@ichr',':robot_face:','cRoMi')
%     SlackNotification(url,'Experiment Finished!','@ebersin',':robot_face:','cRoMi')
end

function lockPower(target,pm,wheel)
    P = 70;            % P for PID (no I or D because laziness)    
    timeout = 30;       % Timeout after X seconds
    tol = 0.02*target;  % Must be within X% of target
    
    currPow = pm.get_power('samples', 10, 'units', 'mW');
    clk = tic;
    
    while (toc(clk) < timeout && abs(currPow(end)-target) > tol) || toc(clk) < timeout/2
        wheel.angle = max(min(wheel.angle-P*(log10(currPow(end))-log10(target)), 180), 0); %/sqrt(length(currPow));
        [currPow(end+1), powstd] = pm.get_power('samples', 10, 'units', 'mW');
        fprintf('Angle at %.2f, power at %.2f +/- %.2f uW\n', wheel.angle, currPow(end)*1e3, powstd*1e3)
    end
    
    assert(abs(currPow(end)-target) < tol + powstd, 'Unable to lock power to target')
end