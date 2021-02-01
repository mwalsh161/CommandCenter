classdef Spectrum < Modules.Experiment
    %Spectrum Experimental wrapper for Drivers.WinSpec
    
    properties(SetObservable,GetObservable)
        ip =        Prefs.String('No Server', 'help', 'IP/hostname of computer with the WinSpec server');
        grating = 	Prefs.MultipleChoice('');
        position = 	Prefs.Double(NaN,   'unit', 'nm');      % Grating position
        exposure =  Prefs.Double(NaN,   'unit', 'sec');     % Exposure time
        
        over_exposed_override = Prefs.Boolean(false);       % override over_exposed error from server and return data regardless
    end
    
%     properties(Access=private)
% %         intensity =     Base.Meas([1 1024], 'unit', 'arb')
% %         wavelength =    Base.Meas([1 1024], 'unit', 'nm')
%         
%         measurements = [Base.Meas([1 1024], 'field', 'intensity',  'unit', 'arb') ...
%                         Base.Meas([1 1024], 'field', 'wavelength', 'unit', 'nm')];
%     end
    
    properties (Hidden, Constant)
        gratingFormat = @(a)sprintf('%i %s', a.grooves, a.name)
    end
    
    properties(SetObservable,AbortSet)
        data
        
%         prefs = {'over_exposed_override','ip'}; % Not including winspec stuff because it can take a long time!
%         show_prefs = {'exposure','position','grating','over_exposed_override','ip'};
    end
    
    properties(SetAccess=private,Hidden)
        WinSpec
        listeners
    end
    
    methods(Access=private)
        function obj = Spectrum()
            'Spectrum init'
            
            obj.path = 'spectrometer';
            
            obj.measurements = [Base.Meas([1 1024], 'field', 'intensity',  'unit', 'arb') ...
                                Base.Meas([1 1024], 'field', 'wavelength', 'unit', 'nm')];
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
                Object.ip = Object.ip;
            end
            obj = Object;
        end
    end
    
    methods
        function run( obj,status,managers,ax )
            assert(~isempty(obj.WinSpec) && isobject(obj.WinSpec)&&isvalid(obj.WinSpec),'WinSpec not configured propertly; check the IP');
            obj.data = [];
            
            if ~isempty(status)
                set(status,'string','Connecting...');
                drawnow;
                obj.data = obj.WinSpec.acquire(@(t)set(status,'string',sprintf('Elapsed Time: %0.2f',t)),obj.over_exposed_override); %user can cause abort error during this call
            else
                obj.data = obj.WinSpec.acquire([],obj.over_exposed_override);
            end
            
            if ~isempty(obj.data) && ~isempty(ax)
                plot(ax,obj.data.x, obj.data.y)
                xlabel(ax,'Wavelength (nm)')
                ylabel(ax,'Intensity (AU)')
                if ~isempty(status)
                    set(status,'string','Complete!')
                end
            else
                if ~isempty(status)
                    set(status,'string','Unknown error. WinSpec did not return anything.')
                end
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
            
            obj.ip = val;
            
            err = [];
            
%             obj.setMeasurementVars(1024);
            
            if ~strcmp(val, 'No Server')
                h = msgbox(sprintf('Connecting to %s...',val), mfilename, 'help', 'modal');
                delete(findall(h,'tag','OKButton')); drawnow;
                try
                    obj.WinSpec = Drivers.WinSpec.instance(val);
                    
                    obj.setGratingStrings();
                    obj.get_grating();
                    
                    obj.position = obj.WinSpec.position;
                    obj.exposure = obj.WinSpec.exposure;
                    
%                     obj.setMeasurementVars(1024);
                    
                    delete(h)
                    return;
                catch err
                    delete(h)
                end
            end
            
            
            obj.WinSpec = [];
            
            obj.grating = {};
            obj.position = NaN;
            obj.exposure = NaN;
            
            obj.ip = 'No Server';
            
            val = obj.ip;
            
            if ~isempty(err)
                rethrow(err)
            end
        end
%         function setMeasurementVars(obj, N)
%             obj.sizes = struct('wavelength', [1 N],   'intensity', [1 N]);
%             obj.units = struct('wavelength', 'nm',      'intensity', 'arb');
%             % Scans and dims default to 1:N (pixels), which is fine.
%         end
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
        
        function strs = getGratingStrings(obj)
            if ~isempty(obj.WinSpec)
                strs = arrayfun(obj.gratingFormat, obj.WinSpec.gratings_avail, 'uniformoutput', false);
            else
                strs = {};
            end
        end
        function setGratingStrings(obj)
            g = obj.get_meta_pref('grating');

            g.choices = obj.getGratingStrings();

            obj.set_meta_pref('grating', g);
        end
        function val = get_grating(obj, ~)
            if ~isempty(obj.WinSpec)
                grating_info = obj.WinSpec.gratings_avail(obj.WinSpec.grating);
                obj.grating = obj.gratingFormat(grating_info);
                val = obj.grating;
            end
        end
        
        % Experimental Set methods
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
        function setWrapper(obj,param,varargin)
            if isempty(obj.WinSpec); return; end
            % Don't set in constructor.
            d = dbstack;
            if ismember([mfilename '.' mfilename],{d.name}); return; end
            obj.WinSpec.(sprintf('set%s',param))(varargin{:});
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

