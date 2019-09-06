classdef ModuleSelectionField < Base.input
    %MODULESELECTIONFIELD provides UI to choose modules and access their settings

    properties
        label = gobjects(1);
        selection = gobjects(1);
        buttons = gobjects(1,3);
        empty_val = '<None>';
    end

    methods % Helpers
        function strings = get_module_strings(obj, modules)
            strings = arrayfun(@(a)class(a), modules,'uniformoutput',false);
            if isempty(strings)
                strings = {obj.empty_val};
            end
        end
    end
    methods
        function tf = isvalid(obj)
            tf = isgraphics(obj.label) && isvalid(obj.label);
        end
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px)
            % Line 1: Label
            % Line 2: popupmenu
            % Line 3: add/remove/settings buttons
            % Prepare/format values
            obj.empty_val = pref.empty_val;
            label_width_px = 0;
            pad = 5; % px between lines
            tag = strrep(pref.name,' ','_');
            labeltext = pref.name;
            if ~isempty(pref.units)
                labeltext = sprintf('%s (%s)',pref.name,pref.units);
            end
            % Line 3
            height_px = 0;
            if ~pref.readonly
                obj.buttons(1) = uicontrol(parent, 'style', 'pushbutton',...
                                'string', 'Add', 'units', 'pixels',...
                                'tag', [tag '_add'], 'Callback', @obj.add_module);
                obj.buttons(2) = uicontrol(parent, 'style', 'pushbutton',...
                                'string', 'Remove', 'units', 'pixels',...
                                'tag', [tag '_remove'], 'Callback', @obj.rm_module,...
                                'tooltip','Selected module (above)',...
                                'enable','off');
                obj.buttons(3) = uicontrol(parent, 'style', 'pushbutton',...
                                'string', 'Settings', 'units', 'pixels',...
                                'tag', [tag '_settings'], 'Callback', @obj.module_settings,...
                                'tooltip','For selected module (above)',...
                                'enable','off');
                obj.buttons(1).Position(2) = yloc_px;
                obj.buttons(2).Position(2) = yloc_px;
                obj.buttons(3).Position(2) = yloc_px;
                height_px = obj.buttons(1).Extent(4) + pad;
            end
            % Line 2
            obj.selection = uicontrol(parent, 'style', 'popupmenu',...
                        'String', {obj.empty_val},...
                        'horizontalalignment','left',...
                        'units', 'pixels',...
                        'tag', tag,...
                        'UserData', struct('empty',true, 'objects',[])));
            obj.selection.Position(2) = yloc_px + height_px;
            height_px = height_px + obj.selection.Extent(4) + pad;
            % Line 1
            obj.label = uicontrol(parent, 'style', 'text',...
                        'string', [labeltext ': '],...
                        'horizontalalignment', 'right',...
                        'units', 'pixels',...
                        'tag', [tag '_label']);
            obj.label.Position(2) = yloc_px + height_px;
            height_px = height_px + obj.label.Position(4);

            if ~isempty(pref.help_text)
                set([obj.label, obj.selection], 'ToolTip', pref.help_text);
            end
        end
        function link_callback(obj,callback)
            obj.selection.Callback = callback;
        end
        function adjust_UI(obj, suggested_label_width , margin)
            % Position UI elements on separate lines from bottom up
            total_width = obj.label.Parent.Position(3);
            indent = 2*margin(1);
            if all(isgraphics(obj.buttons))
                pad = 5; % pixels between buttons
                btn_wid = (total_width - indent - margin(2) - pad*2)/3;
                for i = 1:3
                    obj.buttons(i).Position(1) = indent + (btn_wid + pad)*(i-1);
                    obj.buttons(i).Position(3) = btn_wid;
                end
            end
            obj.label.Position(1) = margin(1);
            obj.label.Position(3) = suggested_label_width;
            obj.selection.Position(1) = indent;
            obj.selection.Position(3) = total_width - indent - margin(2);
        end
        function set_value(obj,val)
            
        end
        function val = get_value(obj)
            
        end
    end

    methods % Callbacks
        function add_module(obj,hObj,eventdata)
            fprintf('Added!\n')
        end
        function rm_module(obj,hObj,eventdata)
            fprintf('Removed!\n')
        end
        function module_settings(obj,hObj,eventdata)
            if obj.selection.UserData.empty
                error('No module selected.')
            end
            % Grab instance and call settings
            ind = obj.selection.Value;
            objString = hObj.UserData.String{ind};
            assert(~isempty(objString),'Cannot have empty module string')
            assert(objString(1)~='_','Cannot get settings for Add/Remove buttons');
            if length(strsplit(objString,' ')) == 1 % Means, "Empty: " is not there
                obj = eval(sprintf('%s.instance',objString));
                f = figure('name',sprintf('%s Settings (close when done)',objString),'IntegerHandle','off','menu','none',...
                    'toolbar','none','visible','off','units','characters','resize','off','windowstyle','modal','HitTest','off');
                f.Position(3) = 100;
                panel = uipanel(f);
                obj.settings(panel);
                child = allchild(panel);
                h = 0; % Get height
                for i = 1:length(child)
                    new_h = sum(child(i).Position([2,4]));
                    if new_h > h
                        h = new_h;
                    end
                end
                f.Position(4) = h;
                f.Visible = 'on';
            end
        end
    end

end