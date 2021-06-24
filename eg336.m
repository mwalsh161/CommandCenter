function eg336(ms, managers)
    folder = 'Z:\Experiments\Diamond\EG336\2021_06_04 RoMi';

    % Disable inactivity!
    timerH = managers.handles.inactivity_timer;
    managers.inactivity = true;
    if ~isempty(timerH)
        stop(timerH);
    end

    xsweep = 0:48;
    ysweep = 0:48;

    ard =   Drivers.ArduinoServo.instance('localhost', 3);
    red =   Sources.WhiteLight.instance();
    green = Sources.Laser532_nidaq_PB.instance();

    f = figure('Name', 'Data', 'NumberTitle', 'off', 'Menubar', 'none', 'Toolbar', 'none');
    f.Position(2) = f.Position(2) - f.Position(3) + f.Position(4);
    f.Position(4) = f.Position(3);
    a = axes('Units', 'normalized', 'Position', [0 0 1 1], 'DataAspectRatio', [1 1 1]);
    imsc = imagesc(a, ms.image.image.snapImage());
    set(a, 'YDir', 'normal');
    colormap('gray');

    red.on();
    green.off();
    ard.angle = 0;      % No filter.

    baseX = 0; %round(ms.image.X - ms.offset);
    baseY = 0; %round(ms.image.Y - ms.offset);
%     ms.navigateTarget(baseX + ms.offset, baseY + ms.offset);

%     N = 81*16 - 16;

    n = 1;
    N = -Inf;

    for ii = 1:length(xsweep)
        for jj = 1:length(ysweep)
            if n > N
                dX = xsweep(ii);
                dY = ysweep(jj);

                if ~mod(ii, 2)
                    dY = ysweep(end+1-jj);
                end

                X = baseX + dX;
                Y = baseY + dY;

    %             ms.target_X = X + ms.offset;
    %             ms.target_Y = Y + ms.offset;
    %             ms.targeting = true;

                fname = ['X=' num2str(X) '.Y=' num2str(Y)];

                disp(['Moving to ' fname '!']);
                ms.navigateTarget(X + ms.offset, Y + ms.offset);

    %             if ms.image.N < 3
                ms.focusSmart();
    %             end

                saveas(ms.image.graphics.figure, [folder fname '.png']);

                measure([folder fname '.mat']);
            end
            n = n + 1;
        end
    end


    function measure(fname)
%         angles = [0 0:60:180 0];
        angles = [0 0 120 180 0];
%         names = {'wl', 'g_550LP', 'g_550LP_SiVZPL', 'g_550LP_GeVZPL', 'g_550LP_640LP'};
        names = {'wlpre', 'g_550LP', 'g_550LP_SiVZPL', 'g_550LP_640LP', 'wlpost'};

        fin.coarse_x = ms.coarse_x.read();
        fin.coarse_y = ms.coarse_y.read();
        fin.coarse_z = ms.coarse_z.read();

        fin.fine_x = ms.fine_x.read();
        fin.fine_y = ms.fine_y.read();
        fin.fine_z = ms.fine_z.read();

        fin.qr_X = ms.image.X;
        fin.qr_Y = ms.image.Y;

        fin.g_exposure = 5000;
        fin.wl_exposure = 100;

        fin.measure_start = now;

        for kk = 1:length(angles) %change angles to filter wheel settings
            disp(['    * Snapping ' names{kk} '!']);

            ard.angle = angles(kk);
            if kk ~= 1
                pause(.5);
            end

            if kk == length(angles)  % The first frame is wl, while the rest use green.
                red.on();
                green.off();
            end

            img0 = uint32(ms.image.image.snapImage());
            for ll = 1:(ceil(fin.g_exposure/fin.wl_exposure)-1)
                img0 = img0 + uint32( ms.image.image.snapImage());
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
            disp(['        ...done']);
        end

        fin.measure_end = now;

        save(fname, '-struct', 'fin');

%         ard.angle = 0;      % No filter.
%         red.on();
%         green.off();
% %         ms.image.image.exposure = fin.wl_exposure;
%         pause(.5);
    end
end
