classdef ImagingManager < Base.Manager
    
    properties
        set_colormap = 'gray';
        dumbimage = false;          % If true (useful for experiments), no ROI/crosshairs or listeners (only applies in CC)
    end
    properties(SetAccess={?ImagingManager,?StageManager})
        current_image = [];          % Handle to current SmartImage
    end
    properties(SetObservable,SetAccess=private,AbortSet)
        ROI                          % ROI of imaging device in real units
    end
    properties(Hidden)
        open_im_path = '.';
        climLock = false;
        climLow = 0;
        climHigh = 1000;
    end
    properties(SetAccess=private,Hidden)
        video_controls;       % Used to hold the listener for WindowMousePress
    end
    
    events
        image_taken
    end
    
    methods
        function obj = ImagingManager(handles)
            obj = obj@Base.Manager(Modules.Imaging.modules_package,handles,handles.panelImage,handles.image_select);
            obj.prefs = [obj.prefs {'set_colormap','open_im_path','climLock','climLow','climHigh','dumbimage'}];
            obj.loadPrefs;
            obj.blockOnLoad = handles.menu_imaging;
            set(handles.image_snap,'callback',@(~,~)obj.snap);
            set(handles.image_video,'callback',@obj.startVideo);
            set(handles.image_autofocus,'callback',@obj.autofocus);
            set(handles.clim_lock,'callback',@obj.climLockCB);
            set(handles.clim_low,'callback',@obj.climLowCB);
            set(handles.clim_high,'callback',@obj.climHighCB);
            set(handles.image_ROIreset,'callback',@obj.resetROI);
            set(handles.image_ROI,'CellEditCallback',@obj.roiCallback);
            set(handles.image_save,'ClickedCallback',@obj.save)
            colormap(obj.handles.figure1,obj.set_colormap)
            set(handles.clim_lock,'value',obj.climLock)  % Set to previous value
            set(handles.clim_low,'string',num2str(obj.climLow))
            set(handles.clim_high,'string',num2str(obj.climHigh))
            obj.climLockCB;                              % Update GUI
        end
        function delete(obj)
            if ~isempty(obj.active_module)&&obj.active_module.continuous
                obj.stopVideo;
            end
        end
        function cal = get_cal(obj)
            if isnumeric(obj.active_module.calibration)&&~isnan(obj.active_module.calibration)
                cal = obj.active_module.calibration;
            else
                err = sprintf('%s calibration property is not numeric (or is NaN). Please fix this. Using 1 for now',class(obj.active_module));
                obj.error(err)
                cal = 1;
            end
        end
        function load_im(obj,path)
            im = load(path);
            delete(obj.current_image)
            cla(obj.handles.axImage)
            obj.current_image = Base.SmartImage(im.image, obj.handles.axImage,...
                                                    obj.handles.Managers.Stages,...
                                                    obj.handles.Managers.MetaStage,...
                                                    obj.handles.Managers.Sources,...
                                                    obj, obj.dumbimage);
            if strcmp(obj.handles.colorbar_toggle.State,'on')
                % This leaves it permanently on after SmartImage replaces the temp image
                colorbar(obj.handles.axImage);
            end
        end
        function open_im(obj,path)
            im = load(path);
            newFig = figure('numbertitle','off','HandleVisibility','off');
            set(newFig,'name',sprintf('SmartImage %i',newFig.Number))
            NewAx = axes('parent',newFig);
            colormap(newFig,obj.set_colormap)
            try
                Base.SmartImage(im.image, NewAx,...
                                obj.handles.Managers.Stages,...
                                obj.handles.Managers.MetaStage,...
                                obj.handles.Managers.Sources,...
                                obj, obj.dumbimage);
            catch err
                delete(newFig)
                obj.error(sprintf('SmartImage could not open %s:\n%s',path,err.message))
            end
        end
        function path = get_im_path(obj)
            [fname,path] = uigetfile('*.mat','Open Image',obj.open_im_path);
            if fname
                obj.open_im_path = path;
                path = fullfile(path,fname);
            end
        end
        
        function calibrate(obj)
            % Simply click on either side of something
            instr = {'1. You will be asked to enter the size of an object.',...
                     '2. Click on either side the object with the size from step 1.',...
                     '3. Choose to keep or discard previous measurement.',...
                     '4. Continue with the current average calibration value or repeat'};
            uiwait(msgbox(strjoin(instr,'\n'),'Calibration Instructions','Help','modal'))
            % Open new window with image
            f = figure('WindowState','fullscreen');
            ax = axes('parent',f);
            im = findall(obj.handles.axImage,'type','Image');
            if isempty(im)
                delete(f)
                obj.error('You musth have an image on the axes! Take an image, then try again.')
                return
            end
            cdata = get(im,'cdata');
            x_ax = get(im,'xdata');
            y_ax = get(im,'ydata');
            imagesc(x_ax,y_ax,cdata,'parent',ax)
            colormap(ax,obj.set_colormap)
            axis(ax,'image')
            set(ax,'YDir','normal')
            finished = false;
            vals = [];
            while ~finished
                size = inputdlg('Size of object (um):','Object Size');
                if isempty(size)
                    delete(f)
                    obj.error('Calibration Aborted')
                    return
                end
                [x,y] = ginput(2);
                vals(end+1) = str2double(size{1})/sqrt(diff(x)^2+diff(y)^2);
                cal_info = {'Current calibration info:',...
                            sprintf('Number of samples: %i',numel(vals)),...
                            sprintf('Average: %f',mean(vals)),...
                            sprintf('Standard Deviation: %f',std(vals))};
                choice = questdlg(strjoin(cal_info,'\n'),'Calibration','Go Again','Finished','Cancel','Go Again');
                switch choice
                    case 'Finished'
                        finished = true;
                    case 'Cancel'
                        delete(f)
                        obj.error('Calibration Aborted')
                        return
                end
            end
            delete(f)
            cal = mean(vals);
            obj.active_module.calibration = obj.active_module.calibration*cal;
            obj.log('%s calibrated by user.',class(obj.active_module))
            % If this is the same as the stage, we update that as well (must be the last stage)
            if ~isempty(obj.active_module.uses_stage)
                stage = obj.handles.Managers.Stages.module_byString(obj.active_module.uses_stage);
                stage.calibration(1:2) = stage.calibration(1:2).*[cal cal];
                obj.handles.Managers.Stages.update_GUI_pos;   % Force GUI to update now
                obj.log('Calibrated %s as well.',class(stage))
            end
            obj.updateROI;
            msgbox(sprintf('Calibration Complete\nIt will take effect next time you take an image.'),'Calibration','Help','modal')
        end
        function updateROI(obj)
            if isempty(obj.active_module)
                dat = [NaN,NaN;NaN,NaN];
            else
                cal = obj.get_cal;
                dat = obj.active_module.ROI;
                obj.ROI = dat.*cal;
            end
            set(obj.handles.image_ROI,'data',obj.ROI)
        end
        function setROI(obj,roi)
            if ~isempty(obj.active_module)
            cal = obj.get_cal;
            try
                obj.active_module.ROI = roi./cal; % This should call updateROI from listener
            catch
                obj.updateROI;
            end
            end
        end
        function success = validate_frame(obj)
            success = true;
            try
                assert(~isempty(obj.active_module),'No module loaded.')
                validateattributes(obj.active_module.resolution,{'numeric'},{'integer','size',[1,2]},'snap','module resolution')
                validateattributes(obj.ROI,{'numeric'},{'nonnan','size',[2,2]},'snap','module ROI')
            catch err
                obj.error(err.message);
                success = false;
            end
        end
        function info = snap(obj,quietly)
            if ~obj.validate_frame()
                return
            end
            % quietly will silence the notification (preventing DBManager)
            if nargin < 2
                quietly = false;
            end
            % Returns the image for use in experiments
            obj.disable;
            if strcmp(get(obj.handles.panel_im,'visible'),'off')
                CommandCenter('axes_im_only_Callback',obj.handles.axes_im_only,[],guidata(obj.handles.axes_im_only))
            end
            if obj.active_module.continuous
               obj.stopVideo;
            end
            err = [];
            delete(obj.current_image)
            cla(obj.handles.axImage)
            x = [obj.ROI(1,1) obj.ROI(1,2)];
            y = [obj.ROI(2,1) obj.ROI(2,2)];
            temp = imagesc(x,y,NaN(fliplr(obj.active_module.resolution)),'parent',obj.handles.axImage,'tag','temp');
            axis(obj.handles.axImage,'image')
            set(obj.handles.axImage,'YDir','normal')
            if strcmp(obj.handles.colorbar_toggle.State,'on')
                % This shows the colorbar as the module populates the temp image
                colorbar(obj.handles.axImage);
            end
            try
                if ~isempty(obj.active_module.path) %if path defined, select path
                    obj.handles.Managers.Path.select_path(obj.active_module.path);
                end
                obj.sandboxed_function({obj.active_module,'snap'},temp);
                imPixels = get(temp,'cdata');
                % Use ImageManager default for obj.dumbimage.  This could be queried directly in SmartImage if that is better
                obj.current_image = Base.SmartImage(imPixels, obj.handles.axImage,...
                                                    obj.handles.Managers.Stages,...
                                                    obj.handles.Managers.MetaStage,...
                                                    obj.handles.Managers.Sources,...
                                                    obj, obj.dumbimage);
                
                if strcmp(obj.handles.colorbar_toggle.State,'on')
                    % This leaves it permanently on after SmartImage replaces the temp image
                    colorbar(obj.handles.axImage);
                end
                smartImage = obj.current_image;
                % Update some things
                if ~quietly
                    notify(obj,'image_taken')
                    obj.log('%s snapped image.',class(obj.active_module))
                end
            catch err
            end
            delete(temp);
            obj.enable;
            if ~isempty(err)
                rethrow(err)
            end
            info = smartImage.info;
        end
        
        % GUI callbacks
        function videoUpdate(obj,varargin)
            if obj.active_module.continuous
                set(obj.handles.image_video,'callback',@obj.stopVideo);
                set(obj.handles.image_video,'string','Stop')
                set([obj.handles.menu_imaging],'enable','off');
            else
                set(obj.handles.image_video,'callback',@obj.startVideo);
                set(obj.handles.image_video,'string','Continuous')
                set([obj.handles.menu_imaging],'enable','on');
            end
            drawnow expose;
        end
        function snapCallback(obj,varargin)
            obj.snap;
        end
        function startVideo(obj,varargin)
            if ~obj.validate_frame()
                return
            end
            % This counts as activitiy (override sandboxed_function)
            timerH = obj.handles.inactivity_timer;
            managers = timerH.UserData;
            managers.inactivity = false;
            stop(timerH);

            if strcmp(get(obj.handles.panel_im,'visible'),'off')
                CommandCenter('axes_im_only_Callback',obj.handles.axes_im_only,[],guidata(obj.handles.axes_im_only))
            end
            drawnow expose;
            delete(obj.current_image);
            obj.current_image = [];
            roi = obj.ROI;
            x = [roi(1,1) roi(1,2)];
            y = [roi(2,1) roi(2,2)];
            hImage = imagesc(x,y,NaN(fliplr(obj.active_module.resolution)),'parent',obj.handles.axImage);
            if strcmp(obj.handles.colorbar_toggle.State,'on')
                % This shows the colorbar as the module populates the temp image
                colorbar(obj.handles.axImage);
            end
            axis(obj.handles.axImage,'image')   % Need this line for startVideo fcn that don't return
            set(obj.handles.axImage,'YDir','normal')
            obj.video_controls = addlistener(obj.handles.figure1,'WindowMousePress',@obj.clicked);
            obj.video_controls(2) = addlistener(obj.handles.figure1,'WindowScrollWheel',@obj.scrolled);
            if obj.climLock
                low = str2double(get(obj.handles.clim_low,'string'));
                high = str2double(get(obj.handles.clim_high,'string'));
                set(obj.handles.axImage,'clim',[low high])
            end
            if ~isempty(obj.active_module.path) %if path defined, select path
                obj.handles.Managers.Path.select_path(obj.active_module.path);
            end
            obj.log('%s starting video.',class(obj.active_module))
            obj.sandboxed_function({obj.active_module,'startVideo'},hImage);
            axis(obj.handles.axImage,'image')
        end
        function stopVideo(obj,varargin)
            delete(obj.video_controls)
            obj.sandboxed_function({obj.active_module,'stopVideo'});
            obj.log('%s stopped video.',class(obj.active_module))
            
            % Restart activity
            start(obj.handles.inactivity_timer);
        end
        function clicked(obj,hObject,varargin)
            m_type = get(hObject,'selectionType');
            stage = obj.handles.Managers.Stages;
            if strcmp(m_type,'open')&&~isempty(stage.active_module)
                pos = get(obj.handles.axImage,'CurrentPoint');
                x = pos(1,1);
                y = pos(1,2);
                xlim = get(obj.handles.axImage,'xlim');
                ylim = get(obj.handles.axImage,'ylim');
                % Only when in axes limits
                if xlim(1)<x&&xlim(2)>x&&ylim(1)<y&&ylim(2)>y
                    if sum(isnan([x y]))
                        obj.error(sprintf('No stage active!\nCannot perform this move.'))
                        return
                    end
                    stage.jog([x y 0])
                end
            end
        end
        function scrolled(obj,~,event)
            C = get(obj.handles.axImage,'currentpoint');
            xlim = get(obj.handles.axImage,'xlim');
            ylim = get(obj.handles.axImage,'ylim');
            outX = any(diff([xlim(1) C(1,1) xlim(2)])<0);
            outY = any(diff([ylim(1) C(1,2) ylim(2)])<0);
            if ~(outX || outY)
                stage = obj.handles.Managers.Stages;
                if ~stage.moving
                    stage.jog([0 0 event.VerticalScrollCount*0.5])
                end
            end
        end
        function varargout = autofocus(obj,varargin)
            % Output is either nothing or metric or metric and time.
            obj.disable;
            delete(obj.current_image);
            err = [];
            try
                strt=tic;
                metric = obj.sandboxed_function({obj.active_module,'focus'},obj.handles.axImage,obj.handles.Managers);
                time = toc(strt);
            catch err
            end
            obj.enable;
            if ~isempty(err)
                rethrow(err)
            end
            if nargout == 1
                varargout = {metric};
            elseif nargout == 2
                varargout = {metric,time};
            else
                varargout = {};
            end
        end
        function climLowCB(obj,varargin)
            low = str2double(get(obj.handles.clim_low,'string'));
            if ~isempty(obj.active_module)&&obj.active_module.continuous
                high = str2double(get(obj.handles.clim_high,'string'));
                set(obj.handles.axImage,'clim',[low high])
            end
            obj.climLow = low;
        end
        function climHighCB(obj,varargin)
            high = str2double(get(obj.handles.clim_high,'string'));
            if ~isempty(obj.active_module)&&obj.active_module.continuous
                low = str2double(get(obj.handles.clim_low,'string'));
                set(obj.handles.axImage,'clim',[low high])
            end
            obj.climHigh = high;
        end
        function climLockCB(obj,varargin)
            val = get(obj.handles.clim_lock,'value');
            if val
                set([obj.handles.clim_low,obj.handles.clim_high],'enable','on')
            else
                set([obj.handles.clim_low,obj.handles.clim_high],'enable','off')
            end
            obj.climLock = val;
            if ~isempty(obj.active_module)&&obj.active_module.continuous
                if val
                    clim = get(obj.handles.axImage,'clim');
                    set(obj.handles.clim_low,'string',clim(1));
                    set(obj.handles.clim_high,'string',clim(2));
                    caxis(obj.handles.axImage,'manual')
                    set(obj.handles.axImage,'clim',clim)
                    obj.climLow = clim(1);
                    obj.climHigh = clim(2);
                else
                    caxis(obj.handles.axImage,'auto')
                end
            end
        end
        function resetROI(obj,varargin)
            dat = obj.active_module.maxROI;
            obj.active_module.ROI = dat;
            obj.updateROI;
        end
        function roiCallback(obj,varargin)
            hObj = obj.handles.image_ROI;
            roi = get(hObj,'data');
            obj.setROI(roi);
        end
        function save(obj,varargin)
            obj.error('DBManager did not set handle correctly!')
        end
    end
    methods(Access=protected)
        function active_module_changed(obj,varargin)
            obj.updateROI;
            if isempty(obj.active_module)
                set(obj.handles.Camera_Calibration,'enable','off')
            else
                set(obj.handles.Camera_Calibration,'enable','on')
                addlistener(obj.active_module,'ROI','PostSet',@(~,~)obj.updateROI);
                addlistener(obj.active_module,'continuous','PostSet',@obj.videoUpdate);
            end
        end
    end
    
end
