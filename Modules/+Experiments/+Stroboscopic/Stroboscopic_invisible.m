classdef Stroboscopic_invisible < Modules.Experiment
    %

    properties(SetObservable,AbortSet)
        PB_host =       Prefs.String(Experiments.Stroboscopic.Stroboscopic_invisible.noserver, 'set', 'set_PB_host', 'help', 'IP/hostname of computer with PB server');

        samples =       Prefs.Integer(1, 'min', 1);
        time =          Prefs.Double(1, 'min', 1, 'unit', 's', 'read_only', true);

        render =        Prefs.Boolean(false, 'set', 'set_render');

        image =         Prefs.ModuleInstance('inherits', {'Modules.Imaging'});
        image_line =    Prefs.Integer(NaN, 'allow_nan', true, 'min', 1, 'max', 21, ...
                                        'help', 'PulseBlaster channel that triggers the camera. Unused if NaN.');

        image_pre =     Prefs.Double(0, 'min', 0, 'unit', 'ms');
        image_post =    Prefs.Double(0, 'min', 0, 'unit', 'ms');

        pump_line =     Prefs.Integer(NaN, 'allow_nan', true, 'min', 1, 'max', 21, ...
                                        'help', 'PulseBlaster channel that the pump modulator is connected to. Experiment will not start if NaN.');
        pump_tau =      Prefs.Double(5, 'min', 0, 'unit', 'us', ...
                                        'help', 'Time that the pump is on. Increasing tau increases intialization fidelity, yet decreases SNR.');
        pump_pre =      Prefs.Double(1, 'min', 0, 'unit', 'us', ...
                                        'help', 'Padding before the pump seperating it from any other pulses.');
        pump_post =     Prefs.Double(1, 'min', 0, 'unit', 'us', ...
                                        'help', 'Padding after the pump seperating it from any other pulses.');
    end
    properties
        pb;     % Handle to pulseblaster
        s;      % Current pulsesequence.
        f;      % Handle to the figure that displays the pulse sequence.
        a;      % Handle to the axes that displays the pulse sequence.
    end
    properties(Constant, Hidden)
        noserver = 'No Server';
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
                Objects = Experiments.Stroboscopic.Stroboscopic_invisible.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(varargin,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Experiments.Stroboscopic.Stroboscopic_invisible(varargin{:});
            obj.singleton_id = varargin;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = Stroboscopic_invisible()
            obj.loadPrefs;
        end
    end
    methods(Abstract)
        seq = BuildPulseSequence(obj)
    end
    methods
        function delete(obj)
            delete(obj.a);
            delete(obj.f);
        end
        function val = set_render(obj, val, ~)
            if isempty(obj.f) || ~isvalid(obj.f)
                obj.f = figure;
                obj.a = axes(obj.f);
            else

            end

            obj.s = obj.BuildPulseSequence();
            obj.s.simulate(obj.a);

            val = false;
        end

        function val = set_PB_host(obj,val,~)
            err = [];

            try
                obj.pb = Drivers.PulseBlaster.StaticLines.instance(val);
            catch err

            end

            if isempty(obj.pb)
                obj.PB_host = obj.noserver;
                if ~isempty(err)
                    rethrow(err)
                end
                return
            end
            if ~isempty(err)
                rethrow(err)
            end

            obj.source_on = obj.pb.lines(obj.PB_line);
        end
        function run(obj, status, managers, ax)
            obj.s = obj.BuildPulseSequence();
            prog = obj.s.compile();

            obj.pb
        end
%         function PreRun(obj,~,~,ax)
%             %prepare axes for plotting
%             hold(ax,'on');
%             %plot data bin 1
%             plotH = plot(ax,obj.tauTimes,obj.data.sumCounts(:,1,1),'color','b');
%             %plot data bin 1 errors
%             plotH(2) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,1,1)+obj.data.stdCounts(:,1,1),'color',[1 .5 0],'LineStyle','--'); %upper bound
%             plotH(3) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,1,1)-obj.data.stdCounts(:,1,1),'color',[1 .5 0],'LineStyle','--'); %lower bound
%             %plot data bin 2
%             plotH(4) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,2,1),'color','b');
%             %plot data bin 2 errors
%             plotH(5) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,2,1)+obj.data.stdCounts(:,2,1),'color',[1 .5 0],'LineStyle','--'); %upper bound
%             plotH(6) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,2,1)-obj.data.stdCounts(:,2,1),'color',[1 .5 0],'LineStyle','--'); %lower bound
%             ax.UserData.plots = plotH;
%             ylabel(ax,'Normalized PL');
%             xlabel(ax,'Delay Time \tau (\mus)');
%             hold(ax,'off');
%             set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
%         end
%
%         function UpdateRun(obj,~,~,ax,~,~)
%             if obj.averages > 1
%                 averagedData = squeeze(nanmean(obj.data.sumCounts,3));
%                 meanError = squeeze(nanmean(obj.data.stdCounts,3));
%             else
%                 averagedData = obj.data.sumCounts;
%                 meanError = obj.data.stdCounts;
%             end
%
%             %grab handles to data from axes plotted in PreRun
%             ax.UserData.plots(1).YData = averagedData(:,1);
%             ax.UserData.plots(2).YData = averagedData(:,1) + meanError(:,1);
%             ax.UserData.plots(3).YData = averagedData(:,1) - meanError(:,1);
%             ax.UserData.plots(4).YData = averagedData(:,2);
%             ax.UserData.plots(5).YData = averagedData(:,2) + meanError(:,2);
%             ax.UserData.plots(6).YData = averagedData(:,2) - meanError(:,2);
%             drawnow;
%         end
    end
end
