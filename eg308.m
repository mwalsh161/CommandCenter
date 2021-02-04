function ms = eg308
%     sweep = 10:99;
%     sweep = 20:25;
    sweep = 0:5;
%     sweep = 0;
    
    ni =    Drivers.NIDAQ.dev.instance('dev1');
    stage = Stages.MAX302motors.instance();
    ms =    Drivers.metastage.instance();
    
    ms.coarse_x = stage.motors{1}.get_meta_pref('Position');
    ms.coarse_y = stage.motors{2}.get_meta_pref('Position');
    
    ms.fine_x = ni.OutLines(6).pref;
    ms.fine_y = ni.OutLines(5).pref;
    ms.fine_z = ni.OutLines(7).pref;
    
    ard =   Drivers.ArduinoServo.instance('localhost', 3);
    img =   Imaging.umanager.Camera.instance();
    qr =    Imaging.QR.instance();
    red =   Sources.WhiteLight.instance();
    green = Sources.Laser532_nidaq_PB.instance();
    
    ms.image = qr;
    
    red.on();
    green.off();
    img.exposure = 100;
    
    ms.calibrate();
    
    baseX = round(qr.X - ms.offset);
    baseY = round(qr.Y - ms.offset);
    ms.navigateTarget(baseX + ms.offset, baseY + ms.offset);
    
%     return;

    for ii = 1:length(sweep)
        for jj = 1:length(sweep)
            dX = sweep(ii);
            dY = sweep(jj);
            
            if mod(ii, 2)
                dY = sweep(end+1-jj);
            end
            
            X = baseX + dX;
            Y = baseY + dY;
            
%             ms.target_X = X + ms.offset;
%             ms.target_Y = Y + ms.offset;
%             ms.targeting = true;
            ms.navigateTarget(X + ms.offset, Y + ms.offset);
            
            fname = ['X=' num2str(X) '.Y=' num2str(Y) '.mat'];
            
            disp(['Moving to ' fname '!']);
            
            measure(fname)
        end
    end
    

    function measure(fname)
        angles = [0 0:60:180];
        names = {'wl', 'g_550LP', 'g_550LP_SiVZPL', 'g_550LP_GeVZPL', 'g_550LP_640LP'};
        
        fin.coarse_x = ms.coarse_x.read();
        fin.coarse_y = ms.coarse_y.read();
%         fin.coarse_z = ms.coarse_z.read();
        
        fin.fine_x = ms.fine_x.read();
        fin.fine_y = ms.fine_y.read();
        fin.fine_z = ms.fine_z.read();
        
        fin.qrX = qr.X;
        fin.qrY = qr.Y;
        
        fin.g_exposure = 2000;
        fin.wl_exposure = 100;
        
        for kk = 1:length(angles)
            disp(['    * Snapping ' names{kk} '!']);
            ard.angle = angles(kk);
            pause(.5);
            
            img0 = img.snapImage();
            if qr.flip                  % Put the flipping elsewhere eventually.
                img0 = flipud(img0);
            end
            if qr.rotate ~= 0
                img0 = rot90(img0, round(qr.rotate/90));
            end
            fin.(names{kk}) = img0;
            
            if kk == 1      % The first frame is wl, while the rest use green.
                red.off();
                green.on();
                img.exposure = fin.g_exposure;
            end
        end
        
        save(fname, '-struct', 'fin');
        
        ard.angle = 0;      % No filter.
        red.on();
        green.off();
        img.exposure = fin.wl_exposure;
        pause(.5);
    end
end