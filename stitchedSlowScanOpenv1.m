function stitchedClosedDAQv3(managers)
    %orangecenter = 484;
    %THZ = (orangecenter - 1) : dthz : (orangecenter + 1);
    
    dwvl = 0.01; % 5 GHz
    %orangecenter = 484.12;
    %orangewidth = 0.09;
    %THZ = (orangecenter - orangewidth/2) : dthz : (orangecenter + orangewidth/2);

    S = Sources.Msquared.instance;
    S = Sources.CWAVE.instance;
    S.com('set_piezo_mode', 'opo', 4);


    cam = Imaging.PVCAM.instance;
    C = Sources.Cobolt_PB.instance;

    cam.exposure = 100;
    cam.frames = 1;
%     C.power = 10;
%     C.arm();
%     C.on();
    
    if false
        %pm = Drivers.PM100.instance();

        %freqs = NaN * THZ;
        %pwrs = NaN * THZ;
        freqs = NaN*[0 0 0 0 0]

        ii = 1;

        for i=1:10%for thz = THZ
            %S.TuneSetpoint(thz);
            S.elements_move(-dwvl)
            freqs(ii) = S.getFrequency();
            %pwrs(ii) = pm.get_power();

            freq = freqs(ii)
            %pwr = pwrs(ii)
            pause(100)
            cwavetest(S)

            ii = ii + 1;
        end

        plot(freqs)%, pwrs)

        %save('2023_04_29 orange sweep freq power.mat', 'THZ', 'freqs', 'pwrs')

        return
    end
    
    for i=1:10 
        
        %fprintf('Frequency = %.3f THz!\n', thz)
        
        %S.TuneSetpoint(thz);
        S.elements_move(-dwvl)
        
        fprintf(    'Frequency = %.3f THz!\n', S.getFrequency())
        
        managers.Experiment.run()
                
        if managers.Experiment.aborted
            error('User aborted.');
        end
    end
end



%[50:-0.2:40 40:0.2:60 60:-0.2:50]
