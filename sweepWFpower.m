function sweepWFpower(managers)
    e = managers.Experiment;
    ni = Drivers.NIDAQ.dev.instance('Dev1');

    for voltage = [0, .1, .2, .5, 1, 2] %, 0, .1, .2, .5, 1, 2]
        ni.WriteAOLines('laser', voltage)
        
        if ~e.aborted
            e.run()
        end
    end
    
    if e.aborted
        e.forceSave()
    end
end