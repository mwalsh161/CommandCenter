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
%                         [mp,height_px,label_size(i)] = mp.make_UI(panelH, panelH_loc, widthPx, margin);
        function [obj, height_px, label_width_px] = make_UI(obj, pref, parent, yloc_px, width_px, margin_px)
            assert(isprop(pref, 'reference'), 'Pref using Inputs.ReferenceField must have a ''reference'' property.')
            reference = pref.reference;
            
            obj.yloc_px = yloc_px;
            obj.width_px = width_px;
            
            tag = strrep(pref.name,' ','_');
            
            if isempty(reference)
                reference = Prefs.Empty();
                reference.name = pref.name;
                reference.unit = [];
            end
            
            [reference.ui, height_px, label_width_px] = reference.ui.make_UI(reference, parent, yloc_px, width_px, margin_px);
            
            obj.ui = reference.ui.ui;
            obj.label = reference.ui.label;
%             if isprop(reference.ui, 'unit')
%                 obj.unit = reference.ui.unit;
%             end
            
            obj
            
%             obj.ui
            
%             uicontrol('String', char(0x2699));

            obj.gear

            obj.gear = uicontrol(parent,...
                        'Style', obj.uistyle,...
                        'String', char(0x2699),...
                        'HorizontalAlignment','center',...
                        'Units', 'pixels',...
                        'Tag', tag,...
                        'Enable', 'on',...
                        'Callback', @pref.set_reference_Callback,...
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
%             adjust_UI@Prefs.Inputs.CharField(obj,suggested_label_width_px, margin_px);
%             adjust_UI@Prefs.Inputs.CharField(obj,suggested_label_width_px, margin_px);

            reference = obj.gear.UserData;

            reference.ui.adjust_UI(suggested_label_width_px, margin_px);
            
            obj.label.ForegroundColor = 'b';
            
            obj.gear.Position(1) = reference.ui.ui.Position(1) + reference.ui.ui.Position(3) - reference.ui.ui.Position(4);
            obj.gear.Position(2) = reference.ui.ui.Position(2);
            obj.gear.Position(3) = reference.ui.ui.Position(4);
            obj.gear.Position(4) = reference.ui.ui.Position(4);
            
            reference.ui.ui.Position(3) = reference.ui.ui.Position(3) - reference.ui.ui.Position(4);
            
%             if isgraphics(obj.unit) % unit exist
%                 unit_space = obj.unit.Position(3);
%                 obj.unit.Position(1) = obj.unit.Parent.Position(3) - (unit_space + margin_px(2));
%             end
%             obj.ui.Position(3) = obj.label.Parent.Position(3) - ...
%                                 (suggested_label_width_px + unit_space + sum(margin_px));
        end
        
        % To check if the UI is valid
        tf = isvalid(obj)

        % Given a value, update the UI objects
        function set_value(obj,val)
%             margin_px(1) = obj.label.Position(1);
%             suggested_label_width_px = obj.label.Position(3);
% %             obj.ui.Position(3) = obj.label.Parent.Position(3) - (suggested_label_width_px + margin_px(1) + margin_px(2));
%             margin_px(2) = obj.label.Parent.Position(3) - (suggested_label_width_px + margin_px(1) + obj.ui.Position(3));
%             
%             delete(obj.ui)
%             delete(obj.label)
%             delete(obj.unit)
%             delete(obj.gear)
            
            
            
%             obj.ui.String = val;
        end
        % Retrieve the value from UI and return it
        function val = get_value(obj)
            val = []
%             obj.ui.
%             val = obj.gear.UserData;    % Return the pref saved in UserData.
        end
    end

end
