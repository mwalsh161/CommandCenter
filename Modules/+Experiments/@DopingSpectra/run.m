function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    
    obj.data.spec_intensity = [];
    
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
    
    
    obj.KeithleyBG.outputOn();
    obj.KeithleyTip.outputOn();   
    setVoltageGently(obj.KeithleyBG, rangeBG(1), 0.1);
    setVoltageGently(obj.KeithleyTip, rangeTip(1), 0.1);
    pause(5)
    
    for i = 1:length(rangeBG)
        
        assert(~obj.abort_request,'User aborted.');
        %obj.KeithleyBG.setOutputVoltage(rangeBG(i));
        setVoltageGently(obj.KeithleyBG, rangeBG(i), 0.1);
        
        setVoltageGently(obj.KeithleyTip, rangeTip(1), 0.1);
        pause(5)
        
        for j = 1:length(rangeTip)
            
            assert(~obj.abort_request,'User aborted.');
            %obj.KeithleyTip.setOutputVoltage(rangeTip(j));
            setVoltageGently(obj.KeithleyTip, rangeTip(j), 0.1);
            pause(1)
            
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
            obj.data.spec_intensity_header = ["Backgate Voltage", "Tip Voltage", "Spectrum"];
        case 'APD'
            obj.data.APD_counts = scanH.CData;
            obj.data.APD_dwelltime = obj.APD_dwell;
            obj.data.APD_counts_header = ["Backgate Voltage", "Tip Voltage"];
    end
    
    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
    
    setVoltageGently(obj.KeithleyBG, 0, 0.1);
    setVoltageGently(obj.KeithleyTip, 0, 0.1);
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

function setVoltageGently(keithley,targetVoltage,stepSize)
    startVoltage = keithley.readOutputVoltage();
    if startVoltage > targetVoltage
        stepSize = stepSize*-1;
    end
    for V = startVoltage:stepSize:targetVoltage
        keithley.setOutputVoltage(V);
        pause(0.1);
    end
    keithley.setOutputVoltage(targetVoltage)
end