classdef Reference < Base.Pref
    %REFERENCE

    properties (Hidden)
        default = []; %'____Prefs.Reference.default____';
        ui = Prefs.Inputs.ReferenceField;
        reference = []; % Prefs.Numeric.empty(1,0);
        
        lsh = [];
    end

    methods
        function obj = Reference(varargin)
            obj = obj@Base.Pref(varargin{:});
        end
        
        function tf = isnumeric(obj)
            if isempty(obj.reference)
                tf = false;
            else
                tf = obj.reference.isnumeric();
            end
        end
        
        function tosave = encodeValue(obj, ~) % Ignore the passed data value.
            if isempty(obj.reference)
                tosave = [];
            else
                tosave = obj.reference.encode();
            end
        end
        function [data, obj] = decodeValue(obj, saved)
            obj.reference = Base.Pref.decode(saved);
            data = obj.reference.read();
        end
        
        function obj = set_reference(obj, val)
            if ismember('Prefs.Inputs.LabelControlBasic', superclasses(val.ui)) && ~isa(val, 'Prefs.Reference') && ~ismember('Prefs.Reference', superclasses(val)) && ~isequal(obj.parent, val.parent)
                obj.reference = val;
                obj.parent.set_meta_pref(obj.property_name, obj);

                notify(obj.parent, 'update_settings');
            end
        end
        function obj = set_reference_Callback(obj, src, evt)
            pr = Base.PrefRegister.instance;
            pr.getMenu([], @obj.set_reference);
        end
        
        function obj = link_callback(obj,callback)
            % This wraps ui.link_callback; careful overloading
            if ~isempty(obj.reference)
                obj.ui.link_callback({callback, obj.reference});
            end
        end
        
        function [obj,height_px,label_width_px] = make_UI(obj,varargin)
            % This wraps ui.make_UI; careful overloading
            [obj.ui,height_px,label_width_px] = obj.ui.make_UI(obj,varargin{:});
            obj.reference = obj.ui.gear.UserData;
        end
        
%         function obj = set.reference(obj, val)
% %             obj.parent.
%         end
%         function val = get.reference(obj)
%             
%         end
        
        % Calls to set value are now redirected to the pref that is being referenced.
        function val = get_value(obj, ~)
            if isempty(obj.reference)
                val = NaN;
            else
                val = obj.reference.read();
            end
        end
        function [obj, val] = set_value(obj, val)
            if isempty(obj.reference)
%                 error('No reference to set.');
            else
                obj.reference.writ(val);
            end
        end
        
%         function val = get_ui_value(obj)
%             val = obj.ui.get_value();
%         end
        function set_ui_value(obj,val)
            if ~isempty(obj.reference)
                obj.ui.set_value(val);
            end
        end
        
        function val = read(obj)
            val = obj.reference.read();
        end
        function tf = writ(obj, val)
            tf = obj.reference.writ(val);
        end
    end
end
