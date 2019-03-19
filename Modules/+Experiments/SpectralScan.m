classdef SpectralScan < Modules.Experiment
    %SpectralScan Take spectra at each point of confocal scan
    %   Utilizes the current imaging settings
    %
    %   Click on parts of the image to see spectra from there once the
    %   experiment runs
    
    properties
        data
        meta
        prefs = {'ip'};
        show_prefs = {'exposure','position','grating','ip'};
    end
    properties(SetObservable,AbortSet)
        ip = 'No Server';  % IP to winspec server
        grating = {NaN,uint8(1),uint8(2),uint8(3)};    % Grating number
        position = 637;       % Grating position
        exposure = 1;         % Seconds
    end
    properties(SetAccess=private,Hidden)
        WinSpec % Set when ip changed
        listeners
        scanH;          % Handle to image object of scan (to delete when closed)
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
    end
    
    methods(Access=private)
        function obj = SpectralScan()
            obj.grating = NaN;
            try
                obj.loadPrefs; % Load prefs should setWinSpec
            catch err % Don't need to raise alert here
                if ~strcmp(err.message,'WinSpec not set')
                    rethrow(err)
                end
            end
        end
        function setWinSpec(obj,ip)
            delete(obj.listeners);
            obj.WinSpec = []; obj.listeners = [];
            if strcmp(ip,'No Server')
                return
            end
            wrappers = {'grating','position','exposure'};
            try
                obj.WinSpec = Drivers.WinSpec.instance(ip);
                % Setup listeners and grab winspec settings
                for i = 1:length(wrappers)
                    obj.(wrappers{i}) = obj.WinSpec.(wrappers{i});
                    if i == 1
                        obj.listeners = addlistener(obj.WinSpec,wrappers{i},'PostSet',@(a,b)updateprop(a,b,obj));
                    else
                        obj.listeners(i) = addlistener(obj.WinSpec,wrappers{i},'PostSet',@(a,b)updateprop(a,b,obj));
                    end
                end
            catch err
                obj.WinSpec = [];
                for i = 1:length(wrappers) % Disable editing
                    obj.(wrappers{i}) = NaN;
                end
                rethrow(err)
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.SpectralScan();
            end
            obj = Object;
        end
    end
    methods
        function run(obj,statusH,managers,ax)
            obj.abort_request = false;
            assert(~isempty(obj.WinSpec)&&isobject(obj.WinSpec)&&isvalid(obj.WinSpec),'WinSpec not configured propertly; check the IP');
            stage = managers.Imaging.active_module.uses_stage;
            assert(logical(managers.Stages.check_module_str(stage)),'Stage associated with active imager is not loaded.');
            managers.Stages.setActiveModule(stage); % Make the stage active
            startingPos = managers.Stages.position;
            zpos = startingPos(3);
            
            x = linspace(managers.Imaging.ROI(1,1),managers.Imaging.ROI(1,2),managers.Imaging.active_module.resolution(1));
            y = linspace(managers.Imaging.ROI(2,1),managers.Imaging.ROI(2,2),managers.Imaging.active_module.resolution(2));
            % Need to take a scan to see how long it is
            temp_exp = obj.WinSpec.exposure;
            obj.WinSpec.setExposure(0.001); % Temporary to grab frame
            spec = obj.WinSpec.acquire(@(t)set(statusH,'string',sprintf('Testing Spectrum:\nElapsed Time: %0.2f',t)));
            plot(spec.x,spec.y,'parent',ax); title(ax,'Test with msec exposure');
            obj.WinSpec.setExposure(temp_exp);
            set(statusH,'string','Allocating Memory...'); drawnow;
            obj.data.x = x;
            obj.data.y = y;
            obj.data.freq = spec.x;
            restart = true;
            if isfield(obj.data,'scan') && sum(isnan(obj.data.scan(:))) && obj.data.meta.ExposureSec==temp_exp
                start = numel(obj.data.scan(:,:,1)) - sum(sum(isnan(obj.data.scan(:,:,1))));
                answer = questdlg('Detected incomplete scan. Do you want to resume or start over?','Run','Resume','Restart','Resume');
                if isempty(answer) % User closed window, so let's take that as an abort
                    managers.Experiment.abort; drawnow;
                elseif strcmp(answer,'Resume')
                    restart = false;
                end
            end
            assert(~obj.abort_request,'User Aborted.')
            if restart
                start = 0;
                obj.data.scan = NaN([fliplr(managers.Imaging.active_module.resolution), length(spec.x)]);
            end
            obj.data.meta = spec; % Grab everything from sample SPE file
            obj.data.meta.ExposureSec = temp_exp; % Overwrite real exposure time
            obj.scanH = imagesc(x,y,NaN(fliplr(managers.Imaging.active_module.resolution)),'parent',managers.handles.axImage);
            set(managers.handles.axImage,'ydir','normal');
            axis(obj.scanH.Parent,'image');
            spectH = plot(NaN,NaN,'parent',ax);
            xlabel(ax,'Wavelength (nm)');
            ylabel(ax,'Counts (a.u.)');
            
            set(obj.scanH,'ButtonDownFcn',@(a,b)obj.moveTo(a,b,spectH));
            dt = NaN;
            total = length(x)*length(y);
            err = [];
            try
            for i = 1:length(y)
                for j = 1:length(x)
                    if j+(i-1)*length(y) <= start
                        continue
                    end
                    assert(~obj.abort_request,'User Aborted.')
                    tic;
                    % Update time estimate
                    n = (i-1)*length(y)+j;
                    hrs = floor(dt*(total-n)/60/60);
                    mins = round((dt*(total-n)-hrs*60*60)/60);
                    msg = sprintf('Running (%i%%)\n%i hrs %i mins left.',round(100*n/total),hrs,mins);
                    set(statusH,'string',msg); drawnow;
                    % Move to next spot and take spectra
                    managers.Stages.move([x(j),y(i),zpos]);
                    managers.Stages.waitUntilStopped;
                    spec = obj.WinSpec.acquire(@(t)set(statusH,'string',sprintf('%s\nElapsed Time: %0.2f',msg,t)));
                    % Update data structures and plots
                    obj.data.scan(i,j,:) = spec.y;
                    set(spectH,'xdata',spec.x,'ydata',spec.y);
                    title(ax,sprintf('Spectra %i of %i',n,total));
                    set(obj.scanH,'cdata',mean(obj.data.scan,3));
                    drawnow;
                    if isnan(dt)
                        dt = toc;
                    else
                        dt = 0.5*dt+0.5*toc;
                    end
                end
            end
            catch err
            end
            managers.Stages.move(startingPos)
            managers.Stages.waitUntilStopped;
            if ~isempty(err)
                rethrow(err)
            end
            obj.meta = obj.prefs2struct;
            obj.meta.imager.name = class(managers.Imaging.active_module);
            obj.meta.imager.prefs = managers.Imaging.active_module.prefs2struct;
            obj.meta.stage.name = class(managers.Stages.active_module);
            obj.meta.stage.prefs = managers.Stages.active_module.prefs2struct;
        end
        function moveTo(obj,hObj,eventdata,spectH)
            D = [mean(diff(hObj.XData)) mean(diff(hObj.YData))];
            xBin = ceil(eventdata.IntersectionPoint(1)/D(1)-hObj.XData(1)/D(1)+0.5);
            yBin = ceil(eventdata.IntersectionPoint(2)/D(2)-hObj.YData(1)/D(2)+0.5);
            hold(hObj.Parent,'on')
            title(spectH.Parent,sprintf('(%i,%i)',xBin,yBin));
            set(spectH,'ydata',squeeze(obj.data.scan(yBin,xBin,:)));
        end
        function delete(obj)
            delete(obj.listeners)
        end
        function set.ip(obj,val)
            try
                obj.setWinSpec(val);
                obj.ip = val;
            catch err
                obj.ip = 'No Server';
                rethrow(err)
            end
        end

        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.data = obj.data;
                data.meta = obj.meta;
            else
                data = [];
            end
        end
        
        % Experimental Set methods
        function setWrapper(obj,param,varargin)
            if isempty(obj.WinSpec); return; end
            % Don't set in constructor.
            d = dbstack;
            if ismember([mfilename '.' mfilename],{d.name}); return; end
            obj.WinSpec.(sprintf('set%s',param))(varargin{:});
        end
        function set.grating(obj,val)
            obj.grating = val;
            if isempty(obj.WinSpec); return; end
            d = dbstack;
            if ismember([mfilename '.' mfilename],{d.name}); return; end % Redundant, just to avoid msgbox popup
            h = msgbox(sprintf(['Moving grating from %i to %i',newline,...
                'This takes time.'],obj.WinSpec.grating,val),mfilename,'help','modal');
            delete(findall(h,'tag','OKButton')); drawnow;
            err = [];
            try
            obj.setWrapper('Grating',val,[]);
            catch err
            end
            delete(h)
            if ~isempty(err)
                rethrow(err)
            end
        end
        function set.position(obj,val)
            obj.position = val;
            obj.setWrapper('Grating',[],val);
        end
        function set.exposure(obj,val)
            obj.exposure = val;
            obj.setWrapper('Exposure',val);
        end
    end    
end

