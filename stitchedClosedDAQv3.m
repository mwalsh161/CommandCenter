function stitchedClosedDAQv3(managers)
    dthz = .015;
    orangebase = 484.12;
    orangebase = 406.7;
    orangecenter = orangebase;
    orangewidth = 0.09;
    THZ = (orangecenter - orangewidth/2) : dthz : (orangecenter + orangewidth/2);
    
%     for extra = [1, -1, 2, -2, 3, -3, 4, -4]
    for extra = [1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8]    % Overnight 8/13 wider
        orangecenter = orangebase + extra * (orangewidth + dthz);
        THZ = [THZ ((orangecenter - orangewidth/2) : dthz : (orangecenter + orangewidth/2))];
    end
    
    THZ
    max(THZ) - min(THZ)

    S = Sources.Msquared.instance;

    cam = Imaging.PVCAM.instance;
    C = Sources.Cobolt_PB.instance;
    
    if false
        pm = Drivers.PM100.instance();

        freqs = NaN * THZ;
        pwrs = NaN * THZ;

        ii = 1;

        for thz = THZ
            S.TuneSetpoint(thz);

            freqs(ii) = S.getFrequency();
            pwrs(ii) = pm.get_power();

            freq = freqs(ii)
            pwr = pwrs(ii)

            ii = ii + 1;
        end

        plot(freqs, pwrs)

        save('2023_03_28 orange sweep freq power.mat', 'THZ', 'freqs', 'pwrs')

        return
    end
    
    for thz = THZ 
        
        fprintf('Frequency = %.3f THz!\n', thz)
        
        S.TuneSetpoint(thz);
        
        fprintf(    'Percent = %.3f%%\n!', S.GetPercent)
        
        managers.Experiment.run()
                
        if managers.Experiment.aborted
            error('User aborted.');
        end
    end
end




