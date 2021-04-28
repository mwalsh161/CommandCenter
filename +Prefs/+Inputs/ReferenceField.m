classdef ReferenceField < Prefs.Inputs.LabelControlBasic
    %REFERENCEFIELD

    properties
        gear =  gobjects(1)
        uistyle = 'pushbutton'
    end

    methods
        function [obj, height_px, label_width_px] = make_UI(obj, pref, parent, yloc_px, width_px, margin_px)
            assert(isprop(pref, 'reference'), 'Pref using Inputs.ReferenceField must have a ''reference'' property.')
            reference = pref.reference;
            
            tag = strrep(pref.name,' ','_');
            
            temp = reference;
            
            if isempty(reference)
                reference = Prefs.Empty();
                reference.name = pref.name;
                reference.unit = [];
                temp = reference;
            else
                % Check parent valid.
                reference.help_text = [pref.property_name ' currently references ' reference.parent.encodeReadable(true) '.' reference.property_name ':' newline reference.help_text];
                reference.name = [pref.name ' ' char(0x2799) ' ' reference.name]; % reference.parent.encodeReadable(true) '.'
            end
            
            
            [reference.ui, height_px, label_width_px] = reference.ui.make_UI(reference, parent, yloc_px, width_px, margin_px);
            
            reference.help_text =   temp.help_text;
            reference.name =        temp.name;
            
            obj.ui = reference.ui.ui;
            obj.label = reference.ui.label;

            obj.gear
            
            if isempty(obj.gear) || ~isvalid(obj.gear) || ~isprop(obj.gear, 'UserData') || isempty(obj.gear.UserData)
                disp('Making gear')
                obj.gear = uicontrol(parent,...
                            'Style', obj.uistyle,...
                            'String', char(0x2699),...
                            'FontSize', 14, ...
                            'HorizontalAlignment','center',...
                            'Units', 'pixels',...
                            'Tag', tag,...
                            'Enable', 'on',...
                            'Tooltip', 'This Pref is a Prefs.Reference, which can be used to point to any Pref from another module.',...
                            'Callback', @pref.set_reference_Callback,...
                            'UserData', reference);
            end
                    
            obj.ui.Position(2) = yloc_px;
        end
        
        function link_callback(obj,callback)
            obj.ui.Callback = callback;
        end
        function adjust_UI(obj, suggested_label_width_px, margin_px)
            reference = obj.gear.UserData;

            reference.ui.adjust_UI(suggested_label_width_px, margin_px);
            
            obj.label.ForegroundColor = 'b';
            
            obj.gear.Position(2) = reference.ui.ui.Position(2);
            obj.gear.Position(3) = reference.ui.ui.Position(4);
            obj.gear.Position(4) = reference.ui.ui.Position(4);
            
            if isprop(reference.ui, 'unit') && isgraphics(reference.ui.unit)
                obj.gear.Position(1) = reference.ui.unit.Position(1) + reference.ui.unit.Position(3) - reference.ui.ui.Position(4);
                reference.ui.unit.Position(1) = reference.ui.unit.Position(1) - reference.ui.ui.Position(4);
            else
                obj.gear.Position(1) = reference.ui.ui.Position(1) + reference.ui.ui.Position(3) - reference.ui.ui.Position(4);
            end
            
            reference.ui.ui.Position(3) = reference.ui.ui.Position(3) - reference.ui.ui.Position(4);
        end
        
        % To check if the UI is valid
%         tf = isvalid(obj)

        % Given a value, update the UI objects
        function set_value(obj,val)
            obj.gear.UserData.ui.set_value(val);
        end
        % Retrieve the value from UI and return it
        function val = get_value(obj)
            val = obj.gear.UserData.ui.get_value();
        end
    end

end
