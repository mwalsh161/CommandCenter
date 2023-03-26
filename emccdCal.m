function emccdCal
    cam = Imaging.PVCAM.instance();
    
    gains = [1,2,3];
    gains2 = [1 10 100 200:100:3000 4095];
    
    exposures = [1 10 20];  % ms
    
    img = cam.snapImage();
    
    for exposure = exposures
        cam.exposure = exposure;
        
        for gain = gains
            cam.gain = gain;

            ii = 1;
            imgs = NaN(size(img, 1), size(img, 2), length(gains2));
            
            for gain2 = gains2
                [exposure, gain, gain2]
                cam.EMgain = gain2;
                
                imgs(:,:,ii) = cam.snapImage();
                
                ii = ii + 1;
            end
            fname = sprintf('X:\\Experiments\\MontanaII\\2022-05-04\\expo_%i_gain_%i', exposure, gain);
            save(fname, 'exposure', 'gain', 'gains2', 'imgs');
        end
    end
end