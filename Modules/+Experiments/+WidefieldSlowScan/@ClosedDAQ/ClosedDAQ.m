classdef ClosedDAQ < Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible
    %Closed Closed-loop laser sweep for slowscan
    % Set freqs_THz, locks laser to each position (still records measured
    % value, but should be within resolution of the laser

    properties(GetObservable, SetObservable, AbortSet)
%         base_freq = Prefs.Double(470, 'unit', 'THz', 'set', 'calc_freqs',                       'help', 'The frequency that.');
%         base_percent = Prefs.Double(50, 'unit', '%', 'set', 'calc_freqs',                       'help', 'The percentage setting for the base frequency.');
        
        DAQ_dev = Prefs.String('Dev1',                                                          'help', 'NIDAQ Device.');
        DAQ_line = Prefs.String('laser',                                                        'help', 'NIDAQ virtual line.');
        
        from =  Prefs.Double(10, 'set', 'calc_freqs_from', 'min', 10, 'max', 90, 'unit', '%',   'help', 'Percentage value to scan from.');
        to =    Prefs.Double(90, 'set', 'calc_freqs_to', 'min', 10, 'max', 90, 'unit', '%',     'help', 'Percentage value to scan to.');
        
        overshoot = Prefs.Double(5, 'set', 'calc_freqs', 'min', 0, 'max', 10, 'unit', '%',      'help', 'To counteract hysteresis, we offset from by offshoot at the beginning of the scan.');
        
        step =  Prefs.Double(10, 'min', 0, 'unit', 'MHz',                                       'help', 'Step between points in the sweep. This is in MHz because sane units are sane.');
        
        Vrange = Prefs.Double(10, 'readonly', true, 'unit', 'V',                                'help', 'Max range that the DAQ can input on the laser. This is dangerous to change, so it is readonly for now.');
        V2GHz = Prefs.Double(2.5, 'unit', 'GHz/V',                                              'help', 'Conversion between voltage and GHz for the laser. This is only used to calculate freq_from and freq_to along with figuring out what step means.');
        
        freq_from = Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'THz',       'help', 'Calculated conversion between percent and THz for from.');
        freq_to =   Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'THz',       'help', 'Calculated conversion between percent and THz for to.');
        freq_range =Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'GHz',       'help', 'Calculated conversion between percent range and GHz range.');
        
        freq_calculate = Prefs.Boolean(false, 'set', 'calc_freqs');
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
            obj.prefs = [obj.prefs,{'DAQ_dev','DAQ_line','from','to','overshoot','step','Vrange','V2GHz'}];
            obj.loadPrefs; % Load prefs specified as obj.prefs
%             obj.get_scan_points();
        end
        
        function get_scan_points(obj)
            base_percent = obj.resLaser.GetPercent;
            
            stepTHz = obj.step/1e6; % Step is in MHz
            
            if obj.to > obj.from    % We are ascending
                overshoot_percent = obj.from - obj.overshoot;
            else                    % We are descending
                overshoot_percent = obj.from + obj.overshoot;
                
                stepTHz = -stepTHz;
            end
            
            assert(overshoot_percent >= 0 && overshoot_percent <= 100);                         % Make sure overshoot_percent is sane.
            
            obj.overshoot_voltage = (overshoot_percent - base_percent) * obj.Vrange / 100;  % And calculate the cooresponding voltage.
            
            rangeTHz = (obj.V2GHz * obj.Vrange / 1e3);
            stepPercent = 100 * stepTHz / rangeTHz;               % Convert step to percentage
            
            if obj.to > obj.from    % We are ascending
                stepPercent =  abs(stepPercent);
            else                    % We are descending
                stepPercent = -abs(stepPercent);
            end
            
            
%             stepPercent
%             obj.from
%             obj.to
            
            scan_percents = (obj.from:stepPercent:obj.to);    
            if scan_percents(end) ~= obj.to                 % If to isn't present...
                scan_percents(end + 1) = obj.to;            % ...add it.
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
            PreRun@Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible(obj, 0, managers, ax);
            
            obj.get_scan_points();
            
%             obj.resLaser.wavelength_lock = true;
            obj.resLaser.WavelengthLock(true);
            pause(.5);
%             obj.resLaser.wavelength_lock = false;
            obj.resLaser.WavelengthLock(false);
%             obj.resLaser.etalon_lock = false;
            
            obj.loadDAQ();
            obj.setLaser(obj.overshoot_voltage)
        end
        function loadDAQ(obj)
%             if ~isempty(obj.dev)
%                 delete(obj.dev)
%             end
            obj.dev = Drivers.NIDAQ.dev.instance(obj.DAQ_dev);
        end
        function setLaser(obj, scan_point)
            obj.dev.WriteAOLines(obj.DAQ_line, scan_point);
        end
    end

    methods
        function val = calc_freqs(obj, val, ~) %turn percent ranges into frequencies
            obj.freq_from = percent2THz(obj, obj.from);
            obj.freq_to = percent2THz(obj, obj.to);
            obj.freq_range = 1e3*(obj.freq_to - obj.freq_from); %thz to ghz
            
            val = false;
        end 
        function val = calc_freqs_from(obj, val, ~)
            obj.freq_from = percent2THz(obj, val);
            obj.freq_to = percent2THz(obj, obj.to);
            obj.freq_range = 1e3*(obj.freq_to - obj.freq_from); %thz to ghz
        end
        function val = calc_freqs_to(obj, val, ~) %turn percent ranges into frequencies
            obj.freq_from = percent2THz(obj, obj.from);
            obj.freq_to = percent2THz(obj, val);
            obj.freq_range = 1e3*(obj.freq_to - obj.freq_from); %thz to ghz
        end 
    end
end
