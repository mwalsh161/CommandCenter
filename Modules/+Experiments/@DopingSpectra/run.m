function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    
    rangeBG = eval(obj.BGVoltageRange);
    obj.data.BackgateVoltages = rangeBG;
    rangeTip = eval(obj.TipVoltageRange);
    obj.data.TipVoltages = rangeTip;
    
    switch obj.Detection_Type
        case 'Spectrometer'
            panel = ax.Parent; delete(ax); % For spectrometer detection, we need two axes for plotting
            ax(1) = subplot(2,1,1,'parent',panel);
            ax(2) = subplot(2,1,2,'parent',panel);
            obj.takeSpec.run(status,managers,ax(2)) % Take Dummy Spectra to get spectrometer pixel number
            spectrum = obj.takeSpec.GetData(managers.Stages,managers.Imaging);
            scanH = imagesc(ax(1),spectrum.wavelength,rangeTip,NaN(length(rangeTip),length(spectrum.wavelength))); % ,'parent',managers.handles.axImage
            set(ax(1),'ydir','normal');
            ylabel(ax(1),'Tip Voltage (V)')
            xlabel(ax(1),'Wavelength (nm)')
        case 'APD'
            scanH = imagesc(ax,rangeTip,rangeBG,NaN(length(rangeTip),length(rangeBG)));
            xlabel(ax,'Tip Voltage (V)')
            ylabel(ax,'Backgate Voltage (V)')
    end
    
    
    obj.KeithleyBG.setOutputVoltage(0);
    obj.KeithleyTip.setOutputVoltage(0);
    obj.KeithleyBG.outputOn();
    obj.KeithleyTip.outputOn();
    pause(0.2)
    
    for i = 1:length(rangeBG)
        
        assert(~obj.abort_request,'User aborted.');
        obj.KeithleyBG.setOutputVoltage(rangeBG(i));
        pause(0.2)
        
        for j = 1:length(rangeTip)
            
            assert(~obj.abort_request,'User aborted.');
            obj.KeithleyTip.setOutputVoltage(rangeTip(j));
            pause(0.2)
            
            switch obj.Detection_Type
                case 'Spectrometer'
                    obj.takeSpec.run(status,managers,ax(2)) % Run spectrum
                    spectrum = obj.takeSpec.GetData(managers.Stages,managers.Imaging);  % Get spectrum data
                    obj.data.spec_intensity(i,j,:) = spectrum.intensity;
                    if j == 1
                        title(ax(1),sprintf('Backgate Voltage (V) %.2f', rangeBG(i)));
                        scanH.CData = NaN(length(rangeTip),length(spectrum.wavelength)) ;
                    end
                    scanH.CData(j,:) = spectrum.intensity;
                    title(ax(2),sprintf('Spectra %i of %i. Tip %.2f V, Backgate %.2f V.',(i-1)*length(rangeTip)+j,length(rangeBG)*length(rangeTip),rangeTip(j),rangeBG(i)));
                    drawnow
                case 'APD'
                    APD_counts = obj.counter.singleShot(obj.APD_dwell)*obj.APD_dwell/1000;
                    scanH.CData(i,j) = APD_counts;
                    drawnow
            end
        end
    end
    
    switch obj.Detection_Type
        case 'Spectrometer'
            obj.data.spec_wavelength = spectrum.wavelength;
        case 'APD'
            obj.data.APD_counts = scanH.CData;
            obj.data.APD_dwelltime = obj.APD_dwell; 
    end
    obj.data.BGVoltages = rangeBG;
    obj.data.TipVoltages = rangeTip;
    
    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
    
    obj.KeithleyBG.setOutputVoltage(0);
    obj.KeithleyTip.setOutputVoltage(0);
    obj.KeithleyBG.outputOff();
    obj.KeithleyTip.outputOff();
    
    try
        % EXPERIMENT CODE %
    catch err
    end
    % CLEAN UP CODE %
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
