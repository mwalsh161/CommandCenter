classdef ModuleSelectionField < Base.input
    %MODULESELECTIONFIELD provides UI to choose modules and access their settings

    properties
    end

    methods % Satisfy all abstract methods
        function tf = isvalid(obj)
            
        end
        % These methods are responsible for building the settings UI and setting/getting values from it
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px)
            % Here, widths will all be taken care of in adjust_UI
            tag = strrep(pref.name,' ','_');
            if ~isempty(pref.units)
                nameFormatted = sprintf('%s (%s): ',pref.name,pref.units);
            else
                nameFormatted = sprintf('%s: ',pref.name);
            end
            enabled = 'on';
            if pref.readonly
                enabled = 'off';
            end
            obj.label = uicontrol(parent, 'style', 'text',...
                        'string', nameFormatted,...
                        'horizontalalignment', 'right',...
                        'units', 'pixels',...
                        'tag', [tag '_label']);
            obj.label.Position(2) = yloc_px;
            label_width_px = obj.label.Extent(3);

            obj.ui = uicontrol(parent, 'style', 'popupmenu',...
                        'String',pref.choices_strings,...
                        'horizontalalignment','left',...
                        'units', 'pixels',...
                        'tag', tag,...
                        'enable', enabled);
            obj.ui.Position(2) = yloc_px;

            if ~isempty(pref.help_text)
                set([obj.label, obj.ui], 'ToolTip', pref.help_text);
            end
            height_px = obj.ui.Position(4);
        end
        function link_callback(obj,callback)
            obj.ui.Callback = callback;
        end
        function adjust_UI(obj,suggested_label_width_px,margin_px)
            obj.label.Position(1) = margin_px(1);
            obj.label.Position(3) = suggested_label_width_px;
            obj.ui.Position(1) = suggested_label_width_px + margin_px(1);
            obj.ui.Position(3) = obj.label.Parent.Position(3) - ...
                                (suggested_label_width_px + sum(margin_px));
        end
        function set_value(obj,val)
            
        end
        function val = get_value(obj)
            
        end
    end

end