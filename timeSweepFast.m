function timeSweepFast(managers)
    pm = Drivers.PM100.instance();
    wheel = Drivers.ArduinoServo.instance('localhost', 2); % Which weaves as it wills.
    
        
    try
%         lockPower(0.0015, pm, wheel); % lock power to 1.5 uW
        lockPower(0.015, pm, wheel); % lock power to 1.5 uW
    catch
        disp('Power setting failed; proceeding anyway.');
    end
    error("a")

    E = Experiments.WidefieldSlowScan.DAQ.Fast.instance();

    for tt = .5:.5:5
        E.fast_time = tt;
        
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
    
    currPow = pm.get_power('samples', 5, 'units', 'mW');
    clk = tic;
    
    while (toc(clk) < timeout && abs(currPow(end)-target) > tol) || toc(clk) < timeout/2
        wheel.angle = max(min(wheel.angle-P*(log10(currPow(end))-log10(target)), 180), 0); %/sqrt(length(currPow));
        [currPow(end+1), powstd] = pm.get_power('samples', 5, 'units', 'mW');
        fprintf('Angle at %.2f, power at %.2f +/- %.2f uW\n', wheel.angle, currPow(end)*1e3, powstd*1e3)
    end
    
    assert(abs(currPow(end)-target) < tol + powstd, 'Unable to lock power to target')
end