classdef ClosedDAQ < Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible
    %Closed Closed-loop laser sweep for slowscan
    % Set freqs_THz, locks laser to each position (still records measured
    % value, but should be within resolution of the laser

    properties(SetObservable,AbortSet)
        Base_Frequency = Prefs.Double(470, 'unit', 'THz');
        Base_Etalon = Prefs.Double(50, 'unit', '%');
        
        DAQ_dev = Prefs.String('Dev1');
        DAQ_line = Prefs.String('ao3');
        
        from =  Prefs.Double(10, 'set', 'calc_freqs', 'min', 10, 'max', 90, 'unit', '%');
        to =    Prefs.Double(90, 'set', 'calc_freqs', 'min', 10, 'max', 90, 'unit', '%');
        
        Vrange = Prefs.Double(10, 'readonly', 'unit', 'V');
        V2GHz = Prefs.Double(2.5, 'readonly', 'unit', 'GHz/V');
        
        freq_from = Prefs.Double(NaN, 'allow_nan', true, 'readonly', 'unit', 'THz');
        freq_to =   Prefs.Double(NaN, 'allow_nan', true, 'readonly', 'unit', 'THz');
    end
%     properties(Constant)
%         xlabel = 'Frequency (THz)';
%     end

    properties
        dev
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = ClosedDAQ()
            obj.dev = Drivers.NIDAQ.dev(obj.DAQ_dev);
            
            obj.scan_points = 
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
        
        function setLaser(obj, index)
            obj.dev.WriteAOLines(obj.name, obj.scan_points(index));
        end
    end

    methods
        function set.calc_freqs(obj, val)
            
            obj.calc_freqs = val;
        end 
    end
end
