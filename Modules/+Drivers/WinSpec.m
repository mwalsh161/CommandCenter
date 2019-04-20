classdef WinSpec < Modules.Driver
    %WINSPEC Sets up platform for data transfer to winspec.
    %   Make sure server is setup on spectrometer.  Authentication takes
    %   place on server side. Client must be registered in diamondbase
    %   (IPtracker) for authentication
    %
    %   Removed WinSpec's concept of background file. Implement client
    %   side experiment if necessary.
    %
    %   Every action (except acquire) is blocking on server side. This
    %   means changing gratings will render matlab inactive until complete
    %   or connection fails.

    properties(SetAccess=?Base.Module,SetObservable, AbortSet)
        % Used for monitoring only (use methods to change)
        % Base.Module needs permission for getPrefs;
        grating = 1;          % Grating number (index into gratings_avail)
        position = 637;       % Grating position
        exposure = 1;         % Seconds
        running = false;
    end
    properties(SetAccess=private)
        gratings_avail = {}; % Populated on setup
    end
    properties(Hidden)
        prefs = {'grating','position','exposure','cal_local'};
    end
    properties(SetAccess={?Base.Module},Hidden)
        cal_local = struct('nm2THz',[],'gof',[],'datetime',[],'source',[],'expired',{}); %local-only calibration data for going from nm to THz
    end
    properties(SetAccess=private,Hidden)
        connection
        abort_requested = false;
    end
    properties(Constant,Hidden)
        calibration_timeout = 7; %duration in days after which Spectrum will give warning to recalibrate
        c = 299792; %speed of light in nm*THz
    end
    methods(Static)
        function obj = instance(ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.WinSpec.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(resolvedIP,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.WinSpec(ip);
            obj.singleton_id = resolvedIP;
            Objects(end+1) = obj;
        end
    end
    methods(Access=protected)
        function obj = WinSpec(ip)
            obj.grating = uint8(1); % Default
            % Build TCP connection
            obj.connection = tcpip(ip,36577,'OutputBufferSize',1024,'InputBufferSize',1024);
            obj.connection.Timeout = 10;
            obj.connection.Terminator = 'LF';
            obj.loadPrefs;
            % Verify current state
            obj.setup();
            [N,pos,exp] = obj.getInstrParams();
            changed = {};
            if N ~= obj.grating
                changed{end+1} = sprintf('grating (%i -> %i)',obj.grating,N);
                obj.grating = N;
            end
            if pos ~= obj.position
                changed{end+1} = sprintf('spectrograph position (%0.2f nm -> %0.2f nm)',...
                    obj.position,pos);
                obj.position = pos;
            end
            if exp ~= obj.exposure
                changed{end+1} = sprintf('spectrograph exposure (%0.3f sec -> %0.3f sec)',...
                    obj.exposure,exp);
                obj.exposure = exp;
            end
            if ~isempty(changed)
                w = sprintf('Following parameters have changed since last time:\n  %s',...
                    strjoin(changed,[newline '  ']));
                warndlg(w,mfilename);
            end
        end
        function response = com(obj,funcname,varargin)
            % Last argument can be optional function handle
            callback = [];
            if ~isempty(varargin) && isa(varargin{end},'function_handle')
                callback = varargin{end};
                varargin(end) = [];
            end
            % Server always replies and always closes connection after msg
            % assert funcname is a string, and cast varargin (cell array)
            % to strings (use cellfun - operates on each entry of cell)
            msg.function = funcname;
            msg.args = varargin;
            msg = jsonencode(msg);
            assert(~strcmp(obj.connection.Status,'open'),[mfilename ' connection left open. Please close and retry.']);
            fopen(obj.connection);
            err = [];
            try
                msg = [urlencode(msg) newline];
                buffsz = obj.connection.OutputBufferSize;
                for i = 1:ceil(length(msg)/buffsz)
                    fprintf(obj.connection,'%s',msg(buffsz*(i-1)+1:min(end,buffsz*i)));
                end
                response = '';
                tStart = tic; % For callback
                while true
                    assert(toc(tStart) <= obj.connection.Timeout,'Connection timed out.')
                    if obj.connection.BytesAvailable
                        [partial,~,msg] = fscanf(obj.connection);
                        response = [response partial]; %#ok<AGROW>
                        if isempty(msg)
                            break
                        elseif ~startswith(msg,'The input buffer was filled before the Terminator was reached.')
                            warning(msg)
                        end
                    end
                    if ~isempty(callback)
                        callback(toc(tStart));
                    end
                end
                response = urldecode(strip(response));  % Decode
                response = jsondecode(response);
                % server does not keep connection open, and doing so client
                % side will result in error on next connection.
            catch err
            end
            fclose(obj.connection);
            if ~isempty(err); rethrow(err); end
            % If, because assert always evaluates error arg; response.resp not always string (unless error)
            if ~response.success
                error(['serverside error: ' response.resp])
            end
            response = response.resp;
        end
    end
    methods
        function delete(obj)
            if ~isempty(obj.connection)
                if strcmp(obj.connection.status,'open')
                    fclose(obj.connection);
                end
                delete(obj.connection);
            end
        end
        function exposure_set = find_exposure(obj,MaxExposure,varargin)
            % Find exposure that sets max pixel to intensity percentage
            % max_exposure: exposure value to not exceed
            % Optional inputs are arg,val pairs
            % [p] default 0.5, percentage of max intensity to get
            % the max pixel value to
            p = inputParser;
            addRequired(p,'MaxExposure',@isnumeric);
            addParameter(p,'p',0.5,@isnumeric);
            addParameter(p,'ax',gca,@(a)isa(a,'matlab.graphics.axis.Axes')&&isvalid(a));
            parse(p,MaxExposure,varargin{:});
            p = p.Results;
            
            max_intensity = 2^16-1;
            target_intensity = max_intensity*p.p;
            % First, try smallest exposure to make sure there is a chance
            exposure_set = 0;
            y = get_val(exposure_set);
            assert(y < max_intensity,'Smallest exposure still overexposed');
            if y >= target_intensity
                return
            end
            bounds = [0 p.MaxExposure];
            for i = 1:10 % Min step size is then roughly 1/2^10 (0.9%)
                exposure_set = mean(bounds);
                y = get_val(exposure_set);
                if y >= target_intensity && y < max_intensity
                    return
                elseif y < target_intensity
                    bounds(1) = exposure_set; % Increase lower bound
                elseif y >= max_intensity
                    bounds(2) = exposure_set; % Decrease upper bound
                end
            end
            error('Failed to reach target intensity within 10 steps.')
            function y = get_val(exp)
                obj.setExposure(exp);
                sp = obj.acquire([],true); % Will do our own test
                y = max(sp.y);
                plt = plot(p.ax,sp.x,sp.y);
                legend(plt,{sprintf('%g seconds',exp)});
            end
        end
        function sp = acquire(obj,updateFcn,over_exposed_override)
            % [optional] Calls updateFcn with the only input as the elapsed time
            % [optional] over_exposed_override will supress server's
            %   overexposed error (default is not to supress)
            if nargin < 2
                updateFcn = [];
            else
                assert(isempty(updateFcn)||isa(updateFcn,'function_handle'),'"updateFcn" callback must be a function handle');
            end
            if nargin < 3
                over_exposed_override = false;
            end
            obj.running = true;
            obj.abort_requested = false;
            lastTimeout= obj.connection.Timeout;
            obj.connection.Timeout = lastTimeout + obj.exposure;
            function acquire_callback(t)
                assert(~obj.abort_requested,'User Aborted')
                if ~isempty(updateFcn); updateFcn(t); end
                drawnow; % Flush callback queue
            end
            try
                sp = obj.com('acquire',over_exposed_override,@acquire_callback);
            catch err
                if strcmp(err.message,'Connection timed out.')
                    obj.setExposure(obj.exposure);
                    error('%s\n%s\n->%s','Connection timed out: retry acquire',...
                        'possibly due to someone updating server exposure directly, took following actions:',...
                        strjoin({'Aborting any current acquisition.','Resetting exposure'},'\n->'));  % Server handles abort upon client disconnect
                end
                obj.running = false;
                obj.connection.Timeout = lastTimeout;
                rethrow(err)
            end
            obj.connection.Timeout = lastTimeout;
            obj.running = false;
            %create wavelength axis from calibration polynomial and store a .x column
            x = sp.ROI(2):sp.ROI(4);
            sp.x=(sp.CAL_COEFFS(1)+...
                sp.CAL_COEFFS(2)*x+...
                sp.CAL_COEFFS(3)*x.^2+...
                sp.CAL_COEFFS(4)*x.^3+...
                sp.CAL_COEFFS(5)*x.^4)';
            if abs(sp.EXPOSEC - obj.exposure) > 0.0001
                warning('Exposure changed from expected value!')
            end
            if abs(sp.GRAT_NUM - obj.grating) > 0.0001
                warning('Grating changed from expected value!')
            end
        end
        function abort(obj)
            % Can only abort in acquisition; this is now done by client
            % disconnect
            obj.abort_requested = true;
        end
        % Set Functions
        function setup(obj)
            % This sets basic file handling: overwrite, autosave, no BG
            % file etc.
            out = obj.com('setup');
            obj.gratings_avail = out.gratings;
        end
        function setGrating(obj,N,pos)
            % If N/pos empty, will use last setting (still require all args
            % in call though)
            if isempty(N)
                N = obj.grating;
            end
            if isempty(pos)
                pos = obj.position;
            end
            assert(isnumeric(N),'Grating index should be numeric.')
            assert(isnumeric(pos),'Grating position should be numeric.')
            timeout = obj.connection.Timeout;
            obj.connection.Timeout = 60*2; % Changing grating takes quite some time
            obj.com('grating',N,pos);
            obj.connection.Timeout = timeout;
            % Abortset should make this reasonable overhead
            obj.grating = N;
            obj.position = pos;
        end
        function setExposure(obj,exp)
            assert(isnumeric(exp),'Exposure should be numeric.')
            obj.com('exposure',exp);
            obj.exposure = exp;
        end
        % Get Functions
        function [N,pos,exp] = getInstrParams(obj)
            % Gets grating info and exposure from instrument (sec)
            out = obj.com('getGratingAndExposure');
            N = out(1); pos = out(2); exp = out(3);
        end
        function calibrate(obj,laser,range,exposure,ax) %when fed a tunable laser, will sweep the laser's range to calibrate itself, outputting a calibration function
            assert(isvalid(laser),'Invalid laser handle passed to Winspec calibration')
            assert(isnumeric(range) && length(range)==2,'Laser range for calibration should be array [min,max] in units of THz')
            f = [];
            if nargin < 5
                f = figure;
                ax = axes('parent',f);
            end
            err = [];
            try
                oldExposure = obj.exposure;
                obj.setExposure(exposure); %exposure is in seconds
                setpoints = linspace(range(1),range(2),5); %take 10 points across the range of the laser
                specloc = NaN(1,length(setpoints));
                laserloc = NaN(1,length(setpoints));
                laser.on;
                xlabel(ax,'Wavelength (nm)')
                title(ax,'Calibrating spectrometer')
                for i=1:length(setpoints)
                    laser.TuneCoarse(setpoints(i));
                    laserspec = obj.acquire;
                    plot(ax,laserspec.x,laserspec.y);drawnow;
                    specfit = fitpeaks(laserspec.x,laserspec.y,'fittype','gauss');
                    assert(length(specfit.locations) == 1, sprintf('Unable to read laser cleanly on spectrometer (%i peaks)',length(specfit.locations)));
                    specloc(i) = specfit.locations;
                    laserloc(i) = laser.getFrequency;
                end
                fit_type = fittype('a/(x-b)+c');
                options = fitoptions(fit_type);
                options.Start = [obj.c,0,0];
                [temp.nm2THz,temp.gof] = fit(specloc',laserloc',fit_type,options);
                temp.source = class(laser);
                temp.datetime = datetime;
                obj.cal_local = temp;
            catch err
            end
            laser.off;
            delete(f);
            obj.setExposure(oldExposure) %reset exposure
            if ~isempty(err)
                rethrow(err)
            end
        end
        
        function cal = calibration(obj,varargin)
            %get the calibration of the spectrometer; this is stored as 
            %cal_local. This can be called with additional inputs
            %(laser,range,exposure,ax), in which case the user will be
            %prompted to calibrate now if the calibration is expired or
            %does not exist.
            if isempty(obj.cal_local)
                % If called in savePref method, ignore and return default
                st = dbstack;
                if length(st) > 1 && strcmp(st(2).name,'Module.savePrefs')
                    mp = findprop(obj,'cal_local');
                    cal = mp.DefaultValue;
                    return
                elseif ~isempty(varargin)
                    answer = questdlg('No WinSpec calibration found; calibrate now?','No WinSpec Calibration','Yes','No','No');
                    if strcmp(answer,'Yes')
                        obj.calibrate(varargin{:})
                    else
                        error('No spectrometer calibration found; calibrate using WinSpec.calibrate(tunable laser handle, exposure time in seconds)');
                    end
                else
                    error('No spectrometer calibration found; calibrate using WinSpec.calibrate(tunable laser handle, exposure time in seconds)');
                end
            end
            obj.cal_local.expired = false;
            if days(datetime-obj.cal_local.datetime) >= obj.calibration_timeout
                warnstring = sprintf('Calibration not performed since %s. Recommend recalibrating by running WinSpec.calibrate.',datestr(obj.cal_local.datetime));
                if ~isempty(varargin) %with additional inputs, option to calibrate now
                    answer = questdlg([warnstring, ' Calibrate now?'],'WinSpec Calibration Expired','Yes','No','No');
                    if strcmp(answer,'Yes')
                        obj.calibrate(varargin{:})
                    else
                        obj.cal_local.expired = true;
                    end
                else
                    warning(warnstring)
                    obj.cal_local.expired = true;
                end
            end
            cal = obj.cal_local;
        end
    end
end

