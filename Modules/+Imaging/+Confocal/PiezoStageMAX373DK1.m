classdef PiezoStageMAX373DK1 < Modules.Imaging
    %CONFOCAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        h %handle to abort button
        maxROI = [0 20; 0 20];
        dwell = 1;                              % Per pixel in ms (will only update between frames)
        prefs = {'dwell','resolution','ROI'};
        data_name = 'Confocal';                 % For diamondbase (via ImagingManager)
        data_type = 'General';                  % For diamondbase (via ImagingManager)
    end
    
    properties(SetObservable)
        resolution = [120 120];                 % Pixels
        ROI = [0 10;0 10];                      % voltage
        continuous = false;
        abort_flag = false;
    end
    
    properties(SetAccess=immutable)
        counter             % Handle to counter driver
        ni
        piezoStage
    end
    
    properties(Access=private)
        listeners
    end
  
    methods(Access=private)
        function obj = PiezoStageMAX373DK1()
            obj.uses_stage = 'Stages.MAX373DK1';
            obj.piezoStage = Stages.MAX373DK1.instance;
            obj.loadPrefs;
            obj.counter = Drivers.Counter.instance('APD1','CounterSync');
            obj.ni = Drivers.NIDAQ.dev.instance('Dev1');
           
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Confocal.PiezoStageMAX373DK1();
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
            error('Not Implemented.')
        end
        
        function snap(obj,im,continuous)
            obj.abort_flag = false;
            if nargin < 3
                continuous = false;
            end
            assert(strcmp(obj.piezoStage.piezoDriver.getLoopMode(1),'Closed'),[' Channel '...
                ' 1 must be set to closed loop mode to take an image.'])
            assert(strcmp(obj.piezoStage.piezoDriver.getLoopMode(2),'Closed'),[' Channel '...
                ' 2 must be set to closed loop mode to take an image.'])
            xres = obj.resolution(1);
            yres = obj.resolution(2);
            x = linspace(obj.ROI(1,1),obj.ROI(1,2),xres);
            y = linspace(obj.ROI(2,1),obj.ROI(2,2),yres);
            if ~continuous
                % If this is the same name as the modal figure already, it will replace it.
                obj.h = msgbox('To stop scan, press abort.','ImagingManager','help','modal');
                obj.h.KeyPressFcn='';  % Prevent esc from closing window
                % Repurpose the OKButton
                button = findall(obj.h,'tag','OKButton');
                % This silently aborts. Autosave will execute. Callback to
                % function that also throws error to avoid saving.
                set(button,'tag','AbortButton','string','Abort',...
                    'callback',@(~,~)obj.AbortScan)
                drawnow;
            end
            %sweep over x and y to make an image
            obj.counter.dwell =obj.dwell;
            ImageData = NaN(numel(y),numel(x));
            for xpos = 1:numel(x)
                for ypos = 1:numel(y)
                    if obj.abort_flag
                        return
                    end
                    obj.piezoStage.move(x(xpos),y(ypos),[])
                    ImageData(ypos,xpos) = obj.counter.singleShot(obj.dwell,1);
                    set(im,'cdata',ImageData)
                    pause(0.01)
                end
            end
            if ~continuous
                delete(obj.h);
            end
        end
        
        function startVideo(obj,im)
            obj.continuous = true;
            while obj.continuous
                obj.snap(im,true)
            end
        end
        
        function stopVideo(obj)
            obj.continuous = false;
            obj.abort_flag = true;
        end
        
        % Settings and Callbacks
        function settings(obj,panelH)
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
        
        function AbortScan(obj,~,~)
            obj.abort_flag = true;
            obj.continuous = false;
            delete(obj.h);
        end
        
        function StartCounterCallback(obj,varargin)
            obj.counter.start;
        end
        
    end
end


