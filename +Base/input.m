classdef input
% INPUT Abstract class for input UIs in settings
%   Used by class-based prefs (stored in Prefs.Inputs)

    methods(Abstract)
        % Prepare an appropriate UI container in parent no lower than yloc_px
        %   and no wider than width_px (parent width) and return:
        %   ui: matlab type containing UI data (passed to obj.adjust_UI)
        %   height_px: extent of UI constructed (not including any padding)
        %   label_width_px: the width of an optional label component. Used
        %       to justify all labels in adjust_UI. Return 0 if not needed.
        [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px)
        
        % Method to link callback (see subclass to see specifics). Useful
        % to separate from make_UI such that user can pass this obj in the
        % callback after it has been linked to UI (it is a value class!)
        link_callback(obj,callback)
        
        % Once Module.settings calls all get_UI methods, it will go back
        % and call this method using a suggested label_width_px giving this
        % pref the opportunity to readjust positions if desired. Likewise,
        % margin specifies [left, right] margins in pixels requested by CC.
        adjust_UI(obj, suggested_label_width_px, margin)
        
        % To check if the UI is valid
        tf = isvalid(obj)

        % Given a value, update the UI objects
        set_value(obj,val)
        % Retrieve the value from UI and return it
        val = get_value(obj)
    end

end