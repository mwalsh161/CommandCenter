classdef Reference < Base.Pref
    %REFERENCE

    properties (Hidden)
        default = []; %'____Prefs.Reference.default____';
        ui = Prefs.Inputs.ReferenceField;
        reference = Prefs.Numeric.empty(1,0);
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
        
%         function obj = set.pref(obj, val)
%             
%         end
%         function val = get.pref(obj)
%             
%         end
        
        % Calls to set value are now redirected to the pref that is being referenced.
        function [obj, val] = set_value(obj, val)
%             if ~isempty(val)
                if isempty(obj.reference)
%                     error('No reference to set.');
                else
                    obj.reference.writ(val);
%                     val = obj.pref.read();
                end
%             end
        end
        function val = get_value(obj, ~)
            if isempty(obj.reference)
                val = NaN;
            else
                val = obj.reference.read();
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
