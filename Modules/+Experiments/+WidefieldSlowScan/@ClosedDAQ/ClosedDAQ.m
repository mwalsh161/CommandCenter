classdef ClosedDAQ < Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible
    %Closed Closed-loop laser sweep for slowscan
    % Set freqs_THz, locks laser to each position (still records measured
    % value, but should be within resolution of the laser

    properties(SetObservable,AbortSet)
        Base_Frequency = Prefs.Double(470, 'unit', 'THz',   'help', 'The frequency that.');
        Base_Etalon = Prefs.Double(50, 'unit', '%',         'help', 'The etalon setting for the base frequency.');
        
        DAQ_dev = Prefs.String('Dev1',                      'help', 'NIDAQ Device.');
        DAQ_line = Prefs.String('laser',                    'help', 'NIDAQ virtual line.');
        
        from =  Prefs.Double(10, 'set', 'calc_freqs', 'min', 10, 'max', 90, 'unit', '%', 'help', 'Percentage value to scan from.');
        to =    Prefs.Double(90, 'set', 'calc_freqs', 'min', 10, 'max', 90, 'unit', '%', 'help', 'Percentage value to scan to.');
        
        overshoot = Prefs.Double(5, 'set', 'calc_freqs', 'min', 0, 'max', 10, 'unit', '%', 'To counteract hysteresis, we offset from by offshoot at the beginning of the scan.');
        
        step =  Prefs.Double(10, 'min', 0, 'MHz', 'help', 'Step This is in MHz because sane units are sane.');
        
        Vrange = Prefs.Double(10, 'readonly', 'unit', 'V', 'help', 'Max range that the DAQ can input on the laser.');
        V2GHz = Prefs.Double(2.5, 'readonly', 'unit', 'GHz/V', 'help');
        
        freq_from = Prefs.Double(NaN, 'allow_nan', true, 'readonly', 'unit', 'THz');
        freq_to =   Prefs.Double(NaN, 'allow_nan', true, 'readonly', 'unit', 'THz');
    end
%     properties(Constant)
%         xlabel = 'Frequency (THz)';
%     end

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
            obj.dev = Drivers.NIDAQ.dev(obj.DAQ_dev);
            obj.loadPrefs; % Load prefs specified as obj.prefs
            obj.get_scan_points();
        end
        
        function setLaser(obj, index)
            obj.dev.WriteAOLines(obj.name, obj.scan_points(index));
        end
        
        function get_scan_points(obj)
            stepTHz = obj.step/1e6;
            
            if obj.to > obj.from    % We are ascending
                overshoot_percent = obj.from - obj.overshoot;
            else                    % We are descending
                overshoot_percent = obj.from + obj.overshoot;
                
                stepTHz = -stepTHz;
            end
            
            assert(overshoot_percent >= 0 && overshoot_percent <= 100);
            
            obj.overshoot_voltage = (overshoot_percent - obj.Base_Etalon) * obj.Vrange / 100;
            
            rangeTHz = (obj.V2GHz * obj.Vrange / 1e3);
            stepPercent = stepTHz / rangeTHz;
            
            scan_percents = obj.from:stepPercent:obj.to;
            if scan_percents(end) ~= obj.to
                scan_percents(end + 1) = obj.to;
            end
            
            assert(all(scan_percents >= 0 & scan_percents <= 100));
            
            obj.scan_points = (scan_percents - obj.Base_Etalon) * obj.Vrange / 100;
        end
        
        function THz = percent2THz(obj, percent)
            THz = obj.V2GHz * obj.Vrange * (percent - obj.Base_Etalon);
        end
    end

    methods
    end
end
