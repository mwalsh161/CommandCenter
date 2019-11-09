classdef SpecSlowScan < Experiments.AutoExperiment.AutoExperiment_invisible
    %SpecSlowScan Automatically performs 1) spectra, 2) open-loop PLE, and
    %3) closed-loop PLE on identified sites

    properties(SetObservable,GetObservable)
        % Preferences for thresholding in the patch methods
        freq_range = Prefs.DoubleArray(299792./[635,640],'units','THz','min',0,'allow_nan',false);
        SpecCalExposure = Prefs.Double(0.1,'min',0,'units','sec');
        SpecPeakThresh = Prefs.Double(4,'min',0,'allow_nan',false,'help','Number of std above noise proms');
        PointsPerPeak = Prefs.Integer(10,'min',0,'allow_nan',false,'help','how many points per std for SlowScanClosed');
        StdsPerPeak = Prefs.Double(5,'min',0,'allow_nan',false,'help','how wide of a bin around peaks for SlowScanClosed');
        analysis_file = Prefs.File('filter_spec','*.mat','help','Used in patch functions instead of fitting last result. This also ignores SpecPeakThresh.',...
                                     'custom_validate','validate_file');
    end
    properties
        patch_functions = {'','Spec2Open','Open2Closed'};
        prerun_functions = {'PreSpec','PreSlow','PreSlow'};
        nm2THz = []; %this will be a function pulled from calibrating the spectrometer in the prerun method
        analysis = [];
    end
    methods(Access=private)
        function obj = SpecSlowScan()
            obj.experiments = [Experiments.Spectrum.instance,...
                                Experiments.SlowScan.Open.instance,...
                                Experiments.SlowScan.Closed.instance];
            obj.prefs = [{'freq_range','SpecPeakThresh','PointsPerPeak','StdsPerPeak','SpecCalExposure'},obj.prefs];
            obj.show_prefs = [{'freq_range','SpecPeakThresh','PointsPerPeak','StdsPerPeak','SpecCalExposure','analysis_file'},obj.show_prefs];
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
        varargout = analyze(data,varargin)
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
            % PreRun assures same resLaser for open/closed
            obj.experiments(2).resLaser.off;
            obj.experiments(2).repumpLaser.off;
            obj.imaging_source.on;
            obj.experiments(2).resLaser.SpecSafeMode(obj.freq_range);
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
        function params = Spec2Open(obj,site,index)
            params = struct('freq_THz',{}); %structure of params beings assigned
            if isempty(obj.analysis) || isnan(obj.analysis(index,1).index)
                % get all experiments named 'Spectrum' associated with site
                specs = site.experiments(strcmpi({site.experiments.name},'Experiments.Spectrum'));
                for i=1:length(specs)
                    spec = specs(i); %grab ith spectrum experiment
                    if ~spec(i).completed || spec(i).skipped
                        continue
                    end
                    x = spec.data.wavelength;
                    range = find(x>=min(299792./obj.freq_range) & x<=max(299792./obj.freq_range)); %clip to only range of interest
                    x = spec.data.wavelength(range);
                    y = spec.data.intensity(range);
                    specfit = fitpeaks(x,y,'fittype','gauss','AmplitudeSensitivity',obj.SpecPeakThresh); %fit spectrum peaks
                    for j=1:length(specfit.locations) %add a new parameter set for each peak found
                        params(end+1).freq_THz = obj.nm2THz(specfit.locations(j));
                    end
                end
            else
                for j = 1:length(obj.analysis(index,1).locations) %add a new parameter set for each peak found
                    % Ignore settings for SpecPeakThresh
                    params(end+1).freq_THz = obj.nm2THz(obj.analysis(index,1).locations(j));
                end
            end
        end
        function params = Open2Closed(obj,site,index)
            params = struct('freqs_THz',{}); %structure of params beings assigned
            composite.freqs = [];
            composite.counts = [];
            scanfit = []; % Make sure not a struct here for below if statement
            if isempty(obj.analysis) || isnan(obj.analysis(index,2).index) % NaN index means it wasn't checked
                % get all experiments named 'SlowScan_Open' associated with site
                scans = site.experiments(strcmpi({site.experiments.name},'Experiments.SlowScan.Open'));
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
                end
            else
                scanfit = obj.analysis(index,2); % Note this doesn't have fitpeaks' "SNRs" field, and widths all FWHM
            end
            if isstruct(scanfit)
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
            if ~isempty(obj.analysis)
                status.String = 'Checking analysis file'; drawnow;
                % We already checked size(...,2) in validate_file; at this
                % point there should be data loaded as well!
                n_analysis_sites = size(obj.analysis,1);
                n_data_sites = length(obj.data.sites);
                assert(n_analysis_sites==n_data_sites,...
                    sprintf('Found %i analysis entries, but %i sites. These should be equal.',...
                    	n_analysis_sites,n_data_sites));
                for i = 1:n_data_sites
                    for j = 1:3
                        assert(isnan(obj.analysis(i,j).index) || (obj.analysis(i,j).index == i),...
                            ['At least one analysis index does not reference its position (also corresponding to data position). ',...
                            'This is currently not supported and likely means the "inds" option was used in the analysis method.']);
                    end
                end
            end
            %before running, calibrate spectrometer and check resLaser
            status.String = 'Checking spectrometer and resLaser'; drawnow;
            specH = obj.experiments(1).WinSpec;
            laserH = obj.experiments(2).resLaser;
            assert(~isempty(laserH),'No laser selected for SlowScan experiment(s)!');
            assert(isequal(laserH,obj.experiments(3).resLaser),...
                'Currently, SpecSlowScan only supports using the same resLaser for SlowScan.Open and SlowScan.Closed.');
            laserH.arm; % Go through arming now to make sure things are set at the beginning (e.g. calibration if it exists)
            managers.Path.select_path('spectrometer'); %this may be unnecessary
            calibration = specH.calibration(laserH,obj.freq_range,obj.SpecCalExposure,ax);
            obj.nm2THz = calibration.nm2THz; %grab the calibration function
            obj.meta.nm2THz = obj.nm2THz; % And add to metadata
            obj.meta.analysis = obj.analysis; % To avoid scenarios where analysis gets renamed/deleted
            
            % Set SlowScan.Open to always use Tune Coarse
            obj.experiments(2).tune_coarse = true;
        end
        
        function validate_file(obj,val,~)
            % We will validate and set the analysis prop here
            if ~isempty(val)
                flag = exist(val,'file');
                if flag == 0
                    error('Could not find "%s"!',val)
                end
                if flag ~= 2
                    error('File "%s" must be a mat file!',val)
                end
                dat = load(val);
                names = fieldnames(dat);
                if length(names) ~= 1
                    error('Loaded mat file should have a single variable; found\n%s',strjoin(names,', '));
                end
                if ~isstruct(dat.(names{1})) || size(dat.(names{1}),2) ~= 3
                    error('Loaded variable from file should be an Nx3 struct.');
                end
                obj.analysis = dat.(names{1});
            else
                obj.analysis = [];
            end
        end
    end
end
