function memorytest(core)
    seqmode = true; %false;
    
    mem = NaN(1, 200);
    f = figure;
    
    a = subplot(2,1,1);
    yyaxis left
    p1 = plot(a, 1:length(mem), mem);
    ylabel('MATLAB Memory Use')
    yyaxis right
    hold on
    p3a = plot(a, 1:(length(mem)-1), mem(2:end));
%     p3b = plot(a, 1:(length(mem)-1), mem(2:end));
%     p3c = plot(a, 1:(length(mem)-1), mem(2:end));
%     if seqmode
%         legend({'Total Memory', 'Total Delta', 'Delta due to starting continuous', 'Delta due to getting frame'});
%     else
%         legend({'Total Memory', 'Total Delta', 'Delta due to snapping', 'Delta due to getting'});
%     end
    ylabel('Delta MATLAB Memory Use')
    
    a = subplot(2,1,2);
    yyaxis left
    p2 = plot(a, 1:length(mem), mem);
    ylabel('Time For Frame Grab')
    yyaxis right
    p4 = plot(a, 1:length(mem), mem);
    ylabel('Num Frames')
    
    tic
    
    if core.isSequenceRunning()
        core.stopSequenceAcquisition();
    end
    
    core.setExposure(100);
    
    if seqmode
        if ~core.isSequenceRunning()
            core.startContinuousSequenceAcquisition(100);
        end
    end
    
    N = 1;
    
    m1 = memory;
    
    basemem = m1.MemUsedMATLAB;
    
    while isvalid(f) && ~(seqmode && ~core.isSequenceRunning)
        if seqmode
            if false %mod(N, 20) == 0
                if core.isSequenceRunning
                    core.stopSequenceAcquisition
                end

                expnew = randi([250,300]);
                disp(['Frame ' num2str(N) ': Setting exposure to ' num2str(expnew)]);

                core.setExposure(expnew);

                if ~core.isSequenceRunning()
                    core.startContinuousSequenceAcquisition(N); % Use increasing N to deduce if memory correlates.
                    disp(['Set image buffer to ' num2str(core.getImageBufferSize())]);
                end
            end
            
%             m2 = memory;

            dat = [];
            
            while isempty(dat)
                while core.getRemainingImageCount() == 0
        %             disp('Waiting for image.')
                    pause(.01);
                end

                try
                    dat = core.popNextImage();
                catch err
                    disp(['Fail on frame #' num2str(N)]);
                    warning(err.message);
                end
            end
        else
            core.snapImage();
            
            m2 = memory;
            
            dat = core.getImage();
        end
        
        if isvalid(f)
            p2.YData = circshift(p2.YData, 1);
            p2.YData(1) = toc;

            tic

            m3 = memory;
            p1.YData = circshift(p1.YData, 1);
            p1.YData(1) = m3.MemUsedMATLAB - basemem;
            
            p3a.YData = circshift(p3a.YData, 1);
%             p3b.YData = circshift(p3b.YData, 1);
%             p3c.YData = circshift(p3c.YData, 1);
            p3a.YData(1) = m3.MemUsedMATLAB - m1.MemUsedMATLAB;
%             p3b.YData(1) = m2.MemUsedMATLAB - m1.MemUsedMATLAB;
%             p3c.YData(1) = m3.MemUsedMATLAB - m2.MemUsedMATLAB;

            p4.YData = N - (1:length(mem));
            
            m1 = m3;

            drawnow;
        end
        
        N = N + 1;
    end
    
    if ~isvalid(f)
        disp('Figure was closed.')
    end
    
    if (seqmode && ~core.isSequenceRunning())
        disp('Camera aquisition failed.')
    end
    
end