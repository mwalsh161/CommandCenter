classdef Centerchip < Modules.Experiment
    %AutoChipletSearch Description of experiment
    properties(SetObservable,AbortSet)
        data
        ip = 'No Server';
        grating = @Experiments.Spectrum.set_grating_values;
        position = NaN;       % Grating position
        exposure = NaN;         % Seconds
        over_exposed_override = false; % override over_exposed error from server and return data regardless
        prefs = {'over_exposed_override','ip'}; % Not including winspec stuff because it can take a long time!
        show_prefs = {'exposure','position','grating','over_exposed_override','ip'};
    end
    properties(SetAccess=private,Hidden)
        WinSpec
        listeners
    end
    properties(GetObservable,SetObservable)
        % These should be preferences you want set in default settings method
        camera = Prefs.ModuleInstance('help_text','White light camera imaging module for focusing');
        galvo = Prefs.ModuleInstance('help_text','Galvo scanning imaging module for confocal scanning');
        laser = Prefs.ModuleInstance('help_text','laser used for galvo confocal scanning');
        whitelight = Prefs.ModuleInstance('help_text','White light used for camera focusing');
        experiment = Prefs.ModuleInstance('help_text','Experiment to run at each point')
    end
    methods(Access=private)
        function obj = Centerchip()
            obj.path = 'spectrometer';
            obj.grating = NaN;
            try
                obj.loadPrefs; % Load prefs should load WinSpec via set.ip
            catch err % Don't need to raise alert here
                if ~strcmp(err.message,'WinSpec not set')
                    rethrow(err)
                end
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Centerchip();
            end
            obj = Object;
        end
        function gratings = set_grating_values()
            % If this is called properly, we can assume the singleton is
            % loaded, and grab it. If not called by CC, this will end up
            % creating an instance rather than grabbing the existing one.
            obj = Experiments.Centerchip.instance;
            if isempty(obj.WinSpec)
                gratings = {'Connect to WinSpec first (ip)'};
            else
                gratings = arrayfun(@(a)sprintf('%i %s',a.grooves,a.name),obj.WinSpec.gratings_avail,'uniformoutput',false);
            end
        end
        sp = spectrumload(filename)
        out = TCP_comm( ip,port,msg )
    end

    methods
        % function run( obj,status,managers,ax )
        %     assert(~isempty(obj.WinSpec)&&isobject(obj.WinSpec)&&isvalid(obj.WinSpec),'WinSpec not configured propertly; check the IP');
        %     set(status,'string','Connecting...');
        %     obj.data = [];
        %     drawnow;
        %     obj.data = obj.WinSpec.acquire(@(t)set(status,'string',sprintf('Elapsed Time: %0.2f',t)),obj.over_exposed_override); %user can cause abort error during this call
        %     if ~isempty(obj.data)
        %         plot(ax,obj.data.x,obj.data.y)
        %         xlabel(ax,'Wavelength (nm)')
        %         ylabel(ax,'Intensity (AU)')
        %         set(status,'string','Complete!')
        %     else
        %         set(status,'string','Unknown error. WinSpec did not return anything.')
        %     end
        %     obj.data.position = managers.Stages.position;
        %     try
        %         obj.data.WinSpec_calibration = obj.WinSpec.calibration;
        %         img = obj.camera.snap;
        %     catch
        %         obj.data.WinSpec_calibration = [];
        %     end
        % end

        function run( obj,status,managers,ax )
            % Imaging.Camera.snap()

            img = obj.camera.snap;
        
            % Main run method (callback for CC run button)
            % obj.abort_request = false;
            % status.String = 'Experiment started';
            % drawnow;
            % % Edit here down (save data to obj.data)
            % % Tips:
            % % - If using a loop, it is good practice to call:
            % %     drawnow; assert(~obj.abort_request,'User aborted.');
            % %     as frequently as possible
            % % - try/catch/end statements useful for cleaning up
            % % - You can get a figure-like object (to create subplots) by:
            % %     panel = ax.Parent; delete(ax);
            % %     ax(1) = subplot(1,2,1,'parent',panel);
            % % - drawnow can be used to update status box message and any plots
        
            % % Edit this to include meta data for this experimental run (saved in obj.GetData)
            % obj.meta.prefs = obj.prefs2struct;
            % obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
        
            % panel = ax.Parent; delete(ax); % Get subplots
            % % Image processing subplot
            % image_ax = subplot(1,2,1,'parent',panel);
        
            % % obj.laser.on;
        
        
            % try
        
            %     for i = 1:obj.chiplet_number(1)
            %         % scan through chiplet x
            %         for j = 1:obj.chiplet_number(2)
            %             % scan through chiplet y
        
            %             % Go to camera path
            %             obj.whitelight.on;
            %             if managers.Path.active_path ~= "camera"
            %                 managers.Path.select_path('camera')
            %             end
        
            %             % Focus
            %             try
            %                 obj.camera.ContrastFocus(managers, obj.fine_autofocus_range, obj.fine_autofocus_step_size, obj.fine_autofocus_stage, false);
            %             catch err
            %                 % If autofocus doesn't work, try coarse autofocus before giving up
            %                 obj.camera.ContrastFocus(managers, obj.coarse_autofocus_range, obj.coarse_autofocus_step_size, obj.coarse_autofocus_stage, false);
            %                 obj.camera.ContrastFocus(managers, obj.fine_autofocus_range, obj.fine_autofocus_step_size, obj.fine_autofocus_stage, false);
            %             end
        
            %             % Center chiplet
        
            %             % Go to confocal scan
            %             % obj.whitelight.off;
            %             % managers.Path.select_path('APD')
                        
        
            %             % Process image to get points
            %             img = obj.camera.snap
        
            %             % functiontofindthecenter(img)
        
            %             % Run experiment at points
                        
        
            %         end
            %     end
            % catch err
            % end
            % % CLEAN UP CODE %
            % if exist('err','var')
            %     % HANDLE ERROR CODE %
            %     rethrow(err)
            % end
        end
        
        function set.ip(obj,val)
            delete(obj.listeners);
            obj.WinSpec = []; obj.listeners = [];
            wrappers = {'grating','position','exposure'};
            if strcmp(val,'No Server')
                for i = 1:length(wrappers) % Disable editing
                    obj.(wrappers{i}) = NaN;
                end
                obj.ip = val;
            else
                h = msgbox(sprintf('Connecting to %s...',val),mfilename,'help','modal');
                delete(findall(h,'tag','OKButton')); drawnow;
                try
                    obj.WinSpec = Drivers.WinSpec.instance(val); %#ok<*MCSUP>
                    obj.ip = val;
                    % Setup listeners and grab winspec settings
                    grating_info = obj.WinSpec.gratings_avail(obj.WinSpec.grating);
                    notify(obj,'update_settings'); % Trigger CC to reload settings now that we have grating info (before calling update_settings)
                    obj.grating = sprintf('%i %s',grating_info.grooves,grating_info.name);
                    obj.listeners = addlistener(obj.WinSpec,'grating','PostSet',@obj.set_grating_string);
                    for i = 2:length(wrappers)
                        obj.(wrappers{i}) = obj.WinSpec.(wrappers{i});
                        obj.listeners(i) = addlistener(obj.WinSpec,wrappers{i},'PostSet',@(a,b)updateprop(a,b,obj));
                    end
                    delete(h)
                catch err
                    delete(h)
                    obj.WinSpec = [];
                    for i = 1:length(wrappers) % Disable editing
                        obj.(wrappers{i}) = NaN;
                    end
                    obj.ip = 'No Server';
                    notify(obj,'update_settings'); % Trigger CC to reload settings now that we have disabled them with NaN
                    rethrow(err)
                end
            end
        end
        function delete(obj)
            delete(obj.listeners)
            delete(obj.WinSpec)
        end
        function abort(obj)
            obj.WinSpec.abort;
        end
        
        function dat = GetData(obj,~,~)
            dat = [];
            if ~isempty(obj.data)
                dat.diamondbase.data_name = 'Spectrum';
                dat.diamondbase.data_type = 'local';
                dat.wavelength = obj.data.x;
                dat.intensity = obj.data.y;
                dat.meta = rmfield(obj.data,{'x','y'});
            end
        end
        
        function set_grating_string(obj,varargin)
            grating_info = obj.WinSpec.gratings_avail(obj.WinSpec.grating);
            obj.grating = sprintf('%i %s',grating_info.grooves,grating_info.name);
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
            val = find(strcmp(obj.set_grating_values,val)); % Grab index corresponding to option
            assert(~isempty(val),sprintf('Could not find "%s" grating in WinSpec.gratings_avail',val));
            h = msgbox(sprintf(['Moving grating from %i to %i',newline,...
                'This may take time.'],obj.WinSpec.grating,val),[mfilename ' grating'],'help','modal');
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
    % properties(SetObservable,AbortSet)
    %     % These should be preferences you want set in default settings method
    %     chiplet_spacing = Prefs.DoubleArray([65 65], 'units','um','help_text','Array of x and y spacing of chiplets');
    %     chiplet_number = Prefs.DoubleArray([2 2], 'units','um','help_text','Number of chiplets along x and y');
        
    %     fine_autofocus_stage = Prefs.ModuleInstance('help_text','Stage that does fine autofocusing (probably piezo)');
    %     fine_autofocus_range = Prefs.DoubleArray([0 1], 'units', 'um', 'help_text', 'Range around current stage position that autofocus will search to find focus');
    %     fine_autofocus_step_size = Prefs.Double(0.1, 'units', 'um', 'help_text','Step size to use for fine autofocusing','min',0);
        
    %     coarse_autofocus_stage = Prefs.ModuleInstance('help_text','Stage that does coarse autofocusing (probably setpper)');
    %     coarse_autofocus_range = Prefs.DoubleArray([-1 1], 'units', 'um', 'help_text', 'Range around current stage position that autofocus will search to find focus');
    %     coarse_autofocus_step_size = Prefs.Double(0.1, 'units', 'um', 'help_text','Step size to use for autofocusing','min',0);
        
    %     camera = Prefs.ModuleInstance('help_text','White light camera imaging module for focusing');
    %     galvo = Prefs.ModuleInstance('help_text','Galvo scanning imaging module for confocal scanning');
    %     laser = Prefs.ModuleInstance('help_text','laser used for galvo confocal scanning');
    %     whitelight = Prefs.ModuleInstance('help_text','White light used for camera focusing');
        
    %     experiment = Prefs.ModuleInstance('help_text','Experiment to run at each point')
    % end
    % properties
    %     prefs = {'chiplet_spacing','chiplet_number','fine_autofocus_stage','fine_autofocus_range','fine_autofocus_step_size','coarse_autofocus_stage','coarse_autofocus_range','coarse_autofocus_step_size','camera','galvo'};
    %     %show_prefs = {};   % Use for ordering and/or selecting which prefs to show in GUI
    %     %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    % end
    % properties(SetAccess=private,Hidden)
    %     % Internal properties that should not be accessible by command line
    %     % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
    %     data = [] % Useful for saving data from run method
    %     meta = [] % Useful to store meta data in run method
    %     abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    % end
