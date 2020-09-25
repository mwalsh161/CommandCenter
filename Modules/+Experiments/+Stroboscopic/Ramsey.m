classdef Ramsey < Experiments.Stroboscopic.Stroboscopic_invisible
    %

    properties(SetObservable,AbortSet)
        mw_line =     Prefs.Integer(NaN, 'allow_nan', true, 'min', 1, 'max', 21, ...
                                        'help', 'PulseBlaster channel that the microwave switch is connected to. Experiment will not start if NaN.');
        mw_tau =      Prefs.Double(5, 'min', 0, 'unit', 'us', ...
                                        'help', 'Time between microwave pulses. Note that power is off at this time, unlike Stroboscopic.Rabi.');
        mw_pi2 =      Prefs.Double(5, 'min', 0, 'unit', 'us', ...
                                        'help', 'Time for a microwave pi/2 pulse.');
    end
    properties
%         pb;     % Handle to pulseblaster
%         s;      % Current pulsesequence.
%         f;      % Handle to the figure that displays the pulse sequence.
%         a;      % Handle to the axes that displays the pulse sequence.
    end
    methods(Static)
        function obj = instance(varargin)
            % This file is what locks the instance in memory such that singleton
            % can perform properly.
            % For the most part, varargin will be empty, but if you know what you
            % are doing, you can modify/use the input (just be aware of singleton_id)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Experiments.Stroboscopic.Ramsey.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(varargin,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Experiments.Stroboscopic.Ramsey(varargin{:});
            obj.singleton_id = varargin;
            Objects(end+1) = obj;
        end
    end
    methods
        function s = BuildPulseSequence(obj)
            s = sequence('Ramsey');

            pump =  channel('pump',     'color', 'g', 'hardware', obj.pump_line-1);
            mw =    channel('MW',       'color', 'b', 'hardware', obj.mw_line-1);

            s.channelOrder = [pump mw];

            g = s.StartNode;

            g = node(g, pump,   'delta', obj.pump_pre,  'units', 'us');
            g = node(g, pump,   'delta', obj.pump_tau,  'units', 'us');

            g = node(g, mw,     'delta', obj.pump_post, 'units', 'us'); % First pi/2 pulse
            g = node(g, mw,     'delta', obj.mw_pi2,    'units', 'us');
            g = node(g, mw,     'delta', obj.mw_tau,    'units', 'us'); % Second pi/2 pulse
                node(g, mw,     'delta', obj.mw_pi2,    'units', 'us');

            s.repeat = obj.samples;
        end
    end
    methods(Access=private)
        function obj = Ramsey()
            obj.loadPrefs;
        end
    end

    methods
    end
end
