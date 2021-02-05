function eg308(ms)
    sweep = 0:10;
    
    ard =   Drivers.ArduinoServo.instance('localhost', 3);
    red =   Sources.WhiteLight.instance();
    green = Sources.Laser532_nidaq_PB.instance();

    f = figure;
    f.Position(2) = f.Position(2) - f.Position(3) + f.Position(4);
    f.Position(4) = f.Position(3);
    a = axes('Units', 'normalized', 'Position', [0 0 1 1], 'DataAspectRatio', [1 1 1]);
    imsc = imagesc(a, ms.image.image.snapImage());
    colormap('gray');
    
    baseX = round(ms.image.X - ms.offset);
    baseY = round(ms.image.Y - ms.offset);
    ms.navigateTarget(baseX + ms.offset, baseY + ms.offset);

    for ii = 1:length(sweep)
        for jj = 1:length(sweep)
            dX = sweep(ii);
            dY = sweep(jj);
            
            if ~mod(ii, 2)
                dY = sweep(end+1-jj);
            end
            
            X = baseX + dX;
            Y = baseY + dY;
            
%             ms.target_X = X + ms.offset;
%             ms.target_Y = Y + ms.offset;
%             ms.targeting = true;
            
            fname = ['X=' num2str(X) '.Y=' num2str(Y)];
            
            disp(['Moving to ' fname '!']);
            ms.navigateTarget(X + ms.offset, Y + ms.offset);
            saveas(ms.image.graphics.figure, [fname '.png']);
            
            measure([fname '.mat']);
        end
    end
    

    function measure(fname)
        angles = [0 0:60:180];
        names = {'wl', 'g_550LP', 'g_550LP_SiVZPL', 'g_550LP_GeVZPL', 'g_550LP_640LP'};
        
        fin.coarse_x = ms.coarse_x.read();
        fin.coarse_y = ms.coarse_y.read();
        fin.coarse_z = ms.coarse_z.read();
        
        fin.fine_x = ms.fine_x.read();
        fin.fine_y = ms.fine_y.read();
        fin.fine_z = ms.fine_z.read();
        
        fin.qrX = ms.image.X;
        fin.qrY = ms.image.Y;
        
        fin.g_exposure = 2000;
        fin.wl_exposure = 100;
        
        for kk = 1:length(angles)
            ard.angle = angles(kk);
            pause(.5);
            
            img0 = ms.image.image.snapImage();
            for ll = 1:(ceil(fin.g_exposure/fin.wl_exposure)-1)
                img0 = img0 + ms.image.image.snapImage();
            end
            
            if ms.image.flip                  % Put the flipping elsewhere eventually.
                img0 = flipud(img0);
            end
            if ms.image.rotate ~= 0
                img0 = rot90(img0, round(ms.image.rotate/90));
            end
            fin.(names{kk}) = img0;
            
            imsc.CData = img0;
            
            if kk == 1      % The first frame is wl, while the rest use green.
                red.off();
                green.on();
%                 ms.image.image.exposure = fin.g_exposure;
            end
            disp(['    * Snapped ' names{kk} '!']);
        end
        
        save(fname, '-struct', 'fin');
        
        ard.angle = 0;      % No filter.
        red.on();
        green.off();
%         ms.image.image.exposure = fin.wl_exposure;
        pause(.5);
    end
end