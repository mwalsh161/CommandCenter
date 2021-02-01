classdef ODMR < Modules.Experiment
    %ODMR Description of experiment
    % Useful to list any dependencies here too

    properties (GetObservable, SetObservable)
        image = Prefs.ModuleInstance('inherits', {'Modules.Imaging'}, 'set', 'set_image');

        signal_generator = Prefs.ModuleInstance('inherits', {'Modules.Source'});
        
        norm_frequency = Prefs.Double(2.5e9/Sources.SignalGenerators.SG_Source_invisible.freqUnit2Hz, ...
                                    'min', 0,...
                                    'unit', Sources.SignalGenerators.SG_Source_invisible.freqUnit, ...
                                    'help', 'The frquency tone that the signal generator is set at during normalization.');
    end
    
    properties
        raw
        norm
        data
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        function obj = instance(varargin)
            % This file is what locks the instance in memory such that singleton
            % can perform properly. 
            % For the most part, varargin will be empty, but if you know what you
            % are doing, you can modify/use the input (just be aware of singleton_id)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Experiments.ODMR.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(varargin,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Experiments.ODMR(varargin{:});
            obj.singleton_id = varargin;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = ODMR()
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        function run(obj,~,~,~)
            base_freq = obj.signal_generator.frequency;
            obj.raw = obj.image.measure();
            
            obj.signal_generator.frequency = obj.norm_frequency;
            obj.norm = obj.image.measure();
            
            obj.signal_generator.frequency = base_freq;
            
            obj.data = 1 - obj.raw ./ obj.norm;
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,~,~)
            % Callback for saving methods
            dat.raw = obj.raw;
            dat.norm = obj.norm;
            dat.data = obj.data;
        end

        function val = set_image(obj, val, ~)
            meas = val.measurements;
            
            obj.measurements = [Base.Meas(meas.size, 'field', 'raw',  'unit', meas.unit, 'scans', meas.scans, 'dims', meas.dims) ...
                                Base.Meas(meas.size, 'field', 'norm', 'unit', meas.unit, 'scans', meas.scans, 'dims', meas.dims) ...
                                Base.Meas(meas.size, 'field', 'data', 'unit', meas.unit, 'scans', meas.scans, 'dims', meas.dims)];
        end
    end
end
