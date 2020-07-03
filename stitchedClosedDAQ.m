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
    THZ = [497.5:dthz:498];

    S = Sources.msquared.EMM.instance;

    pm = Drivers.PM100.instance();
    cam = Imaging.PVCAM.instance;
    C = Sources.Cobolt_PB.instance;
    wheel = Drivers.ArduinoServo.instance('localhost', 2); % Which weaves as it wills.

    cam.exposure = 300;
    C.power = 10;
    C.arm();
    C.on();
    wheel.angle  = 45;
    
    for thz = THZ 
        thz
        try
            S.TuneSetpoint(thz);
        catch
            
        end
        pause(.5)
        S.GetPercent
        
        while abs(S.GetPercent - 50) > 5
            try
                S.TuneSetpoint(thz + 2*dthz);
                S.TuneSetpoint(thz + (rand-.5)*dthz/40);
            catch
            end
            pause(.5)
            S.GetPercent
        end
        
        if abs(S.getFrequency() - thz) > 10*dthz
            disp(S.getFrequency())
            disp(thz)
            error('Laser is freaking out.')
        end

        C.off
        
        try
            lockPower(0.01, pm, wheel); % lock power to 10 uW
        catch
            disp('Power setting failed; proceeding anyway.');
        end
        
        managers.Experiment.run()
                
        if managers.Experiment.aborted
            error('User aborted.');
        end
    end
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