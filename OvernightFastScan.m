function OvernightFastScan(managers)
    f = Imaging.FastScan.instance();
    
    temp = imagesc(NaN, NaN, NaN, 'Parent', managers.handles.axImage, 'Tag', 'temp');

    while true
        f.frequencyCalibration()
        f.snaps(temp)
        f.save()
        f.reset()
    end
end