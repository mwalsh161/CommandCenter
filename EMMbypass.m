function EMMbypass(target)
    wm6 = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', 6, false);
    wm7 = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', 7, false);
    s = Sources.msquared.SolsTiS.instance();
    
%     wm7.SetSwitcherSignalState(1);
    
    try
        diff_freq = wm7.getFrequency() - wm6.getFrequency();
    catch
        diff_freq = s.c/1950
    end
    
    target_freq = s.c/target;
    solstis_freq = target_freq - diff_freq;
    s.TuneSetpoint(solstis_freq);
    
%     wm7.SetSwitcherSignalState(1);
    
    diff_freq = wm7.getFrequency() - wm6.getFrequency();
    
    diff_wavelength = s.c/diff_freq
    solstis_wavelength = s.c/solstis_freq
    emm_wavelength = s.c/wm7.getFrequency()
end