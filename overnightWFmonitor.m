% Get cam
ni = Drivers.NIDAQ.dev.instance('Dev1');
cam = Imaging.PVCAM.instance();
cam.exposure = 2000; %2 s
wm = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu',5);
ii = 0;

while true
%     for on = [0 1]
%         ni.WriteDOLines('apd mirror',on);
        t = now;
        img = cam.snapImage();
        freq = wm.getFrequency;
        ii = ii + 1;
        
        fname = sprintf('X:\\Experiments\\Ian\\Current\\CSEM\\Round 1\\Wafer 1\\2022_02_18 mod.safe.v4.0+ M2 Cyro\\2022_03_02 SiV\\wf_image_%i',ii);
        save(fname,'img', 't','freq');
        
        pause(60)
%     end 
end 