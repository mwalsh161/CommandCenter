function msquaredStressTest
    f = figure;

    L = 590:5:640;
    
    ms = Sources.Msquared.instance();

    for l = L
        if ~isvalid(f)
            break
        end
        
        ms.setpoint_ = l;
        ms.VIS_wavelength
    end
end