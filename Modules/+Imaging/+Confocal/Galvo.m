classdef Galvo < Modules.Imaging
    %CONFOCAL Control galvo mirrors and an APD to snap an image
    %   This is typically instantiated along side Stages.Galvos
    %
    %   ToDo: consolidate the calibration property into NIDAQ, so they
    %       can't accidentally be out of sync!
    
    properties
        maxROI = [-1.18 1.18; -1.18 1.18];
        prefs = {'dwell','resolution','ROI','use_z'};
        data_name = 'Confocal';                 % For diamondbase (via ImagingManager)
        data_type = 'General';                  % For diamondbase (via ImagingManager)
    end
    properties(SetObservable, GetObservable)
        resolution = Prefs.DoubleArray([120 120]);                 % Pixels
        ROI = Prefs.DoubleArray([-3 3;-3 3], 'set', 'set_ROI');                      % voltage
        continuous = false;
        dwell = Prefs.Double(1);                              % Per pixel in ms (will only update between frames)
        use_z = Prefs.Boolean(true);                           % To use z or to not use
    end
    properties(Access=private)
        counter_was_running = false;
    end
    properties(SetAccess=immutable)
        galvos              % Handle to galvo controller
        counter             % Handle to counter driver
    end
    
    methods(Access=private)
        function obj = Galvo()
            obj.uses_stage = 'Stages.Galvos';
            obj.path = 'APD1';
            obj.loadPrefs;
            if obj.use_z
                try
                    obj.galvos = Drivers.NIDAQ.stage.instance('X','Y','Z','APD1','GalvoScanSync');
                catch err
                    if ~isempty(strfind(err.message,'No line with name "Z".'))
                        answer = questdlg(sprintf('Continue without Z?\nYou can change later by unchecking in module settings.'),'NIDAQ','yes','no','yes');
                        if strcmp(answer,'yes')
                            obj.galvos = Drivers.NIDAQ.stage.instance('X','Y','','APD1','GalvoScanSync');
                            obj.use_z = false;
                        else
                            rethrow(err)
                        end
                    end
                end
            else
                obj.galvos = Drivers.NIDAQ.stage.instance('X','Y','','APD1','GalvoScanSync');
            end
            obj.counter = Drivers.Counter.instance('APD1','CounterSync');
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Confocal.Galvo();
            end
            obj = Object;
        end
    end
    methods
        function val = set_ROI(obj,val, ~)
            % Update ROI without going outside maxROI

            val(1,1) = max(obj.maxROI(1,1),val(1,1)); %#ok<*MCSUP>
            val(1,2) = min(obj.maxROI(1,2),val(1,2));
            val(2,1) = max(obj.maxROI(2,1),val(2,1));
            val(2,2) = min(obj.maxROI(2,2),val(2,2));
            % Now make sure no cross over
            val(1,2) = max(val(1,1),val(1,2));
            val(2,2) = max(val(2,1),val(2,2));
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
                obj.counter_was_running = obj.counter.running;
                if obj.counter_was_running
                    % If this is a continuous run, this is handled in startVideo
                    obj.counter.stop;
                end
                % If this is the same name as the modal figure already, it will replace it.
                h = msgbox('To stop scan, press abort.','ImagingManager','help','modal');
                h.KeyPressFcn='';  % Prevent esc from closing window
                h.CloseRequestFcn = @(~,~)obj.abort;
                % Repurpose the OKButton
                button = findobj(h,'tag','OKButton');
                % This silently aborts. Autosave will execute. Callback to
                % function that also throws error to avoid saving.
                set(button,'tag','AbortButton','string','Abort',...
                    'callback',@(~,~)obj.abort)
                drawnow;
            end
            obj.galvos.StartScan;
            try
                obj.galvos.StreamToImage(im);
            catch err
            end
            if ~continuous
                delete(h);
                if obj.counter_was_running
                    obj.counter.start;
                end
            end
            if exist('err','var')
                rethrow(err);
            end
        end
        function abort(obj)
            % Wrapper to make sure errors don't freeze window on screen
            try
                obj.galvos.AbortScan;
            catch err
                errordlg(getReport(err,'extended','hyperlinks','off'));
            end
        end
        function startVideo(obj,im)
            obj.continuous = true;
            obj.counter_was_running = obj.counter.running;
            if obj.counter_was_running
                obj.counter.stop;
            end
            while obj.continuous
                obj.snap(im,true)
            end
        end
        function stopVideo(obj)
            obj.continuous = false;
            if isvalid(obj.galvos.taskPulseTrain) && ...
                strcmp(obj.galvos.taskPulseTrain.status,'Started')
                obj.galvos.AbortScan;
            end
            if obj.counter_was_running
                obj.counter.start;
            end
        end
        
        % Settings and Callbacks
        function  settings(obj,panelH,~,~)
            spacing = 1.5;
            num_lines = 4;
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
        	line = 4;
            uicontrol(panelH,'style','checkbox','string','Use Z','horizontalalignment','right',...
                'units','characters','position',[2 spacing*(num_lines-line) 18 1.25],...
                'value',obj.use_z,'callback',@obj.use_zCallback);
           
        end
        function use_zCallback(obj,hObj,~)
            obj.use_z = get(hObj,'Value');
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

