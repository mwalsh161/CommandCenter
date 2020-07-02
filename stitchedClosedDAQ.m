function stitchedClosedDAQ(managers)
%     GG = 10.^(-2:.5:1.5);
% %     GG = 10.^(1.5:1:1.5);
%     
%     C = Sources.Cobolt_PB.instance;
%     
%     C.arm()
%     C.on()
    dwl = .0075;
    
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
    WL = [497.5:dwl:498];


%     S0 = Sources.msquared.SolsTiS.instance;
%     S0.lock_wavelength("off")
    S = Sources.msquared.EMM.instance;
%     S.WavelengthLock(false);
%     S.set_etalon_lock(false)

    
    cam = Imaging.PVCAM.instance;
    C = Sources.Cobolt_PB.instance;
    wheel = Drivers.ArduinoServo.instance('localhost', 2); % Which weaves as it wills.

    cam.exposure = 300;
    C.power = 10;
    wheel.angle  = 45;
    
    for wl = WL(18:end) %18:end added at 10:03 on 7/2 by EBersin to continue experiment
        wl
%         S.WavelengthLock(true);
        try
            S.TuneSetpoint(wl);
        catch
            
        end
        pause(.5)
        S.GetPercent
        
        while abs(S.GetPercent - 50) > 5
            try
                S.TuneSetpoint(wl + 2*dwl);
                S.TuneSetpoint(wl + (rand-.5)*dwl/40);
            catch
            end
            pause(.5)
            S.GetPercent
        end
        
        if abs(S.getFrequency() - wl) > 10*dwl
            disp(S.getFrequency())
            disp(wl)
            error('Laser is freaking out.')
        end

        managers.Experiment.run()
                
        if managers.Experiment.aborted
            error('User aborted.');
        end
    end
end