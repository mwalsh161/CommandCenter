classdef Spectrum < Modules.Experiment
    %Spectrum Experimental wrapper for Drivers.WinSpec
    
    properties(SetObservable,GetObservable)
        ip = Prefs.String('No Server', 'help', 'IP/hostname of computer with the WinSpec server');
        grating = 	Prefs.MultipleChoice('choices', @Experiments.Spectrum.set_grating_values, 'allow_empty', false);    % Grating number (index into gratings_avail)
        position = 	Prefs.Double(NaN,   'unit', 'nm');     % Grating position
        exposure =  Prefs.Double(NaN,   'unit', 'sec');     % Exposure time
    end
    
    properties(SetObservable,AbortSet)
        data
        
%         ip = 'No Server';
%         grating = @Experiments.Spectrum.set_grating_values;
%         position = NaN;       % Grating position
%         exposure = NaN;         % Seconds
        
        over_exposed_override = false; % override over_exposed error from server and return data regardless
        prefs = {'over_exposed_override','ip'}; % Not including winspec stuff because it can take a long time!
        show_prefs = {'exposure','position','grating','over_exposed_override','ip'};
    end
    properties(SetAccess=private,Hidden)
        WinSpec
        listeners
    end
    methods(Access=private)
        function obj = Spectrum()
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
                Object = Experiments.Spectrum();
            end
            obj = Object;
        end
        function gratings = set_grating_values()
            % If this is called properly, we can assume the singleton is
            % loaded, and grab it. If not called by CC, this will end up
            % creating an instance rather than grabbing the existing one.
            obj = Experiments.Spectrum.instance;
            if isempty(obj.WinSpec)
                gratings = {'Connect to WinSpec first (ip)'};
            else
                gratings = arrayfun(@(a)sprintf('%i %s', a.grooves, a.name), obj.WinSpec.gratings_avail, 'uniformoutput', false);
            end
        end
        sp = spectrumload(filename)
        out = TCP_comm( ip,port,msg )
    end
    
    methods
        function run( obj,status,managers,ax )
            assert(~isempty(obj.WinSpec)&&isobject(obj.WinSpec)&&isvalid(obj.WinSpec),'WinSpec not configured propertly; check the IP');
            set(status,'string','Connecting...');
            obj.data = [];
            drawnow;
            obj.data = obj.WinSpec.acquire(@(t)set(status,'string',sprintf('Elapsed Time: %0.2f',t)),obj.over_exposed_override); %user can cause abort error during this call
            
            if ~isempty(obj.data) && ~isempty(ax)
                plot(ax,obj.data.x,obj.data.y)
                xlabel(ax,'Wavelength (nm)')
                ylabel(ax,'Intensity (AU)')
                set(status,'string','Complete!')
            else
                set(status,'string','Unknown error. WinSpec did not return anything.')
            end
            
            if ~isempty(managers)
                obj.data.position = managers.Stages.position;
            end
            
            try
                obj.data.WinSpec_calibration = obj.WinSpec.calibration;
            catch
                obj.data.WinSpec_calibration = [];
            end
        end
        
        function val = set_ip(obj,val, ~)
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
            
            val = obj.ip;
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
        function val = set_grating(obj, val, ~)
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
            obj.setWrapper('Grating', val, []);
            catch err
            end
            delete(h)
            if ~isempty(err)
                rethrow(err)
            end
        end
        function val = set_position(obj, val, ~)
            obj.position = val;
            obj.setWrapper('Grating', [], val);
        end
        function val = set_exposure(obj, val, ~)
            obj.exposure = val;
            obj.setWrapper('Exposure', val);
        end
    end
    
end

