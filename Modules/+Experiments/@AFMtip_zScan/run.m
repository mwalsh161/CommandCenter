function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    
    obj.data.spec_intensity = [];
    
    % init zPositions
    zRange = eval(obj.zRange);
    obj.data.zRange = zRange;
    startPos = obj.ANC.get_offset_voltage(1);
    zPositions = startPos - zRange;
    obj.data.zPositonVoltages = zPositions;
    
    % init Keithleys
    BG = obj.BGVoltage;
    obj.data.BackgateVoltage = BG;
    rangeTip = eval(obj.TipVoltageRange);
    obj.data.TipVoltages = rangeTip;
    obj.KeithleyBG.outputOn();
    obj.KeithleyTip.outputOn();   
    setVoltageGently(obj.KeithleyBG, BG), 0.2);
    setVoltageGently(obj.KeithleyTip, rangeTip(1), 0.2);
    pause(1);
    
    % Init Detection 
    switch obj.Detection_Type
        case 'Spectrometer'
            panel = ax.Parent; delete(ax); % For spectrometer detection, we need two axes for plotting
            ax(1) = subplot(2,1,1,'parent',panel);
            ax(2) = subplot(2,1,2,'parent',panel);
            obj.takeSpec.run(status,managers,ax(2)) % Take Dummy Spectra to get spectrometer pixel number
            spectrum = obj.takeSpec.GetData(managers.Stages,managers.Imaging);
            scanH = imagesc(ax(1),spectrum.wavelength,zPositions,NaN(length(zPositions),length(spectrum.wavelength))); % ,'parent',managers.handles.axImage
            set(ax(1),'ydir','normal');
            title(ax(1),sprintf('Plot for Tip Voltage %.2f V', rangeTip(1)));
            ylabel(ax(1),'Tip Position (V)');
            xlabel(ax(1),'Wavelength (nm)');
        case 'APD'
            scanH = imagesc(ax,rangeTip,rangeBG,NaN(length(zPositions),length(rangeTip)));
            ylabel(ax(1),'Tip Position (V)');
            xlabel(ax(1),'Tip Voltage (V)');
    end
    
    % start zScan
    for i = 1:length(zPositions)
        assert(~obj.abort_request,'User aborted.');
        
        % move AFM tip
        obj.ANC.set_offset_voltage(1, zPositions(i));
        pause(2);
        
        % take spec
        for j = 1:length(rangeTip)
            
            assert(~obj.abort_request,'User aborted.');
            setVoltageGently(obj.KeithleyTip, rangeTip(j), 0.2);
            pause(1)
            
            switch obj.Detection_Type
                case 'Spectrometer'
                    obj.takeSpec.run(status,managers,ax(2)) % Run spectrum
                    spectrum = obj.takeSpec.GetData(managers.Stages,managers.Imaging);  % Get spectrum data
                    obj.data.spec_intensity(i,j,:) = spectrum.intensity;
                    obj.data.spec_wavelength = spectrum.wavelength;
                    title(ax(2),sprintf('Spectra %i of %i. zPos %.2f V, Tip %.2f V, Backgate %.2f V.',(i-1)*length(zPositions)+j,length(rangeTip)*length(zPositions),zPositions(i),rangeTip(j),BG));
                    if j == 1
                        scanH.CData(i,:) = spectrum.intensity;
                    end
                    drawnow;
                    
                case 'APD'
                    APD_counts = obj.counter.singleShot(obj.APD_dwell)*obj.APD_dwell/1000;
                    scanH.CData(i,j) = APD_counts;
                    drawnow;
            end
        end
        
    end
    
    setVoltageGently(obj.KeithleyBG, 0, 0.2);
    setVoltageGently(obj.KeithleyTip, 0, 0.2);
    obj.KeithleyBG.outputOff();
    obj.KeithleyTip.outputOff();

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);

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
    for V = startVoltage:stepSize:targetVoltage
        keithley.setOutputVoltage(V);
        pause(0.2);
    end
    keithley.setOutputVoltage(targetVoltage)
end