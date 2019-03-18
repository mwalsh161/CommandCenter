classdef CollectionScan < Modules.Imaging
    %CONFOCAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        maxROI = [-1.18 1.18; -1.18 1.18];
        dwell = 1;                              % Per pixel in ms (will only update between frames)
        prefs = {'dwell','resolution','ROI'};
        data_name = 'Confocal';                 % For diamondbase (via ImagingManager)
        data_type = 'General';                  % For diamondbase (via ImagingManager)
    end
    properties(SetObservable)
        resolution = [120 120];                 % Pixels
        ROI = [-3 3;-3 3];                      % voltage
        continuous = false;
    end
    properties(SetAccess=immutable)
        galvos              % Handle to galvo controller
        counter             % Handle to counter driver
    end
    
    methods(Access=private)
        function obj = CollectionScan()
            obj.uses_stage = 'Stages.CollectionGalvos';
            obj.loadPrefs;
            obj.galvos = Drivers.NIDAQ.stage.instance('Xc','Yc','','APD1','GalvoScanSync');
            obj.counter = Drivers.Counter.instance('APD1','CounterSync');
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Confocal.CollectionScan();
            end
            obj = Object;
        end
    end
    methods
        function set.ROI(obj,val)
            % Update ROI without going outside maxROI
            val(1,1) = max(obj.maxROI(1,1),val(1,1)); %#ok<*MCSUP>
            val(1,2) = min(obj.maxROI(1,2),val(1,2));
            val(2,1) = max(obj.maxROI(2,1),val(2,1));
            val(2,2) = min(obj.maxROI(2,2),val(2,2));
            % Now make sure no cross over
            val(1,2) = max(val(1,1),val(1,2));
            val(2,2) = max(val(2,1),val(2,2));
            obj.ROI = val;
        end
        function focus(obj,ax,stageHandle)
        end
        function snap(obj,im,continuous)
            if nargin < 3
                continuous = false;
            end
            xres = obj.resolution(1);
            yres = obj.resolution(2);
            x = linspace(obj.ROI(1,1),obj.ROI(1,2),xres);
            y = linspace(obj.ROI(2,1),obj.ROI(2,2),yres);
            obj.galvos.SetupScan(x,y,obj.dwell)
            if ~continuous
                % If this is the same name as the modal figure already, it will replace it.
                h = msgbox('To stop scan, press abort.','ImagingManager','help','modal');
                h.KeyPressFcn='';  % Prevent esc from closing window
                h.CloseRequestFcn = @(~,~)obj.galvos.AbortScan;
                % Repurpose the OKButton
                button = findall(h,'tag','OKButton');
                % This silently aborts. Autosave will execute. Callback to
                % function that also throws error to avoid saving.
                set(button,'tag','AbortButton','string','Abort',...
                    'callback',@(~,~)obj.galvos.AbortScan)
                drawnow;
            end
            obj.galvos.StartScan;
            obj.galvos.StreamToImage(im)
            if ~continuous
                delete(h);
            end
        end
        function startVideo(obj,im)
            obj.continuous = true;
            while obj.continuous
                obj.snap(im,true)
            end
        end
        function stopVideo(obj)
            if strcmp(obj.galvos.taskPulseTrain.status,'Started')
                obj.galvos.AbortScan;
            end
            obj.continuous = false;
        end
        
        % Settings and Callbacks
        function settings(obj,panelH)
            spacing = 1.5;
            num_lines = 3;
            line = 1;
            uicontrol(panelH,'style','text','string','Dwell (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.dwell),...
                'units','characters','callback',@obj.dwellCallback,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 2;
            uicontrol(panelH,'style','text','string','X points (pixels):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.resolution(1)),'tag','x',...
                'units','characters','callback',@obj.resolutionCallback,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            uicontrol(panelH,'style','pushbutton','string','Counter',...
                'units','characters','position',[32 spacing*(num_lines-line) 10 3],...
                'callback',@obj.StartCounterCallback)
            line = 3;
            uicontrol(panelH,'style','text','string','Y points (pixels):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.resolution(2)),'tag','y',...
                'units','characters','callback',@obj.resolutionCallback,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
        end
        function dwellCallback(obj,hObj,varargin)
            val = str2double((get(hObj,'string')));
            obj.dwell = val;
        end
        function resolutionCallback(obj,hObj,~)
            val = str2double((get(hObj,'string')));
            if strcmp(get(hObj,'tag'),'x')
                pos = 1;
            else
                pos = 2;
            end
            obj.resolution(pos) = val;
        end
        function StartCounterCallback(obj,varargin)
            obj.counter.start;
        end
    end
    
end

