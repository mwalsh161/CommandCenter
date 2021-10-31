function stitchedClosedDAQv2(managers)
    dthz = .010; %20 ghz
    
    % SiV
%     460.5
%     WL = 406.500:dwl:406.900;
%     WL = 406.710:dwl:406.900;
%     WL = [406.740:dwl:406.900 406.500:dwl:406.710];
%     WL = 406.7;
%    THZ = 406.300:dthz:407.300; %sutula 
%    THZ = 406.500:dthz:407.300; %sutula
%     THZ = 405.900:dthz:407.000; %sutula 2021_10_16 based on visual  
THZ = 406.340:dthz:407.000; 
%     THZ = 405.67:dthz:407.88;

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
%     THZ = [497.625:dthz:499.25]; %2020_07_09 ichr

    S = Sources.Msquared.instance;

    cam = Imaging.PVCAM.instance;
    C = Sources.Cobolt_PB.instance;

    cam.exposure = 1000;
    cam.frames = 1;
    C.power = 10;
    C.arm();
    C.on();
    
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




