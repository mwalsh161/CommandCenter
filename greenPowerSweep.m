function greenPowerSweep(managers)
    GG = 10.^(-2:.5:1.5);
%     GG = 10.^(1.5:1:1.5);
    
    C = Sources.Cobolt_PB.instance;
    
    C.arm()
    C.on()
    
    for g = GG
        C.CW_power = g;

        managers.Experiment.run()
    end
g
    E = Experiments.WidefieldSlowScan.Closed.instance;
    E.repump_always_on = false;
    
    for g = GG(end:-1:1)
        C.CW_power = g;

        managers.Experiment.run()
    end
end