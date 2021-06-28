classdef LabelControlBasic < Base.Input
    % LABELCONTROLBASIC provides functionality for preparing a common input type
    %   of a right justified label (text) and a left justified input uicontrol element
    %   It stores the label uicontrol element in "label" and the input element
    %   in "ui"
    %   In its most basic form, this defaults to a CharField

    properties % Handles to all uicontrol objects
        label = gobjects(1)
        ui = gobjects(1)
    end
    properties(Abstract,Hidden)
        uistyle;   % uicontrol style argument
    end

    methods % Satisfy all abstract methods
        function tf = isvalid(obj)
            tf = isgraphics(obj.ui) && isvalid(obj.ui);
        end
        % These methods are responsible for building the settings UI and setting/getting values from it
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin)
            % Here, widths will all be taken care of in adjust_UI
            tag = strrep(pref.name,' ','_');
            labeltext = obj.get_label(pref);

            if strcmp(obj.uistyle, 'checkbox') && strcmp(pref.unit, '0/1')
                labeltext = labeltext(1:end-6);
            end

            enabled = 'on';
            if pref.readonly
                enabled = 'off';
            end
            obj.label = uicontrol(parent, 'Style', 'text',...
                        'String', [labeltext ': '],...
                        'HorizontalAlignment', 'right',...
                        'Units', 'pixels',...
                        'Tag', [tag '_label']);
            obj.label.Position(2) = yloc_px;
            label_width_px = obj.label.Extent(3);

            obj.ui = uicontrol(parent, 'Style', obj.uistyle,...
                        'HorizontalAlignment','left',...
                        'Units', 'pixels',...
                        'Tag', tag,...
                        'Enable', enabled,...
                        'UserData', pref.readonly);   % UserData field contains another copy of readonly for inputs which overwrite Enable
            obj.ui.Position(2) = yloc_px;

%             if ~isempty(pref.help_text)
            set(obj.label, 'Tooltip', pref.get_help_text);
%             end
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
            if any(obj.label.Extent(3:4) > obj.label.Position(3:4))
                help_text = get(obj.label, 'Tooltip');
                set(obj.label, 'Tooltip',...
                    ['<html>' obj.label.String(1:end-2) '<br/>' help_text(7:end)]);
            end
        end
        function set_value(obj,val)
            obj.ui.String = val;
        end
        function val = get_value(obj)
            val = obj.ui.String;
        end
    end

end
