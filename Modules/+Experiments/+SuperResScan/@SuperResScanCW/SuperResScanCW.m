classdef SuperResScanCW < Modules.Experiment
    
    properties
        abort_request = false;
        prefs = {'resLaser','repumpLaser','scan_type','wavelengths_set','resonator_percents','useROI','xmin','xmax','xpoints','ymin','ymax','ypoints'};
        show_prefs = {'resLaser','repumpLaser','scan_type','wavelengths_set','resonator_percents','useROI','xmin','xmax','xpoints','ymin','ymax','ypoints'};
        wavelengths = linspace(0,100,101);
        percents = linspace(0,100,101);
    end
    properties(SetObservable)
        resLaser = Modules.Source.empty;
        repumpLaser = Modules.Source.empty;
        scan_type = {'Wavelength','Resonator'};
        wavelengths_set = 'linspace(615,625,101)';
        resonator_percents = 'linspace(0,100,101)';
        useROI = true;
        xmin = -1;
        xmax = 1;
        xpoints = 100;
        ymin = -1;
        ymax = 1;
        ypoints = 100;
    end
    properties(Constant)
        c = 299792; %speed of light for converting wavelength in nm to frequency in THz
    end
    properties (SetAccess=private)
        data = [];
        meta = [];
        pb;
        nidaq;
        galvos;
    end
    
    methods(Access=private)
        function obj = SuperResScanCW()
            obj.loadPrefs;
            obj.galvos = Drivers.NIDAQ.stage.instance('X','Y','Z','APD1','GalvoScanSync');
            obj.nidaq = Drivers.NIDAQ.dev.instance('Dev1');
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.SuperResScan.SuperResScanCW();
            end
            obj = Object;
        end
    end
    
    methods
        run(obj,statusH,managers,ax)
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        function dat = GetData(obj,~,~)
            % Callback for saving methods (note, lots more info in the two managers input!)
            dat.data = obj.data;
            dat.meta = obj.meta;
        end
        
        function set.wavelengths_set(obj,val)
            obj.wavelengths = eval(val);
            obj.wavelengths_set = val;
        end
        function set.resonator_percents(obj,val)
            obj.percents = eval(val);
            obj.resonator_percents = val;
        end
        function set.xmin(obj,val)
            assert(isnumeric(val),'Value must be a number');
            obj.xmin = val;
        end
        function set.xmax(obj,val)
            assert(isnumeric(val),'Value must be a number');
            obj.xmax = val;
        end
        function set.xpoints(obj,val)
            assert(isnumeric(val),'Value must be a number');
            obj.xpoints = val;
        end
        function set.ymin(obj,val)
            assert(isnumeric(val),'Value must be a number');
            obj.ymin = val;
        end
        function set.ymax(obj,val)
            assert(isnumeric(val),'Value must be a number');
            obj.ymax = val;
        end
        function set.ypoints(obj,val)
            assert(isnumeric(val),'Value must be a number');
            obj.ypoints = val;
        end
    end
end
