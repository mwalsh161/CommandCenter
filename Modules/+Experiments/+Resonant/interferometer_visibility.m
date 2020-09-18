classdef interferometer_visibility < Modules.Experiment
    %TESTQR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        start = -2.3;   % Starting voltage
        stop = 2.3;     % Stopping voltage
        npoints = 2000; % Number of points between start and stop
        dwell = 1;      % ms at each one of npoints
        APD_line = 'APD1'; % APD line name (for counter)
        data;
        prefs = {'start','stop','npoints','dwell'};
        darks;
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        reset = false;          % Reset plots during aquisition
        ni;                     % NIDAQ handle
        counter;                % APD counter
        rl;                     % red laser
    end
    
    methods(Access=private)
        function obj = interferometer_visibility()
            obj.loadPrefs;
            obj.ni = Drivers.NIDAQ.dev.instance('dev1');
            obj.counter = Drivers.Counter.instance(obj.APD_line,'CounterSync');
            obj.rl = Sources.VelocityLaser.instance();
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Resonant.interferometer_visibility();
            end
            obj = Object;
        end
    end
    methods
        function darkCounts(obj)
            obj.rl.off;
            obj.darks = obj.counter.singleShot(1,1);
            obj.darks
        end
        function [v,y] = visibilityOnePeriod(obj,y)
            S=floor(length(y)/10);
            y=smooth(y,S);
            v=(max(y)-min(y))/(max(y)+min(y));
        end
        function y = extractLastPeriod(obj,y_raw,fft_plot)
            L = length(y_raw);
            f = 1/2*(1:L/2)/(L/2);
            Y = fft(y_raw-mean(y_raw));
            [~,loc] = max(abs(Y(1:numel(f))));
            period = round(1/f(loc));
            if period <= 10 || period*5 >= L
                y = [];
                %set(fft_plot,'xdata',f,'ydata',abs(Y(1:floor(L/2))),'color','r');
            else
                y = y_raw(end-period*3:end);
                set(fft_plot,'xdata',f,'ydata',abs(Y(1:floor(L/2))),'color','b');
                title(fft_plot.Parent,sprintf('FFT max %0.4f',f(loc)))
            end
            set(fft_plot.Parent,'xlim',[0 0.5]);
        end

        function run(obj,statusH,managers,ax)
            obj.abort_request = false;
            obj.reset = false;
            obj.data.stream = [];  % Will store all data
            obj.data.visibility = [];
            tempData.stream = [];  % Stores plot data
            tempData.visibility = [];
            obj.rl.arm;
            % Setup Infinite scan
            obj.darkCounts;
            set(statusH,'string','Setting up NIDAQ tasks...'); drawnow;
            voltages = linspace(obj.start,obj.stop,obj.npoints);
            voltages = [voltages linspace(obj.stop,obj.start,obj.npoints)]';
            dwellTime = obj.dwell/1000; % ms to s
            freq = 1/dwellTime;
            PulseTrain = obj.ni.CreateTask('LaserScanTrain');
            try
                PulseTrain.ConfigurePulseTrainOut('GalvoScanSync',freq,0);
            catch err
                PulseTrain.Clear
                rethrow(err)
            end
            Scan = obj.ni.CreateTask('LaserScan');
            try
                Scan.ConfigureVoltageOut('LaserFreq',voltages,PulseTrain,true);
            catch err
                PulseTrain.Clear;
                Scan.Clear;
                rethrow(err)
            end
            Counter = obj.ni.CreateTask('LaserScanCounter');
            try
                Counter.ConfigureCounterIn(obj.APD_line,obj.npoints*2,PulseTrain,true);
            catch err
                PulseTrain.Clear;
                Scan.Clear;
                Counter.Clear;
                rethrow(err)
            end
            % Start everything up
            obj.rl.on;
            Counter.Start;
            Scan.Start;
            PulseTrain.Start;
            % Stream data
            set(statusH,'string','Streaming Data, abort to stop.'); drawnow;
            err = [];
            % Prepare plots
            panel = ax.Parent;
            delete(ax);
            ax1 = subplot(2,2,1,'parent',panel);
            ax2 = subplot(2,2,2,'parent',panel);
            ax3 = subplot(2,2,[3 4],'parent',panel);
            p1 = plot(ax1,NaN,NaN,'tag','data_stream');
            p2 = plot(ax2,NaN,NaN,'tag','FFT');
            p4 = plot(ax3,NaN,NaN,'tag','visibility');
            ylabel(ax1,'APD Counts');
            ylabel(ax3,'Visibility');
            title(ax2,'FFT')
            hold(ax1,'on');
            data_period = [];
            i = 0;
            cs = 'rm';
            % Add reset button for plots
            uicontrol(statusH.Parent.Parent,'style','pushbutton','string','Reset',...
                'callback',@obj.resetPlots);
            try
            while isvalid(Counter)&&~obj.abort_request
                SampsAvail = Counter.AvailableSamples;
                if SampsAvail > 2  % Two because diff is taken immediately
                    counts = diff(double(Counter.ReadCounter(SampsAvail)));
                    obj.data.stream = [obj.data.stream counts];
                    tempData.stream = [tempData.stream counts];
                    data_period = [data_period counts];
                    last_period = obj.extractLastPeriod(data_period,p2);
                    L = length(tempData.stream);
                    set(p1,'ydata',tempData.stream,'xdata',1:L);
                    if last_period > 0
                        [vis,smoothed] = obj.visibilityOnePeriod(last_period);
                        obj.data.visibility = [obj.data.visibility vis];
                        tempData.visibility = [tempData.visibility vis];
                        set(p4,'ydata',tempData.visibility,'xdata',1:length(tempData.visibility));
                        % Alternate color to distinguish separate calculations
                        plot(ax1,L-length(smoothed)+1:L,smoothed,[cs(i+1) '-'],'linewidth',1.5,'tag','smoothed');
                        i = not(i);
                        title(ax1,sprintf('Visibility: %0.2f%%',vis))
                        data_period = [];
                    end
                end
                drawnow;
                if obj.reset
                    delete(findall(ax1,'tag','smoothed'));
                    tempData.stream = [];
                    tempData.visibility = [];
                    obj.reset = false;
                end
            end
            catch err
            end
            % Clean up
            PulseTrain.Clear;
            Scan.Clear;
            Counter.Clear
            obj.ni.WriteAOLines('LaserFreq',0);
            obj.rl.off;
            if ~isempty(err)
                rethrow(err);
            end
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,StageManager,ImagingManager)
            data = obj.data;
        end
        
        function resetPlots(obj,~,~)
            obj.reset = true;
        end
        function  settings(obj,panelH,~,~)
            spacing = 1.75;
            num_lines = 3;
            line = 1;
            uicontrol(panelH,'style','text','string','Start (V):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 10 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.start),...
                'units','characters','callback',@obj.startstopCallback,...
                'horizontalalignment','left','position',[11 spacing*(num_lines-line) 10 1.5],'tag','start');
            uicontrol(panelH,'style','text','string','Stop (V):','horizontalalignment','right',...
                'units','characters','position',[22 spacing*(num_lines-line) 10 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.stop),...
                'units','characters','callback',@obj.startstopCallback,...
                'horizontalalignment','left','position',[35 spacing*(num_lines-line) 10 1.5],'tag','stop');
            line = 2;
            uicontrol(panelH,'style','text','string','npoints:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 10 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.npoints),...
                'units','characters','callback',@obj.scanAttrCallback,...
                'horizontalalignment','left','position',[11 spacing*(num_lines-line) 10 1.5],'tag','npoints');
            uicontrol(panelH,'style','text','string','Dwell (ms):','horizontalalignment','right',...
                'units','characters','position',[22 spacing*(num_lines-line) 12 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.dwell),...
                'units','characters','callback',@obj.scanAttrCallback,...
                'horizontalalignment','left','position',[35 spacing*(num_lines-line) 10 1.5],'tag','dwell');
            line = 3;
            uicontrol(panelH,'style','text','string','APD line:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 10 1.25]);
            opts = {obj.ni.InLines.name};
            uicontrol(panelH,'style','popup','string',opts,...
                'units','characters','callback',@obj.apdCallback,...
                'horizontalalignment','left','position',[11 spacing*(num_lines-line) 20 1.75]);
            uicontrol(panelH,'style','pushbutton','string','Add line',...
                'units','characters','position',[34 spacing*(num_lines-line) 10 1.75],...
                'callback',@obj.openViewCallback);
        end
        function startstopCallback(obj,hObj,~)
            val = str2double(get(hObj,'string'));
            if abs(val) <= 2.3
                obj.(get(hObj,'tag')) = val;
            else
                set(hObj,'string',num2str(obj.(get(hObj,'tag'))))
                error('Must be between -2.3 and 2.3 V');
            end
            set(hObj,'string',num2str(obj.(get(hObj,'tag'))))
        end
        function scanAttrCallback(obj,hObj,~)
            val = str2double(get(hObj,'string'));
            obj.(get(hObj,'tag')) = val;
            set(hObj,'string',num2str(obj.(get(hObj,'tag'))))
        end
        function apdCallback(obj,hObj,~)
            opts = get(hObj,'string');
            val = get(hObj,'Value');
            obj.APD_line = opts{val};
        end
        function openViewCallback(obj,~,~)
            obj.ni.view
        end
    end
    
end

