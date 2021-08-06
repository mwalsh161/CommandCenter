classdef PicoHarp_histo < Modules.Experiment
    %Experimental wrapper for Drivers.PicoHarp300
    
    properties(SetObservable,AbortSet)
        picoharpH;
        data
        meta
        PH_serialNr = 'No device';
        PH_BaseResolution = 'No device';
        connection = false;
        Tacq_ms = 100; %ms
        MaxTime_s = 3600*10; %s
        MaxCounts = 10000;
        plot_x_max_ns = 200;
        SyncDivider = {uint8(1),uint8(2),uint8(4),uint8(8)};
        SyncOffset = 0; %ms
        Ch0_CFDzero = 10;% mV
        Ch0_CFDlevel = 50;% mV
        Ch1_CFDzero = 10;% mV
        Ch1_CFDlevel = 50;% mV
        Binning = num2cell(0:7); % Binning can be 0 to MAXBINSTEPS-1
        Session = num2cell(1:5);
        Waveguide = num2cell(16:10:96);
        PostSize = num2cell([100,112,125,137,150,162]);
        Offset = 0; %ms - still not sure what offset is this
        StopAtOverflow = true;
        OverflowCounts = 65535; %65535 is max value
        prefs = {'connection'};
        show_prefs = {'PH_serialNr','PH_BaseResolution','connection','MaxTime_s','MaxCounts','plot_x_max_ns','Session','Waveguide','PostSize','Binning','SyncDivider','SyncOffset','Ch0_CFDzero','Ch0_CFDlevel','Ch1_CFDzero','Ch1_CFDlevel','Tacq_ms','StopAtOverflow','OverflowCounts'};
        readonly_prefs = {'PH_serialNr','PH_BaseResolution'};
    end
    properties(SetAccess=private,Hidden)
        %picoharpH; %handle to PicoHarp300
        listeners;
        abort_request = false;
        acquiring = false;
    end
    methods(Access=private)
        function obj = PicoHarp_histo()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.PicoHarp_histo();
            end
            obj = Object;
        end
    end
    methods
        function run(obj,status,managers,ax)
            assert(~isempty(obj.picoharpH)&&isvalid(obj.picoharpH),'PicoHarp driver not intialized propertly.');
            assert(isnumeric(obj.SyncDivider),'SyncDivider not set.')
            assert(isnumeric(obj.Binning),'Binning not set.')
            
            status.String = 'Experiment started';
            obj.SetPHconfig;
            obj.data = [];
            obj.meta = [];
            obj.prepPlot(ax);
            obj.abort_request = false;
            obj.acquiring = true;
            drawnow;
            
            if obj.StopAtOverflow
                %acquisition loop
                t = tic;
                while obj.acquiring
                    status.String = sprintf('Elapsed Time: %0.2f',toc(t));
                    obj.picoharpH.PH_ClearHistMem;
                    obj.picoharpH.PH_StartMeas(obj.Tacq_ms);
                    while ~obj.picoharpH.PH_CTCStatus
                        pause(obj.Tacq_ms/1000/100);
                    end
                    obj.picoharpH.PH_StopMeas;
                    histdata = obj.picoharpH.PH_GetHistogram;
                    obj.data.y = obj.data.y + histdata;
                    ax.Children.YData = obj.data.y;
                    if toc(t)>obj.MaxTime_s || max(obj.data.y)>obj.MaxCounts || obj.abort_request
                        obj.acquiring = false;
                    end
                    if (bitand(uint32(obj.picoharpH.PH_GetFlags),obj.picoharpH.FLAG_OVERFLOW))
                        error('Acquistion Overflow. Consider reducing Tacq_ms');
                    end
                end
            else
                %acquisition loop
                t = tic;
                while obj.acquiring
                    status.String = sprintf('Elapsed Time: %0.2f',toc(t));
                    obj.picoharpH.PH_ClearHistMem;
                    obj.picoharpH.PH_StartMeas(obj.Tacq_ms);
                    while ~obj.picoharpH.PH_CTCStatus
                        pause(obj.Tacq_ms/1000/100);
                    end
                    obj.picoharpH.PH_StopMeas;
                    histdata = obj.picoharpH.PH_GetHistogram;
                    obj.data.y = obj.data.y + histdata;
                    ax.Children.YData = obj.data.y;
                    if toc(t)>obj.MaxTime_s || max(obj.data.y)>obj.MaxCounts || obj.abort_request
                        obj.acquiring = false;
                    end
                end
            end
        end
        
        function prepPlot(obj,ax)
            resolution = obj.picoharpH.PH_GetResolution;
            obj.meta.resolution = resolution;
            obj.data.x = uint32(resolution*[0:obj.picoharpH.HISTCHAN-1]);
            obj.data.y = uint32(zeros(1,obj.picoharpH.HISTCHAN));
            plot(ax,obj.data.x/1000,obj.data.y);
            set(ax,'YLim',[0 inf])
            if obj.plot_x_max_ns*1000<max(obj.data.x)
                set(ax,'XLim',[0 obj.plot_x_max_ns])
            else
                set(ax,'XLim',[0 max(obj.data.x)])
            end
            set(ax.XLabel,'String','Time (ns)')
            set(ax.YLabel,'String','Counts')
        end
        
        function SetPHconfig(obj)
            obj.picoharpH.PH_SetInputCFD(0,obj.Ch0_CFDlevel,obj.Ch0_CFDzero);
            obj.picoharpH.PH_SetInputCFD(1,obj.Ch1_CFDlevel,obj.Ch1_CFDzero);
            obj.picoharpH.PH_SetBinning(obj.Binning);
            obj.picoharpH.PH_SetStopOverflow(obj.StopAtOverflow,obj.OverflowCounts); %65535 is max value
            obj.picoharpH.PH_SetSyncOffset(obj.SyncOffset);
            obj.picoharpH.PH_SetSyncDiv(obj.SyncDivider);
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function dat = GetData(obj,~,~)
            dat = [];
            for i=1:length(obj.show_prefs)
                obj.meta = setfield(obj.meta,obj.show_prefs{i},getfield(obj,obj.show_prefs{i}));
            end
            obj.meta.PH_serialNr = obj.PH_serialNr
            
            dat.data = obj.data;
            dat.meta = obj.meta;
        end
             
        function delete(obj)
            if ~isempty(obj.picoharpH)
                obj.picoharpH.delete;
            end
            delete(obj.listeners);
        end
        
        % Experimental Set methods
        function set.connection(obj,val)
            if val
                obj.PH_serialNr = 'connecting...';
                drawnow;
                try
                    obj.picoharpH = Drivers.PicoHarp300.instance(1);
                catch err
                    obj.connection = false;
                    obj.PH_serialNr = 'No device';
                    rethrow(err)
                end
                obj.connection = true;
                obj.PH_serialNr = obj.picoharpH.SerialNr{1};
                obj.PH_BaseResolution = obj.picoharpH.PH_GetBaseResolution;
            elseif ~isempty(obj.picoharpH)
                obj.picoharpH.delete;
                obj.connection = false;
                obj.PH_serialNr = 'No device';
            end
        end
    end
end