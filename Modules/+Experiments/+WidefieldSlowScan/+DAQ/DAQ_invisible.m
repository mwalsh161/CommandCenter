classdef DAQ_invisible < Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible
    
    properties(GetObservable, SetObservable, AbortSet)
%         base_freq = Prefs.Double(470, 'unit', 'THz', 'set', 'calc_freqs',                       'help', 'The frequency that.');
%         base_percent = Prefs.Double(50, 'unit', '%', 'set', 'calc_freqs',                       'help', 'The percentage setting for the base frequency.');
        
        DAQ_dev = Prefs.String('Dev1',                                                          'help', 'NIDAQ Device.');
        DAQ_line = Prefs.String('laser',                                                        'help', 'NIDAQ virtual line.');
        
        slow_from =  Prefs.Double(10, 'set', 'calc_freqs_from', 'min', 10, 'max', 90, 'unit', '%',   'help', 'Percentage value to scan from.');
        slow_to =    Prefs.Double(90, 'set', 'calc_freqs_to', 'min', 10, 'max', 90, 'unit', '%',     'help', 'Percentage value to scan to.');
        
        slow_overshoot = Prefs.Double(5, 'set', 'calc_freqs', 'min', 0, 'max', 10, 'unit', '%',      'help', 'To counteract hysteresis, we offset slow_from by overshoot at the beginning of the scan.');
        
        slow_step =  Prefs.Double(10, 'min', 0, 'unit', 'MHz',                                       'help', 'Step between points in the sweep. This is in MHz because sane units are sane.');
        
        Vrange = Prefs.Double(10, 'readonly', true, 'unit', 'V',                                'help', 'Max range that the DAQ can input on the laser. This is dangerous to change, so it is readonly for now.');
        V2GHz = Prefs.Double(2.5, 'unit', 'GHz/V',                                              'help', 'Conversion between voltage and GHz for the laser. This is only used to calculate freq_from and freq_to along with figuring out what step means.');
        
        freq_from = Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'THz',       'help', 'Calculated conversion between percent and THz for slow_from.');
        freq_to =   Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'THz',       'help', 'Calculated conversion between percent and THz for slow_to.');
        freq_range =Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'GHz',       'help', 'Calculated conversion between percent range and GHz range.');
        
        freq_calculate = Prefs.Boolean(false, 'set', 'calc_freqs');
    end

    properties
        dev
        overshoot_voltage
    end

    methods(Access=protected)
        function obj = DAQ_invisible()
            obj.prefs = [obj.prefs,{'DAQ_dev','DAQ_line','slow_from','slow_to','slow_overshoot','slow_step','Vrange','V2GHz'}];
            obj.loadPrefs; % Load prefs specified as obj.prefs
%             obj.get_scan_points();
        end
        
        function get_scan_points(obj)
            base_percent = obj.resLaser.GetPercent;
            
            stepTHz = obj.slow_step/1e6; % obj.slow_step is in MHz
            
            if obj.slow_to > obj.slow_from  % We are ascending
                overshoot_percent = obj.slow_from - obj.slow_overshoot;
            else                            % We are descending
                overshoot_percent = obj.slow_from + obj.slow_overshoot;
                
                stepTHz = -stepTHz;
            end
            
            assert(overshoot_percent >= 0 && overshoot_percent <= 100);                         % Make sure overshoot_percent is sane.
            
            obj.overshoot_voltage = (overshoot_percent - base_percent) * obj.Vrange / 100;  % And calculate the cooresponding voltage.
            
            rangeTHz = (obj.V2GHz * obj.Vrange / 1e3);
            stepPercent = 100 * stepTHz / rangeTHz;               % Convert step to percentage
            
            if obj.slow_to > obj.slow_from    % We are ascending
                stepPercent =  abs(stepPercent);
            else                    % We are descending
                stepPercent = -abs(stepPercent);
            end
            
            scan_percents = (obj.slow_from:stepPercent:obj.slow_to);    
            if scan_percents(end) ~= obj.slow_to                 % If slow_to isn't present...
                scan_percents(end + 1) = obj.slow_to;            % ...add it.
            end
            
            assert(all(scan_percents >= 0 & scan_percents <= 100));                             % Make sure all these values are sane
            
            obj.scan_points = (scan_percents - base_percent) * obj.Vrange / 100;            % And calculate the cooresponding voltages.
        end
    end
    methods
        function THz = percent2THz(obj, percent)
            if isempty(obj.resLaser)
                base_percent = NaN;
            else
                base_percent = obj.resLaser.GetPercent;
            end
            
            THz = obj.resLaser.getFrequency - obj.V2GHz * obj.Vrange * (percent - base_percent) / 1e5;
        end
        function percent = THz2percent(obj, THz)
            if isempty(obj.resLaser)
                base_percent = NaN;
            else
                base_percent = obj.resLaser.GetPercent;
            end
            
            percent = - 1e5 * (THz - obj.resLaser.getFrequency) / (obj.V2GHz * obj.Vrange) + base_percent;
        end
        function PreRun(obj, ~, managers, ax)
            obj.get_scan_points();
            obj.loadDAQ();
            
%             obj.resLaser.WavelengthLock(true);
%             pause(.5);
%             obj.resLaser.WavelengthLock(false);
            
            PreRun@Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible(obj, 0, managers, ax);
            
            obj.setLaser(obj.overshoot_voltage)
        end
        function loadDAQ(obj)
            obj.dev = Drivers.NIDAQ.dev.instance(obj.DAQ_dev);
            obj.dev.ClearAllTasks();
        end
        function setLaser(obj, scan_point)
            obj.dev.WriteAOLines(obj.DAQ_line, scan_point);
        end
    end

    methods
        function val = calc_freqs(obj, val, ~) %turn percent ranges into frequencies
            obj.freq_from = percent2THz(obj, obj.slow_from);
            obj.freq_to = percent2THz(obj, obj.slow_to);
            obj.freq_range = 1e3*(obj.freq_to - obj.freq_from); %thz to ghz
            
            val = false;
        end 
        function val = calc_freqs_from(obj, val, ~)
            obj.freq_from = percent2THz(obj, val);
            obj.freq_to = percent2THz(obj, obj.slow_to);
            obj.freq_range = 1e3*(obj.freq_to - obj.freq_from); %thz to ghz
        end
        function val = calc_freqs_to(obj, val, ~) %turn percent ranges into frequencies
            obj.freq_from = percent2THz(obj, obj.slow_from);
            obj.freq_to = percent2THz(obj, val);
            obj.freq_range = 1e3*(obj.freq_to - obj.freq_from); %thz to ghz
        end 
    end
end
