classdef SpecSlowScan < Experiments.AutoExperiment.AutoExperiment_invisible
    %SpecSlowScan Automatically performs 1) spectra, 2) open-loop PLE,
    %3) closed-loop PLE 4) and SuperRes on identified sites
    % The analysis struct can be extended to include "nm2THz" as well as the
    % corresponding "gof" (both as separate fields).
    % The sites struct has been expanded to have fit information for each
    % peak and if exists, is used instead of re-fitting in situ.

    properties(SetObservable,GetObservable)
        % Preferences for thresholding in the patch methods
        freq_range = Prefs.DoubleArray(299792./[635,640],'units','THz','min',0,'allow_nan',false);
        SpecCalExposure = Prefs.Double(0.1,'min',0,'units','sec');
        SpecPeakThresh = Prefs.Double(4,'min',0,'allow_nan',false,'help_text','Number of std above noise proms');
        PointsPerPeak = Prefs.Integer(10,'min',0,'allow_nan',false,'help_text','how many points per std for SlowScanClosed');
        StdsPerPeak = Prefs.Double(5,'min',0,'allow_nan',false,'help_text','how wide of a bin around peaks for SlowScanClosed');
        ROI_Size = Prefs.Double(2,'units','um','allow_nan',false,'help_text','Symmetric box size (width and height) for super res scans around emitter');
        ROI_points = Prefs.Integer(50,'units','px','allow_nan',false,'help_text','Symmetric pixel count (width and height) for super res scans. Will determine resolution.')
    end
    properties
        patch_functions = {'','Spec2Open','Open2Closed','Closed2SuperRes'};
        prerun_functions = {'PreSpec','PreSlow','PreSlow','PreSuperRes'};
        nm2THz = []; %this will be a function pulled from calibrating the spectrometer in the prerun method
    end
    methods(Access=private)
        function obj = SpecSlowScan()
            obj.experiments = [Experiments.Spectrum.instance,...
                               Experiments.SlowScan.Open.instance,...
                               Experiments.SlowScan.Closed.instance,...
                               Experiments.SuperResScan.instance];
            obj.prefs = [{'freq_range','ROI_Size','ROI_points','SpecPeakThresh','PointsPerPeak','StdsPerPeak','SpecCalExposure'},obj.prefs];
            obj.show_prefs = [{'freq_range','ROI_Size','ROI_points','SpecPeakThresh','PointsPerPeak','StdsPerPeak','SpecCalExposure'},obj.show_prefs];
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
        [n2THz,gof,fig] = diagnostic(data,sites)
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
        function PreSpec(obj,~)
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
        function PreSuperRes(obj,superresexp)
            obj.imaging_source.off;
        end
        %the below patch functions will be run at the beginning of each
        %(site, experiment) in the run_queue for any experiment that isn't
        %the first one, and will be passed the relevant emitter site
        %(containing) all previous experiments.
        function params = Spec2Open(obj,site,index)
            params = struct('freq_THz',{}); %structure of params beings assigned
            if isempty(obj.analysis) || isnan(obj.analysis.sites(index,1).index)
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
                for j = 1:length(obj.analysis.sites(index,1).locations) %add a new parameter set for each peak found
                    % Ignore settings for SpecPeakThresh
                    params(end+1).freq_THz = obj.nm2THz(obj.analysis.sites(index,1).locations(j));
                end
            end
        end
        function params = Open2Closed(obj,site,index)
            params = struct('freqs_THz',{}); %structure of params beings assigned
            composite.freqs = [];
            composite.counts = [];
            scanfit = []; % Make sure not a struct here for below if statement
            if isempty(obj.analysis) || isnan(obj.analysis.sites(index,2).index) % NaN index means it wasn't checked
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
                scanfit = obj.analysis.sites(index,2); % Note this doesn't have fitpeaks' "SNRs" field, and widths all FWHM
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
        function params = Closed2SuperRes(obj,site,index)
            params = struct('x_points',[],'y_points',[],'frequency',{}); %structure of params beings assigned
            composite.freqs = [];
            composite.counts = [];
            scanfit = []; % Make sure not a struct here for below if statement
            if isempty(obj.analysis) || isnan(obj.analysis.sites(index,3).index) % NaN index means it wasn't checked
                % get all experiments named 'SlowScan_Closed' associated with site
                scans = site.experiments(strcmpi({site.experiments.name},'Experiments.SlowScan.Closed'));
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
                scanfit = obj.analysis.sites(index,3);
            end
            pos = site.position;
            if isstruct(scanfit)
                for i = 1:length(scanfit.locations)
                    params(end+1).x_points = sprintf('%g+linspace(-0.5*%g,0.5*%g,%g)',pos(1),obj.ROI_Size,obj.ROI_Size,obj.ROI_points);
                    params(end).y_points = sprintf('%g+linspace(-0.5*%g,0.5*%g,%g)',pos(2),obj.ROI_Size,obj.ROI_Size,obj.ROI_points);
                    params(end).frequency = scanfit.locations(i);
                end
            end
        end
        function sites = AcquireSites(obj,managers)
            sites = Experiments.AutoExperiment.AutoExperiment_invisible.SiteFinder_Confocal(managers,obj.imaging_source,obj.site_selection);
        end
        function validate_analysis(obj)
            for i = 1:size(obj.analysis.sites,1)
                for j = 1:3 % The 3 is for n experiments, which was validated in superclass
                    assert(isnan(obj.analysis.sites(i,j).index) || (obj.analysis.sites(i,j).index == i),...
                        ['At least one analysis index does not reference its position (also corresponding to data position). ',...
                        'This is currently not supported and likely means the "inds" option was used in the analysis method.']);
                end
            end
        end
        function PreRun(obj,status,managers,ax)
            %before running, calibrate spectrometer and check resLaser
            status.String = 'Checking spectrometer and resLaser'; drawnow;
            assert(~isempty(obj.experiments(2).repumpLaser),'SlowScan.Open needs a repump laser defined!');
            assert(~isempty(obj.experiments(3).repumpLaser),'SlowScan.Closed needs a repump laser defined!');
            assert(~isempty(obj.experiments(4).repumpLaser),'SuperResScan needs a repump laser defined!');
            assert(~isempty(obj.experiments(2).resLaser),'SlowScan.Open needs a resonant laser defined!');
            assert(~isempty(obj.experiments(3).resLaser),'SlowScan.Closed needs a resonant laser defined!');
            assert(~isempty(obj.experiments(4).resLaser),'SuperResScan needs a resonant laser defined!');
            % Double check user is cool with SuperResScan using active stage (if more than one loaded)
            if length(managers.Stages.modules) > 1
                answer = questdlg(sprintf('Multiple stages loaded: the active stage, "%s", will be used for SuperResScan. Is this ok?',...
                    class(managers.Stages.active_module)),'SuperResScan Stage','Yes','No','Yes');
                if ~strcmp(answer,'Yes') % Clicking no or exiting box
                    error('Choose active stage you would like to use, and restart.')
                end
            end
            specH = obj.experiments(1).WinSpec;
            laserH = obj.experiments(2).resLaser;
            assert(isequal(laserH,obj.experiments(3).resLaser)&&isequal(laserH,obj.experiments(4).resLaser),...
                'Currently, SpecSlowScan only supports using the same resLaser for all experiments.');
            laserH.arm; % Go through arming now to make sure things are set at the beginning (e.g. calibration if it exists)
            managers.Path.select_path('spectrometer'); %this may be unnecessary
            if ~isempty(obj.analysis) && isfield(obj.analysis,'nm2THz') && ~isempty(obj.analysis.nm2THz)
                answer = questdlg('Found nm2THz calibration in the analysis; would you like to update winspec with this?','WinSpec Calibration','Yes','No','Yes');
                assert(~isempty(answer), 'User aborted.')
                if strcmp(answer,'Yes')
                    assert(isfield(obj.analysis,'gof'),'If attempting to set nm2THz, gof must also be a field in analysis.')
                    specH.set_calibration(obj.analysis.nm2THz, obj.analysis.gof);
                end
            end
            calibration = specH.calibration(laserH,obj.freq_range,obj.SpecCalExposure,ax);
            obj.nm2THz = calibration.nm2THz; %grab the calibration function
            obj.meta.nm2THz = obj.nm2THz; % And add to metadata
            obj.meta.analysis = obj.analysis; % To avoid scenarios where analysis gets renamed/deleted

            % Set SlowScan.Open to always use Tune Coarse
            obj.experiments(2).tune_coarse = true;
        end

    end
end
