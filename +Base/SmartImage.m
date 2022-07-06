classdef SmartImage < handle
    %SMARTIMAGE Contains smart set of axes, and position info
    %   Uses the appropriate listeners for StageManager and ImageManager to
    %   show the current position of the stage in relation to the picture.
    %
    %   Callbacks for double-clicking to position stage at that location.
    %   Draggable frame to adjust the current ROI in relation to the image.
    %
    %   Stores a structure with original picture information (stage, and
    %   ROI). This information is immutable.
    
    properties
        crosshairVisible = 'on';% Crosshairs visibile or not ('on','off')
        ROIVisible = 'on';      % ROI rectangle visible or not ('on','off')
        translate = 'off';      % Determines if patch has HitTest
    end
    properties(Access=private)
        ax                      % Handle to axis
        stage                   % Handle to stage manager
        metastage               % Handle to metastage manager
        imager                  % Handle to imaging manager
        imageH                  % Handle to image object
        contextmenu             % Handle to contextmenu for this image
        ROIMenu                 % Handle to child of context menu
        crosshairMenu           % Handle to child of context menu
        crosshairs              % (x,y) handles to both line objects.
        roiRect                 % Handle to imrect for ROI
        listeners               % Listeners to stage pos and imager ROI
    end
    properties(SetAccess=immutable)
        % Permanent image information.
        %   Image is a NxM matrix with the raw data.
        %   globalPos reflects the center of the image position.
        %   stage is the list of active stages
        %   ROI reflects the x and y information of the image
        %   ModuleInfo is a struct that includes the module name used to acquire the image, and any public properites.
        info = struct('image',{},...
                      'globalPos',{},'stage',{},'realPos',{},...
                      'ROI',{},'ModuleInfo',{});
        Parent
    end
    
    methods(Static)
        function info = extractModuleSettings(module)
            % Gather all public properites into one structure that aren't objects
            props = properties(module);
            for i = 1:numel(props)
                if ~isobject(module.(props{i}))
                    info.(props{i}) = module.(props{i});
                end
            end
            info.module = class(module);
        end
        function stages = get_modules_str(info)
            % Returns same as the stageManager.get_modules_str (but starts with info struct)
            n = length(info.stages);
            stages = cell(1,n);
            for i = 1:n
                stages{i} = info.stages(i).ModuleInfo.module;
            end
        end
    end
    methods
        function obj = SmartImage(firstInp,ax,stage, metastage,source,imager,dumbimage)
            % The first input can either be the image cdata, or the info from another SmartImage
            % stage -> stage manager
            % source -> source manager
            % imager -> imaging manager
            % dumbimage -> boolean
            if nargin < 6
                dumbimage = false;
            end
            obj.stage = stage;
            obj.metastage = metastage;
            obj.imager = imager;
            if isa(firstInp,'struct')
                obj.info = firstInp;
            else
                % Create info struct
                info.image = firstInp;
                info.globalPos = obj.getGlobalPosition;
                stages = struct('position',[],'ModuleInfo',cell(1,numel(stage.modules)));
                for i = 1:numel(stage.modules)
                    tempModule = stage.modules{i};
                    stages(i).ModuleInfo = obj.extractModuleSettings(tempModule); % This will contain uncalibrated position, and calibration factor
                    stages(i).position = tempModule.getCalibratedPosition;
                end
                info.stages = stages;
                sources = struct('ModuleInfo',cell(1,numel(stage.modules)));
                for i = 1:numel(source.modules)
                    tempModule = source.modules{i};
                    sources(i).ModuleInfo = obj.extractModuleSettings(tempModule);
                end
                info.sources = sources;
                info.ROI = imager.ROI;
                info.ModuleInfo = obj.extractModuleSettings(imager.active_module);
                obj.info = info;
            end
            obj.ax = ax;
            obj.Parent = ax;
            % Create Image on ax
            roi = obj.info.ROI;
            x = [roi(1,1) roi(1,2)];
            y = [roi(2,1) roi(2,2)];
            obj.imageH = imagesc(x,y,obj.info.image,'parent',ax,'hittest','off','tag',mfilename);
            obj.imageH.UserData = obj;
            axis(ax,'image');
            set(ax,'YDir','normal');
            
            % Lowest context menu
            fig = Base.getParentFigure(ax);
            obj.contextmenu = uicontextmenu(fig);
            uimenu(obj.contextmenu,'Label','Adjust Brightness/Contrast','Callback',@obj.contrast);
            uimenu(obj.contextmenu,'Label','Popout','Callback',@obj.popout);
            obj.listeners = addlistener(ax,'ObjectBeingDestroyed',@obj.delete);
            set(ax,'uicontextmenu',obj.contextmenu);
            
            if dumbimage
                return
            end
            roi = obj.imager.ROI;
            xmin = roi(1,1);
            xmax = roi(1,2);
            ymin = roi(2,1);
            ymax = roi(2,2);

            % Create Crosshairs
            hold(ax,'on');
            if isequal(obj.get_modules_str(obj.info),stage.get_modules_str)
                pos = stage.position-obj.info.globalPos;
            else
                pos = NaN(1,2);
            end
            if pos(1) < xmin || pos(1) > xmax
                pos(1) = NaN;
            end
            if pos(2) < ymin || pos(2) > ymax
                pos(2) = NaN;
            end
            xlim = get(ax,'xlim');
            xlim(1) = min(xlim(1),xmin); xlim(2) = max(xlim(2),xmax);
            ylim = get(ax,'ylim');
            ylim(1) = min(ylim(1),ymin); ylim(2) = max(ylim(2),ymax);
            obj.crosshairs = plot(ax,[pos(1) pos(1)],ylim,'b','HitTest','off');
            obj.crosshairs(2) = plot(ax,xlim,[pos(2) pos(2)],'b','HitTest','off');
            hold(ax,'off');
            
            % Create ROI
            obj.roiRect = imrect(ax,[xmin,ymin,xmax-xmin,ymax-ymin]);
            obj.roiRect.Deletable = false;
            obj.roiRect.setColor('r');
            obj.roiRect.setPositionConstraintFcn(@obj.constrainROI);
            % Replace ButtonDownFcn to also implement our callback!
            roiGroup = findall(ax,'tag','imrect');
            for i = 1:length(roiGroup.Children)
                callback = roiGroup.Children(i).ButtonDownFcn;
                roiGroup.Children(i).ButtonDownFcn = @(a,b)obj.prepROI(a,b,callback);
            end
            
            % Add listeners
            obj.listeners(2) = addlistener(imager,'ROI','PostSet',@obj.updateROI);
            obj.listeners(3) = addlistener(stage,'newPosition',@obj.updatePos);
            obj.listeners(4) = addlistener(metastage, 'updated', @obj.updatePos);
            % Set up remaining contextmenus (note obj.contextmenu = axes, parent = imrect stuff)
            obj.ROIMenu = uimenu(obj.contextmenu,'Label','ROI Visible','Callback',@obj.visCallback,'checked','on','UserData','ROI','tag','smartimage');
            obj.crosshairMenu = uimenu(obj.contextmenu,'Label','CrossHair Visible','Callback',@obj.visCallback,'checked','on','UserData','crosshair','tag','smartimage');
            uimenu(obj.contextmenu,'Label','Use image''s ROI','Callback',@obj.useROI,'tag','smartimage');
            uimenu(obj.contextmenu,'label','Delete SmartImage feature','callback',@obj.DeleteObjs,'tag','smartimage');
            g = findall(obj.ax,'tag','imrect');
            p = findall(g,'type','patch');
            set(p,'HitTest','off');
            parent = get(p,'uicontextmenu');
            set(g,'uicontextmenu',parent);
            uimenu(parent,'Label','Translate','Callback',@obj.translateCallback,'checked','off');
            uimenu(parent,'Label','Adjust Brightness/Contrast','Callback',@obj.contrast);
            uimenu(parent,'Label','Popout','Callback',@obj.popout);
            obj.ROIMenu(2) = uimenu(parent,'Label','ROI Visible','Callback',@obj.visCallback,'checked','on','UserData','ROI','tag','smartimage');
            obj.crosshairMenu(2) = uimenu(parent,'Label','CrossHair Visible','Callback',@obj.visCallback,'checked','on','UserData','crosshair','tag','smartimage');
            uimenu(parent,'Label','Use image''s ROI','Callback',@obj.useROI,'tag','smartimage');
            uimenu(parent,'label','Delete SmartImage feature','callback',@obj.DeleteObjs,'tag','smartimage');
            % Double click
            obj.listeners(5) = addlistener(fig,'WindowMousePress',@obj.clicked);
            % Closing listeners
            obj.listeners(6) = addlistener(fig,'Close',@obj.delete);
            obj.listeners(7) = addlistener(stage,'ObjectBeingDestroyed',@obj.DeleteObjs);
            obj.listeners(8) = addlistener(imager,'ObjectBeingDestroyed',@obj.DeleteObjs);
            obj.listeners(9) = addlistener(metastage,'ObjectBeingDestroyed',@obj.DeleteObjs);
        end
        function useROI(obj,h,eventdata)
            obj.imager.setROI(obj.info.ROI);
        end
        function translateCallback(obj,h,eventdata)
            % Input: handle to uimenu and imrect patch obj
            if strcmpi(get(h,'checked'),'on')
                val = 'off';
            else
                val = 'on';
            end
            obj.translate = val;
            set(h,'checked',val)
        end
        function visCallback(obj,h,eventdata)
            opt = get(h,'UserData');
            obj.([opt 'Visible']) = opposite(get(h,'checked'));
        end
        function set.translate(obj,val)
            p = findall(obj.ax,'type','patch');
            if isvalid(p)
                set(p,'HitTest',val);
                obj.translate = val;
            else
                obj.translate = 'off';
            end
        end
        function set.crosshairVisible(obj,val)
            if isvalid(obj.crosshairs)
                set(obj.crosshairs,'visible',val);
                set(obj.crosshairMenu,'checked',val)
                obj.crosshairVisible = val;
            else
                obj.crosshairVisible = 'off';
            end
        end
        function set.ROIVisible(obj,val)
            if ~isvalid(obj.roiRect)
                obj.ROIVisible = 'off';
                return
            end
            set(obj.roiRect,'visible',val) %#ok<*MCSUP>
            set(obj.roiRect,'HitTest',val)
            im_rect = findall(obj.ax,'tag','imrect');
            todo = {'maxx miny corner marker',...
                    'maxx maxy corner marker',...
                    'minx maxy corner marker',...
                    'minx miny corner marker',...
                    'miny top line',...
                    'maxx top line',...
                    'maxy top line',...
                    'minx top line',...
                    'patch',...
                    'wing line'};
            for i = 1:numel(todo)
                set(findall(im_rect,'tag',todo{i}),'HitTest',val);
            end
            if strcmp(obj.translate,'off')
                obj.translate = 'off';  % set correct patch val
            end
            set(obj.ROIMenu,'checked',val)
            obj.ROIVisible = val;
        end
        function delete(obj,varargin)
            todelete = {obj.listeners,obj.crosshairs,obj.roiRect,obj.contextmenu};
            for i = 1:numel(todelete)
                for j = 1:numel(todelete{i})
                    if isvalid(todelete{i}(j))
                        delete(todelete{i}(j))
                    end
                end
            end
        end
        function DeleteObjs(obj,varargin)
            obj.crosshairVisible = 'off';
            obj.ROIVisible = 'off';
            % Delete stage-related stuff
            todelete = {obj.listeners,obj.crosshairs,obj.roiRect,findall(Base.getParentFigure(obj.ax),'tag','smartimage')};
            for i = 1:numel(todelete)
                for j = 1:numel(todelete{i})
                    if isvalid(todelete{i}(j))
                        delete(todelete{i}(j))
                    end
                end
            end
        end
        function pos = getGlobalPosition(obj)
            % Gets position but subtracts out stages used by imager
            pos = obj.stage.position;
            if ~isempty(obj.imager.active_module.uses_stage)&&~isempty(obj.stage.modules)
                try
                    stage_used = obj.stage.module_byString(obj.imager.active_module.uses_stage);
                catch
                    error('Stage used for image is not loaded!')
                end
                stage_used_pos = stage_used.getCalibratedPosition;
                pos(1:2) = pos(1:2) - stage_used_pos(1:2);
            end
        end
        % Callbacks
        function popout(obj,varargin)
            % handle saving (need to get DBManager)
            [~,fig] = gcbo;
            managers = fig.UserData;
            % Need to move handles to new object
            newFig = figure('numbertitle','off','HandleVisibility','off');
            set(newFig,'name',sprintf('SmartImage %i',newFig.Number))
            NewAx = axes('parent',newFig);
            colormap(newFig,colormap(obj.ax))
            Base.SmartImage(obj.info,NewAx,managers.Stages,...
                                            Managers.MetaStage,...
                                           managers.Sources,...
                                           managers.Imaging);
            newFig.UserData.Managers = managers; % For popout in new figure
            db = managers.DB;
            delete(findall(newFig,'tag','figMenuFileSaveAs'))
            set(findall(newFig,'tag','figMenuFileSave'),'callback',@(hObj,eventdata)db.imSave(false,hObj,eventdata))
            set(findall(newFig,'tag','Standard.SaveFigure'),'ClickedCallback',@(hObj,eventdata)db.imSave(false,hObj,eventdata))
        end
        
        function contrast(obj,varargin)
            imcontrast(obj.imageH)
        end
        function clicked(obj,hObject,~)
            m_type = get(hObject,'selectionType');
            if strcmp(m_type,'open')&&~isempty(obj.stage.active_module)
                pos = get(obj.ax,'CurrentPoint');
                x = pos(1,1);
                y = pos(1,2);
                xlim = get(obj.ax,'xlim');
                ylim = get(obj.ax,'ylim');
                % Only when in axes limits
                if xlim(1)<x&&xlim(2)>x&&ylim(1)<y&&ylim(2)>y
                    newPos = obj.info.globalPos(1:2) + [x y];  % Remember, globalPos will be 0,0 for galvos, etc.
                    if sum(isnan(newPos))
                        errordlg(sprintf('Image was taken without a stage active.\nCannot perform this move.'))
                        return
                    end
                    imStages = obj.get_modules_str(obj.info);
                    activeStages = obj.stage.get_modules_str;
                    if ~isequal(imStages,activeStages)
                        imStages = strjoin(imStages,', ');
                        activeStages = strjoin(activeStages,', ');
                        errordlg(sprintf('Image was taken with stages:\n%s\n\nCurrent stages:\n%s\n\nCannot perform this move.',imStages,activeStages))
                        return
                    end
                    obj.stage.move([newPos NaN]);
                end
            end
        end
        
        function updateROI(obj,varargin)
            % Updates imrect from imager ROI change
            roi = obj.imager.ROI;
            xmin = roi(1,1);
            xmax = roi(1,2);
            ymin = roi(2,1);
            ymax = roi(2,2);
            pos = [xmin,ymin,xmax-xmin,ymax-ymin];
            obj.roiRect.setPosition(pos);
            obj.updatePos;   % This just updates the bounds of the crosshairs
        end
        function prepROI(obj,hObj,eventdata,callback)
            f = Base.getParentFigure(obj.ax);
            callback(hObj,eventdata);  % This assigns its own WindowButtonUpFcn
            ButtonUp = f.WindowButtonUpFcn;
            f.WindowButtonUpFcn = @(a,b)obj.newROI(a,b,ButtonUp);
        end
        function newROI(obj,hObj,eventdata,callback)
            % Should be called on WindowButtonUpFcn
            % Updates imager's ROI from imrect change
            m_type = get(hObj,'selectionType');
            hObj.WindowButtonUpFcn = '';
            if strcmp(m_type,'normal')
                callback(hObj,eventdata);
                pos = obj.roiRect.getPosition;
                xmin = pos(1);
                xmax = pos(1)+pos(3);
                ymin = pos(2);
                ymax = pos(2)+pos(4);
                obj.imager.setROI([xmin,xmax;ymin,ymax]); % This should call obj.updateROI from listener
            end
        end
        function pos = constrainROI(obj,pos,varargin)
            maxROI = obj.imager.active_module.maxROI.*obj.imager.get_cal;
            roi(1,1) = min(max(maxROI(1,1),pos(1)),maxROI(1,2));
            roi(1,2) = max(min(maxROI(1,2),pos(1)+pos(3)),maxROI(1,1));
            roi(2,1) = min(max(maxROI(2,1),pos(2)),maxROI(2,2));
            roi(2,2) = max(min(maxROI(2,2),pos(2)+pos(4)),maxROI(2,1));
            pos(1) = roi(1,1);
            pos(2) = roi(2,1);
            pos(3) = roi(1,2)-roi(1,1);
            pos(4) = roi(2,2)-roi(2,1);
        end
        function updatePos(obj,varargin)
            pos = obj.stage.position-obj.info.globalPos;
            % First get rid of them to determine the smallest axlim
            set(obj.crosshairs,'xdata',NaN,'ydata',NaN)
            xlim = get(obj.ax,'xlim');
            ylim = get(obj.ax,'ylim');
            if pos(1) < xlim(1) || pos(1) > xlim(2)
                pos(1) = NaN;
            end
            if pos(2) < ylim(1) || pos(2) > ylim(2)
                pos(2) = NaN;
            end
            set(obj.crosshairs(1),'xdata',[pos(1) pos(1)],'ydata',ylim);
            set(obj.crosshairs(2),'xdata',xlim,'ydata',[pos(2) pos(2)]);
        end
    end
    
end

