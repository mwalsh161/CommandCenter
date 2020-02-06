function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    
    try
        obj.resLaser.off
        obj.data = [];
        rangeWL = eval(obj.ScanRange);
        rangeFreq = Sources.TunableLaser_invisible.c./rangeWL; % change wavelength (nm) to frequency (THz)
        obj.PM.set_average_count(1);
        PWavg_num = 25;
        PWall = zeros(length(eval(obj.ScanRange)),PWavg_num);
        
        switch obj.Detection_Type
            case 'Spectrometer'
                panel = ax.Parent; delete(ax); % For spectrometer detection, we need two axes for plotting
                ax(1) = subplot(1,2,1,'parent',panel);
                ax(2) = subplot(1,2,2,'parent',panel);
                temp_exposure = obj.takeSpec.exposure;
                obj.takeSpec.exposure = 0.001;
                obj.takeSpec.run(status,managers,ax(2)) % Take Dummy Spectra to get spectrometer pixel number
                obj.takeSpec.exposure = temp_exposure;
                spectrum = obj.takeSpec.GetData(managers.Stages,managers.Imaging);
                scanH = imagesc(ax(1),spectrum.wavelength,rangeWL,NaN(length(rangeWL),length(spectrum.wavelength))); % ,'parent',managers.handles.axImage
                set(ax(1),'ydir','normal');
            case 'APD'
                scanH = plot(ax,rangeWL,NaN(1,length(rangeWL)),'LineWidth',1.5);
                xlabel(ax,'Excitation Wavelength (nm)')
                ylabel(ax,'APD counts')
                obj.data.APD_dwelltime = obj.APD_dwell;
        end
        
        error_count = 0;
        for i = 1:length(rangeWL)
            assert(~obj.abort_request,'User aborted.');
            try % Try wavelength tuning once more if it fails
                obj.resLaser.TuneCoarse(rangeFreq(i)); % Tune solstis or EMM
            catch err
                if strcmp(err.msgID, 'HWSERVER:empty') || strcmp(err.message,'Tuning failed')
                    try % Move to next target wavelength if it fails once again
                        obj.resLaser.TuneCoarse(rangeFreq(i)); % Tune solstis or EMM
                    catch err
                        if strcmp(err.msgID, 'HWSERVER:empty') || strcmp(err.message,'Tuning failed')
                            error_count = error_count+1;
                            obj.meta.error_count(error_count) = i;
                            obj.meta.error_msg(error_count) = err.message;
                            continue
                        else
                            rethrow(err);
                        end
                    end
                else
                    retrhow(err);
                end
            end
            pause(0.2);
            obj.resLaser.on
            pause(0.1);
            
            switch obj.Detection_Type
                case 'Spectrometer'
                    obj.takeSpec.run(status,managers,ax(2)) % Run spectrum
                    spectrum = obj.takeSpec.GetData(managers.Stages,managers.Imaging);  % Get spectrum data
                    obj.data.spec_wavelength = spectrum.wavelength'; %
                    obj.data.spec_intensity(i,:) = spectrum.intensity;
                    scanH.CData(i,:) = spectrum.intensity;
                    title(ax(2),sprintf('Spectra %i of %i',i,length(rangeWL)));
                    drawnow
                case 'APD'
                    APD_counts = obj.counter.singleShot(obj.APD_dwell)*obj.APD_dwell/1000;
                    scanH.YData(i) = APD_counts;
                    obj.data.APD_counts(i) = APD_counts;
                    drawnow
            end
            
            obj.PM.set_wavelength(round(rangeWL(i))); % set powermeter wavelength
            for j =1:PWavg_num % Take power data
                try
                    PWall(i,j) = obj.PM.get_power('MW');
                catch err
                    warning(err.message)
                    PWall(i,j) = NaN;
                    continue
                end
            end
            obj.data.laser_power(i) = nanmean(PWall(i,:)); % Save average power measured
            obj.data.laser_power_all(i,:) = PWall(i,:); % Save average power measured
            obj.data.laser_wavelength(i) = Sources.TunableLaser_invisible.c/obj.resLaser.getFrequency; % Get exact wavelength from wavemeter
            
            obj.resLaser.off
        end
        obj.data.laser_setwavelength = rangeWL;
        obj.data.Detection_Type = obj.Detection_Type;
        
        % Edit this to include meta data for this experimental run (saved in obj.GetData)
        obj.meta.prefs = obj.prefs2struct;
        obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
    
        % EXPERIMENT CODE %
    catch err
        obj.resLaser.off
    end
    % CLEAN UP CODE %
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
