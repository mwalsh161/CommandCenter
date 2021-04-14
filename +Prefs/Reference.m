classdef Reference < Base.Pref
    %REFERENCE

    properties (Hidden)
        default = []; %'____Prefs.Reference.default____';
        ui = Prefs.Inputs.ReferenceField;
        pref = Prefs.Numeric.empty(1,0);
    end

    methods
        function obj = Reference(varargin)
            obj = obj@Base.Pref(varargin{:});
        end
        
        function tf = isnumeric(obj)
            if isempty(obj.pref)
                tf = false;
            else
                tf = obj.pref.isnumeric();
            end
        end
        
        % Functions that actually write (set) and read (get) the hardware, with overhead.
        function [obj, val] = set_value(obj,val)
%             if ~isempty(val)
                if isempty(obj.pref)
%                     error('No reference to set.');
                else
                    obj.pref.writ(val);
%                     val = obj.pref.read();
                end
%             end
        end
        function val = get_value(obj)
            if isempty(obj.pref)
                val = NaN;
            else
                val = obj.pref.read();
            end
        end
        
        function val = read(obj)
            val = obj.pref.read();
        end
        function tf = writ(obj, val)
            tf = obj.pref.writ(val);
        end
        
        function validate(~, val)
%             if ~isa(val, 'Prefs.Numeric') && ~ismember('Prefs.Numeric', superclasses(val))
%                 error(['Prefs.Reference must point to a Prefs.Numeric. Instead got a ' class(val)]);
%             end
        end
    end
end
