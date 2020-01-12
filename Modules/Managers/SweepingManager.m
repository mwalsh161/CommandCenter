classdef SweepingManager < Base.Manager
    
    properties(SetAccess=private)
        aborted = false;
        scan = [];
    end
    
    events
        experiment_finished
    end
    
    methods
        function obj = SweepingManager(handles)
            obj = obj@Base.Manager(Modules.Scanning.modules_package,handles,handles.panelScanning);
            obj.blockOnLoad = handles.menu_scanning;
            
            if ~isempty(handles.axImage) && isvalid(handles.axImage)
                cla(handles.axImage,'reset')
            else % Clean up and reset axes
                delete(allchild(handles.panel_exp));  % Potential memory leak if user doesn't have delete callback to clean up listeners
                handles.axImage = axes('parent',obj.handles.panel_img,'tag','axImage');
            end
            
            obj.scan = Base.Scan;
            Base.ScanViewer(obj.scan, handles.axImage, handles.panelScanning.content);
            
            obj.scan.reset;
            drawnow;
        end
        
        function getAvail(obj,parent_menu)
            % Override. 
            module_strs = obj.get_modules_str;
            delete(allchild(parent_menu));
            if isempty(module_strs)
                uimenu(parent_menu,'label','No Scans Loaded','enable','off');
            end
            for i = 1:numel(module_strs)
                module_str = module_strs{i};
                uimenu(parent_menu,'label',module_str,'enable','off');
            end
            
            uimenu(parent_menu, 'Text', 'New Scan', 'Callback', @obj.newScan_Callback);
            uimenu(parent_menu, 'Text', 'Start Scan', 'Callback', @(s,e)(obj.scan.snap), 'Separator', 'on');
            uimenu(parent_menu, 'Text', 'Reset Scan', 'Callback', @(s,e)(obj.scan.reset));
        end
        
%         function new()
%             figure;
%             pl = Base.prefList();
%             
%                 pl.menu
%         end
        
        % Save Event Callback
        function forceSave(obj,varargin)
            % Go through autosave
            obj.handles.Managers.DB.expSave(true)
        end

    end
    methods(Access=protected)
        function active_module_changed(obj,varargin)
            if ~isempty(obj.active_module)
                addlistener(obj.active_module,'save_request',@obj.forceSave);
            end
        end
    end
    methods(Static)
        function [textH,h] = abortBox(name,abort_callback)
            h = msgbox('Experiment Started',sprintf('%s running',name),'help','modal');
            h.KeyPressFcn='';  % Prevent esc from closing window
            h.CloseRequestFcn = abort_callback;
            % Repurpose the OKButton
            button = findall(h,'tag','OKButton');
            set(button,'tag','AbortButton','string','Abort',...
                'callback',abort_callback)
            textH = findall(h,'tag','MessageBox');
            addlistener(textH,'String','PostSet',@Base.Manager.resizeMsgBox);
        end
    end
    methods(Static)
        function newScan_Callback(src, evt)
            pl = Base.prefList.instance;
            m = pl.getMenu(figure, @(s,e,p)(disp(p)), 'readonly', false, 'numeric', true);
        end
    end
end

