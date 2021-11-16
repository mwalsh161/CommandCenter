function OvernightFastScan(managers)
    f = Imaging.FastScan.instance();
    
    temp = imagesc(1, 1, 1, 'Parent', managers.handles.axImage, 'Tag', 'temp');

    while true
        f.frequencyCalibration()
        f.snaps(temp)
        f.save()
        f.reset()
    end
end