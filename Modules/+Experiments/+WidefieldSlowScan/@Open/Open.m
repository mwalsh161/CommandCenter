classdef Open < Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible
    %Open Open-loop laser sweep for slowscan
    % Set freqs_THz, locks laser to each position (still records measured
    % value, but should be within resolution of the laser

    properties(SetObservable,AbortSet)
        percents = 'linspace(10,90,81)'; %eval(freqs_THz) will define freqs [scan_points]
    end
%     properties(Constant)
%         xlabel = 'Frequency (THz)';
%     end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = Open()
            obj.scan_points = eval(obj.percents);
            obj.prefs = [{'percents'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        function setLaser(obj, scan_point)
            if scan_point ~= 0  % Intentional for ClosedDAQ overload
                tries = 3;
                while tries > 0
                    try
                        obj.resLaser.TunePercent(scan_point);
                        break;
                    catch
                        warning(['Laser failed to tune to ' num2str(scan_point) ' %.'])
                    end
                    tries = tries - 1;
                end
                if tries == 0
                    error(['Laser failed thrice to tune to ' num2str(scan_point) ' %. Stopping run.'])
                end
            end
        end
        
        function set.percents(obj,val)
            obj.scan_points = str2num(val); %#ok<ST2NM> str2num uses eval but is more robust for numeric input
            obj.percents = val;
        end
    end
end
