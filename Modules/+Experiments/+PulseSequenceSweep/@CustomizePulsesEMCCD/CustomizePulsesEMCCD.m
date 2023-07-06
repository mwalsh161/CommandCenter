classdef CustomizePulsesEMCCD < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %CustomizePulses measures the time dependence of the PLE signal

    properties(SetObservable,AbortSet)
        % Lasers
        resLaser = Modules.Source.empty(1,0); % Allow selection of laser source
        repumpLaser = Modules.Source.empty(1,0); % Allow selection of laser source
        
        % APD
        APDline = 4;            % will read the value from the gui 
        
        % Pulse durations
        repumpTime_us = 1;      % us, will read the value from the gui 
        resOffset_us = 1;       % will read the value from the gui 	
        resTime_us = 10;        % will read the value from the gui 
        
        % EMCCD
        cameraEMCCD = Modules.Imaging.empty(1,0);   % Allow selection of EMCCD
        EMCCD_binning = 1;      % will read the value from the gui 
        EMCCD_gain = 1200;      % will read the value from the gui 
        EMCCD_trigger_line = 1; % will read the value from the gui 
        
        sequenceduration = 0;   % NA
        cameraintegration = 0;  % NA
        %
    end
    
    properties % this is not related to the GUI
        placeHolderVariable = 1; %all APD bins are acquired in one shot, no variable is swept
        counterDuration = 0; %calculated in set.resTime_us
        tauTimes = 0; %calculated in set.resTime_us
    end
    
    properties(Constant)
        nCounterBins = 2; % number of APD bins for this pulse sequence (with more than 20 the PB errors)
        counterSpacing = 0.1; % spacing between APD bins
        vars = {'placeHolderVariable'}; %names of variables to be swept
    end
    
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = CustomizePulsesEMCCD()
            %additional preferences not in superclass
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser',...
                'cameraEMCCD','EMCCD_trigger_line','EMCCD_binning','EMCCD_gain',... %added prefs for PVCAM
                'APDline','repumpTime_us','resOffset_us','resTime_us'}];
            obj.loadPrefs;
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) %Defined in separate file
        
        function PreRun(obj,~,managers,ax)
%             %set EMCCD
%             obj.cameraEMCCD.binning = obj.EMCCD_binning;
%             obj.cameraEMCCD.EMgain = obj.EMCCD_gain;
%             
%             %obj.cameraEMCCD.load_external_trigger('C:\Program Files\Micro-Manager-2.0\Cascade1K.cfg');
%             maxframes = length(obj.tauTimes)*2;
%             obj.sequenceduration = (obj.repumpTime_us+obj.resOffset_us+max(obj.tauTimes)); %sequence duration in us
%             obj.cameraintegration = obj.sequenceduration*obj.samples*1e-3; %camera integration in ms 
%             obj.cameraEMCCD.exposure = obj.cameraintegration; %camera exposure time = sequence duration
%             obj.cameraEMCCD.startVideo();
        end
        
        function UpdateRun(obj,~,~,ax,~,~)
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.sumCounts,1))';
                meanError = squeeze(nanmean(obj.data.stdCounts,1))'*sqrt(obj.samples);
            else
                averagedData = obj.data.sumCounts;
                meanError = obj.data.stdCounts;
            end

            drawnow limitrate;
        end

        function PostRun(obj,~,~,ax)
            obj.cameraEMCCD.stopVideo(); 
        end
        
        function set.resTime_us(obj,val)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            obj.resTime_us = val;
            %obj.counterDuration = obj.resTime_us / obj.nCounterBins - obj.counterSpacing;
            %obj.tauTimes = linspace(0,obj.resTime_us-obj.counterDuration-obj.counterSpacing,obj.nCounterBins);
        end
    end
end
