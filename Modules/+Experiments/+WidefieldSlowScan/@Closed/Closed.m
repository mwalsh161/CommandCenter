classdef Closed < Experiments.WidefieldSlowScan.WidefieldSlowScan_invisible
    %Closed Closed-loop laser sweep for slowscan
    % Set freqs_THz, locks laser to each position (still records measured
    % value, but should be within resolution of the laser

    properties(SetObservable,AbortSet)
        freqs_THz = '470+linspace(-10,10,101)'; %eval(freqs_THz) will define freqs [scan_points]
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
        function obj = Closed()
            obj.scan_points = eval(obj.freqs_THz);
            obj.prefs = [{'freqs_THz'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        function set.freqs_THz(obj,val)
            obj.scan_points = str2num(val); %#ok<ST2NM> str2num uses eval but is more robust for numeric input
            obj.freqs_THz = val;
        end
    end
end
