function eg308
%     sweep = 10:99;
    sweep = 20:25;
    
    ms =    Drivers.metastage.instance();
    ard =   Drivers.ArduinoServo.instance('localhost', 3);
    img =   Imaging.Camera.instance();
    red =   Sources.WhiteLight.instance();
    green = Sources.Laser532_PB.instance();
    
    red.on();
    green.off();

    for ii = 1:length(sweep)
        for jj = 1:length(sweep)
            X = sweep(ii);
            Y = sweep(jj);
            
            if mod(ii, 2)
                Y = sweep(end+1-jj);
            end
            
            ms.target_X = X + ms.offset;
            ms.target_Y = Y + ms.offset;
            ms.targeting = true;
            
            fname = ['x=' num2str(ii) '.y=' num2str(jj) '.mat'];
            
            measure(fname)
        end
    end
    

    function measure(fname)
        angles = [0 0:60:180];
        names = {'wl', 'g_550LP', 'g_550LP_SiVZPL', 'g_550LP_GeVZPL', 'g_550LP_640LP'};
        
        for kk = 1:length(angles)
            ard.angle = angles(kk);
            pause(.5);
            
            fin.(names{kk}) = img.snap();
            
            if kk == 1      % The first frame is wl, while the rest use green.
                red.off();
                green.on();
            end
        end
        
        save(fname, '-struct', 'fin');
        
        ard.angle = 0;      % No filter.
        red.on();
        green.off();
        pause(.5);
    end
end