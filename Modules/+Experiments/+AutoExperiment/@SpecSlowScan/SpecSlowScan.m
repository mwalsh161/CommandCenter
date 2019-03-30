classdef SpecSlowScan < Experiments.AutoExperiment.AutoExperiment_invisible
    %SpecSlowScan Automatically performs 1) spectra, 2) open-loop PLE, and
    %3) closed-loop PLE on identified sites

    properties(SetObservable,AbortSet)
        % Preferences for thresholding in the patch methods
        freq_range = 299792./[635,640];
        SpecCalExposure = 0.1;
        SpecPeakThresh = 4; %SNR threshold for spectral peak detection
        PointsPerPeak = 10; %how many points per std for SlowScanClosed
        StdsPerPeak = 5; %how wide of a bin around peaks for SlowScanClosed
    end
    properties
        patch_functions = {'','Spec2Open','Open2Closed'};
        prerun_functions = {'PreSpec','PreSlow','PreSlow'};
        nm2THz = []; %this will be a function pulled from calibrating the spectrometer in the prerun method
    end
    methods(Access=private)
        function obj = SpecSlowScan()
            obj.experiments = [Experiments.Spectrum.instance,...
                                Experiments.SlowScan.Open.instance,...
                                Experiments.SlowScan.Closed.instance];
            obj.prefs = [{'freq_range','SpecPeakThresh','PointsPerPeak','StdsPerPeak'},obj.prefs];
            obj.show_prefs = [{'freq_range','SpecCalExposure','SpecPeakThresh','PointsPerPeak','StdsPerPeak'},obj.show_prefs];
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance(varargin)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Experiments.AutoExperiment.SpecSlowScan.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(varargin,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Experiments.AutoExperiment.SpecSlowScan(varargin{:});
            obj.singleton_id = varargin;
            Objects(end+1) = obj;
        end
        
        regions = peakRegionBin(peaks,wids,ppp,scanDevs,maxRange)
        function [dx,dy,dz,metric] = Track(Imaging,Stage,track_thresh) 
            % Imaging = handle to active imaging module
            % Stage = handle to active stage module
            % track_thresh = true --> force track
            %                false --> return metric, but don't track
            %                numeric --> if metric <= track_thresh, track
            
            tracker = Drivers.Tracker.instance(Stage,Stage.galvoDriver);
            dx = NaN;
            dy = NaN;
            dz = NaN;
            metric = NaN;
            try
                counter = Drivers.Counter.instance('APD1','APDgate');
                try
                    metric = counter.singleShot(tracker.dwell);
                catch err
                    counter.delete
                    rethrow(err)
                end
                counter.delete
                if (islogical(track_thresh) && track_thresh) || (~islogical(track_thresh) && metric < track_thresh)
                    currPosition = Stage.position;
                    tracker.Track(false);
                    newPosition = Stage.position;
                    delta = newPosition-currPosition;
                    dx = delta(1);
                    dy = delta(2);
                    dz = delta(3);
                end
            catch err
                tracker.delete;
                rethrow(err)
            end
            tracker.delete;
        end
    end
    methods
        % the below pre-run functions will run immediately before the run
        % method of the corresponding experiment each time it is called
        function PreSpec(obj,spec_experiment)
            % Can't assume these are the same lasers for exp 2 and 3
            obj.experiments(2).resLaser.off;
            obj.experiments(3).resLaser.off;
            obj.experiments(2).repumpLaser.off;
            obj.experiments(3).repumpLaser.off;
            obj.imaging_source.on;
            obj.experiments(2).resLaser.SpecSafeMode(obj.freq_range);
            obj.experiments(3).resLaser.SpecSafeMode(obj.freq_range);
        end
        function PreSlow(obj,slow_experiment)
            % turn off spectrometer laser before PLE
            obj.imaging_source.off;
            slow_experiment.resLaser.arm;
        end
        %the below patch functions will be run at the beginning of each
        %(site, experiment) in the run_queue for any experiment that isn't
        %the first one, and will be passed the relevant emitter site 
        %(containing) all previous experiments.
        function params = Spec2Open(obj,site)
            params = struct('freq_THz',{}); %structure of params beings assigned
            specs = site.experiments(strcmpi({site.experiments.name},'Experiments.Spectrum')); %get all experiments named 'Spectrum' associated with site
            for i=1:length(specs)
                spec = specs(i); %grab ith spectrum experiment
                if ~spec(i).completed || spec(i).skipped
                    continue
                end
                x = spec.data.wavelength;
                range = find(x>=min(299792./obj.freq_range) & x<=max(299792./obj.freq_range)); %clip to only range of interest
                x = spec.data.wavelength(range);
                y = spec.data.intensity(range);
                specfit = fitpeaks(x,y,'fittype','gauss','NoiseModel','empirical','StopMetric','r'); %fit spectrum peaks (non calibrated camera; empirical noise)
                for j=1:length(specfit.locations)
                    if specfit.SNRs(j)>=obj.SpecPeakThresh
                        params(end+1).freq_THz = obj.nm2THz(specfit.locations(j)); %add a new parameter set for each peak found
                    end
                end
            end
        end
        function params = Open2Closed(obj,site)
            params = struct('freqs_THz',{}); %structure of params beings assigned
            scans = site.experiments(strcmpi({site.experiments.name},'Experiments.SlowScan.Open')); %get all experiments named 'SlowScan_Open' associated with site
            composite.freqs = [];
            composite.counts = [];
            for i=1:length(scans) %compile all scans
                if scans(i).completed && ~scans(i).skipped
                    composite.freqs = [composite.freqs, scans(i).data.data.freqs_measured];
                    composite.counts = [composite.counts, scans(i).data.data.sumCounts];
                end
            end
            if ~isempty(composite.counts) %if no data, return empty struct from above
                [composite.freqs,I] = sort(composite.freqs); %sort in ascending order
                composite.counts = composite.counts(I);
                scanfit = fitpeaks(composite.freqs',composite.counts','fittype','gauss','NoiseModel','shot'); % Literally photon counts; shot noise
                scanfit.widths = scanfit.widths*2*sqrt(2*log(2)); % sigma to FWHM
                regions = Experiments.AutoExperiment.SpecSlowScan.peakRegionBin(scanfit.locations,scanfit.widths,obj.PointsPerPeak,obj.StdsPerPeak); %bin into regions with no max size
                for i=1:length(regions)
                    % Inverse of what is used in set.freqs_THz (faster than jsonencode by 2x).
                    % Same precision as wavemeter driver: 0.1 MHz
                    vals = num2str(regions{i},'%0.7f ');
                    test = str2num(vals); %#ok<ST2NM> % Truncated precision
                    vals = num2str(unique(test),'%0.7f '); % Remove duplicates caused by truncated precision
                    if length(test)~=length(regions{i})
                        warning('7 digit precision in freqs_THz caused removal of duplicate points');
                    end
                    params(end+1).freqs_THz = vals;
                end
            end
        end
        function sites = AcquireSites(obj,managers)
            sites = Experiments.AutoExperiment.AutoExperiment_invisible.SiteFinder_Confocal(managers,obj.imaging_source,obj.site_selection);
        end
        function PreRun(obj,status,managers,ax)
            %before running, calibrate spectrometer
            specH = obj.experiments(1).WinSpec;
            laserH = obj.experiments(2).resLaser;
            managers.Path.select_path('spectrometer'); %this may be unnecessary
            calibration = specH.calibration(laserH,obj.freq_range,obj.SpecCalExposure,ax);
            obj.nm2THz = calibration.nm2THz; %grab the calibration function
            
            %set SlowScan Open to always use Tune Coarse
            obj.experiments(2).tune_coarse = true;
        end
    end
end
