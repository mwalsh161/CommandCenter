function stitchedClosedDAQ(managers)
%     GG = 10.^(-2:.5:1.5);
% %     GG = 10.^(1.5:1:1.5);
%     
%     C = Sources.Cobolt_PB.instance;
%     
%     C.arm()
%     C.on()
    dwl = .01;
    
    % SiV
%     460.5
%     WL = 406.500:dwl:406.900;
%     WL = 406.710:dwl:406.900;
%     WL = [406.740:dwl:406.900 406.500:dwl:406.710];
%     WL = 406.7;
    WL = 470.31:dwl:470.41;


%     S0 = Sources.msquared.SolsTiS.instance;
%     S0.lock_wavelength("off")
    S = Sources.msquared.EMM.instance;
%     S.WavelengthLock(false);
%     S.set_etalon_lock(false)
    
    for wl = WL
        wl
%         S.WavelengthLock(true);
        try
            S.TuneSetpoint(wl);
        catch
            
        end
        pause(.5)
        S.GetPercent
        
        while abs(S.GetPercent - 50) > 4
            try
                S.TuneSetpoint(wl + 2*dwl);
                S.TuneSetpoint(wl + (rand-.5)*dwl/40);
            catch
            end
            pause(.5)
            S.GetPercent
        end

        managers.Experiment.run()
    end
% g
%     E = Experiments.WidefieldSlowScan.Closed.instance;
%     E.repump_always_on = false;
%     
%     for g = GG(end:-1:1)
%         C.CW_power = g;
% 
%         managers.Experiment.run()
%     end
end