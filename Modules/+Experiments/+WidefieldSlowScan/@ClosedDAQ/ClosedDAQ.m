classdef ClosedDAQ < Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible
    %Closed Closed-loop laser sweep for slowscan
    % Set freqs_THz, locks laser to each position (still records measured
    % value, but should be within resolution of the laser

    properties(SetObservable, AbortSet)
        base_freq = Prefs.Double(470, 'unit', 'THz',                                        'help', 'The frequency that.');
        base_percent = Prefs.Double(50, 'unit', '%',                                        'help', 'The percentage setting for the base frequency.');
        
        DAQ_dev = Prefs.String('Dev1',                                                      'help', 'NIDAQ Device.');
        DAQ_line = Prefs.String('laser',                                                    'help', 'NIDAQ virtual line.');
        
        from =  Prefs.Double(10, 'set', 'calc_freqs', 'min', 10, 'max', 90, 'unit', '%',    'help', 'Percentage value to scan from.');
        to =    Prefs.Double(90, 'set', 'calc_freqs', 'min', 10, 'max', 90, 'unit', '%',    'help', 'Percentage value to scan to.');
        
        overshoot = Prefs.Double(5, 'set', 'calc_freqs', 'min', 0, 'max', 10, 'unit', '%',  'help', 'To counteract hysteresis, we offset from by offshoot at the beginning of the scan.');
        
        step =  Prefs.Double(10, 'min', 0, 'MHz',                                           'help', 'Step between points in the sweep. This is in MHz because sane units are sane.');
        
        Vrange = Prefs.Double(10, 'readonly', true, 'unit', 'V',                            'help', 'Max range that the DAQ can input on the laser. This is dangerous to change, so it is readonly for now.');
        V2GHz = Prefs.Double(2.5, 'unit', 'GHz/V',                                          'help', 'Conversion between voltage and GHz for the laser. This is only used to calculate freq_from and freq_to along with figuring out what step means.');
        
        freq_from = Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'THz',   'help', 'Calculated conversion between percent and THz for from.');
        freq_to =   Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'THz',   'help', 'Calculated conversion between percent and THz for to.');
    end

    properties
        dev
        overshoot_voltage
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = ClosedDAQ()
            obj.loadPrefs; % Load prefs specified as obj.prefs
            obj.get_scan_points();
        end
        
        function setLaser(obj, scan_point)
            obj.dev.WriteAOLines(obj.name, scan_point);
        end
        
        function get_scan_points(obj)
            stepTHz = obj.step/1e6; % Step is in MHz
            
            if obj.to > obj.from    % We are ascending
                overshoot_percent = obj.from - obj.overshoot;
            else                    % We are descending
                overshoot_percent = obj.from + obj.overshoot;
                
                stepTHz = -stepTHz;
            end
            
            assert(overshoot_percent >= 0 && overshoot_percent <= 100);                         % Make sure overshoot_percent is sane.
            
            obj.overshoot_voltage = (overshoot_percent - obj.base_percent) * obj.Vrange / 100;  % And calculate the cooresponding voltage.
            
            rangeTHz = (obj.V2GHz * obj.Vrange / 1e3);
            stepPercent = stepTHz / rangeTHz;               % Convert step to percentage
            
            scan_percents = obj.from:stepPercent:obj.to;    
            if scan_percents(end) ~= obj.to                 % If to isn't present...
                scan_percents(end + 1) = obj.to;            % ...add it.
            end
            
            assert(all(scan_percents >= 0 & scan_percents <= 100));                             % Make sure all these values are sane
            
            obj.scan_points = (scan_percents - obj.base_percent) * obj.Vrange / 100;            % And calculate the cooresponding voltages.
        end
        
        function THz = percent2THz(obj, percent)
            THz = obj.V2GHz * obj.Vrange * (percent - obj.base_percent);
        end
        
        function PreRun(obj, ~, managers, ax)
            PreRun@Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible(obj, 0, managers, ax);
            
            obj.get_scan_points();
            
            obj.dev = Drivers.NIDAQ.dev(obj.DAQ_dev);
            obj.setLaser(obj.overshoot_voltage)
        end
    end

    methods
        function set.calc_freqs(obj, val)
            
            obj.calc_freqs = val;
        end 
    end
end
