classdef ReferenceField < Prefs.Inputs.LabelControlBasic
    %REFERENCEFIELD

    properties
        gear =  gobjects(1)
        uistyle = 'pushbutton'
        
        yloc_px = 0;
        width_px = 0;
%         suggested_label_width_px = 0;
%         margin = 0;
    end

    methods
        % Prepare an appropriate UI container in parent no lower than yloc_px
        %   and no wider than width_px (parent width) and return:
        %   ui: matlab type containing UI data (passed to obj.adjust_UI)
        %   height_px: extent of UI constructed (not including any padding)
        %   label_width_px: the width of an optional label component. Used
        %       to justify all labels in adjust_UI. Return 0 if not needed.
        function [obj, height_px, label_width_px] = make_UI(obj, pref, parent, yloc_px, width_px)
            reference = pref.value;
            
            obj.yloc_px = yloc_px;
            obj.width_px = width_px;
            
            tag = strrep(pref.name,' ','_');
            
            if isempty(reference)
                reference = Prefs.Empty();
            end
            
            [obj, height_px, label_width_px] = reference.ui.make_UI(reference, parent, yloc_px, width_px);
            
            obj.ui = reference.ui;
            obj.label = reference.label;
            if isprop(reference, 'unit')
                obj.unit = reference.unit;
            end
            
            uicontrol('String', char(0x2699));

            obj.gear = uicontrol(parent, 'Style', obj.uistyle,...
                        'HorizontalAlignment','left',...
                        'Units', 'pixels',...
                        'Tag', tag,...
                        'Enable', enabled,...
                        'UserData', reference);
            obj.ui.Position(2) = yloc_px;
        end
        
        % Method to link callback (see subclass to see specifics). Useful
        % to separate from make_UI such that user can pass this obj in the
        % callback after it has been linked to UI (it is a value class!)
        function link_callback(obj,callback)
            obj.ui.Callback = callback;
        end
        
        % Once Module.settings calls all get_UI methods, it will go back
        % and call this method using a suggested label_width_px giving this
        % pref the opportunity to readjust positions if desired. Likewise,
        % margin specifies [left, right] margins in pixels requested by CC.
        function adjust_UI(obj, suggested_label_width_px, margin_px)
            adjust_UI@Prefs.Inputs.CharField(obj,suggested_label_width_px, margin_px);
            
            obj.gear.Position(1) = obj.label.Position(2);
            obj.gear.Position(2) = obj.label.Position(2);
            
            if isgraphics(obj.unit) % unit exist
                unit_space = obj.unit.Position(3);
                obj.unit.Position(1) = obj.unit.Parent.Position(3) - (unit_space + margin_px(2));
            end
            obj.ui.Position(3) = obj.label.Parent.Position(3) - ...
                                (suggested_label_width_px + unit_space + sum(margin_px));
        end
        
        % To check if the UI is valid
        tf = isvalid(obj)

        % Given a value, update the UI objects
        function set_value(obj,val)
            margin_px(1) = obj.label.Position(1);
            suggested_label_width_px = obj.label.Position(3);
%             obj.ui.Position(3) = obj.label.Parent.Position(3) - (suggested_label_width_px + margin_px(1) + margin_px(2));
            margin_px(2) = obj.label.Parent.Position(3) - (suggested_label_width_px + margin_px(1) + obj.ui.Position(3));
            
            delete(obj.ui)
            delete(obj.label)
            delete(obj.unit)
            delete(obj.geear)
            
            
            
%             obj.ui.String = val;
        end
        % Retrieve the value from UI and return it
        function val = get_value(obj)
            val = obj.gear.UserData;    % Return the pref saved in UserData.
        end
    end

end
