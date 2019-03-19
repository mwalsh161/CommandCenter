classdef Spectrum < Modules.Experiment
    %Spectrum Experimental wrapper for Drivers.WinSpec
    
    
    properties(SetObservable,AbortSet)
        data
        ip = 'No Server';
        grating = {NaN,uint8(1),uint8(2),uint8(3)};    % Grating number
        position = 637;       % Grating position
        exposure = 1;         % Seconds
        prefs = {'ip'}; % Not including winspec stuff because it can take a long time!
        show_prefs = {'exposure','position','grating','ip'};
    end
    properties(SetAccess=private,Hidden)
        WinSpec
        fit                     % Handle to fit button
        listeners
    end
    methods(Access=private)
        function obj = Spectrum()
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
                Object = Experiments.Spectrum();
            end
            obj = Object;
        end
        
        sp = spectrumload(filename)
        out = TCP_comm( ip,port,msg )
    end
    methods
        function run( obj,status,managers,ax )
            assert(~isempty(obj.WinSpec)&&isvalid(obj.WinSpec),'WinSpec not configured propertly; check the IP');
            set(status,'string','Connecting...');
            obj.data = [];
            drawnow;
            obj.data = obj.WinSpec.acquire(@(t)set(status,'string',sprintf('Elapsed Time: %0.2f',t))); %user can cause abort error during this call
            if ~isempty(obj.data)
                plot(ax,obj.data.x,obj.data.y)
                xlabel(ax,'Wavelength (nm)')
                ylabel(ax,'Intensity (AU)')
                set(status,'string','Complete!')
            else
                set(status,'string','Unknown error. WinSpec did not return anything.')
            end
            obj.data.position = managers.Stages.position;
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
        function delete(obj)
            delete(obj.listeners)
        end
        function abort(obj)
            obj.WinSpec.abort;
        end
        
        function dat = GetData(obj,~,~)
            dat = [];
            if ~isempty(obj.data)
                dat.diamondbase.data_name = 'Spectrum';
                dat.diamondbase.data_type = 'local';
                dat.meta = obj.data;
                dat.wavelength = obj.data.x;
                dat.intensity = obj.data.y;
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

