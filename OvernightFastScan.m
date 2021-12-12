function OvernightFastScan(managers)
    f = Imaging.FastScan.instance();
    msq = Sources.Msquared.instance(); 
    temp = imagesc(1, 1, 1, 'Parent', managers.handles.axImage, 'Tag', 'temp');
    targetWL = 619.2345; %target in nm 

%     while true
%         f.frequencyCalibration()
%         f.snaps(temp)
%         f.save()
%         f.reset()
%         ni = Drivers.NIDAQ.dev.instance('Dev1');
%         ni.ClearAllTasks;
%     end

%make sure no voltage is applied before initial tune 
    ni = Drivers.NIDAQ.dev.instance('Dev1');
    
    for i=1:100
        ni.ClearAllTasks;
        ni.WriteAOLines('laser',0); %always reset voltage to zero before tuning
        pause(1);
        try
            msq.setpoint_ = targetWL; %better than tunecoarse 
        catch
            
        end 
        sprintf('EMM set to %d',msq.setpoint)
        
        f.fastCalibration; 
        
        if mod(i,2)
            f.repump_always = true;
        else
            f.repump_always = false;
        end 
        
        f.snaps(temp)
        f.save()
        f.reset()
    end 
end
