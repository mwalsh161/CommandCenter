classdef Module < Base.pref
    %MODULE Allow particular types of module arrays
    
    properties
        ui = Prefs.Inputs.ModuleSelectionField;
        inherits = {}; % Superclasses required for this module as cell array of chars
        n = 1;         % Number of allowed instances simultaneously (n > 0)
    end
    
    methods
        function obj = Module(varargin)
            obj = obj.init(varargin{:});
            assert(obj.n > 0, 'Parameter "n" must be greater than 0.')
        end
        function set_ui_value(obj,val)
            obj.ui.set_value(val);
        end
        function val = get_ui_value(obj)
            val = obj.ui.get_value();
        end
        function validate(obj,val)
            if numel(val) > obj.n
                sz = num2str(size(val),'x'); sz(end) = []; % Remove trailing x
                error('MODULE:too_many','%s "%s" exceeds the maximum allowed instances of %i.',...
                    sz, class(val), obj.n)
            end
            supers = superclasses(val);
            if all(ismember(obj.inherits, supers))
                error('MODULE:not_all_superclasses',...
                    '"%s" does not inherit required superclasses: %s',...
                    class(val), strjoin(obj.inherits,', '))
            elseif ~ismember('Base.Module', supers) || ~isa(val, 'Base.Module')
                error('MODULE:not_module','"%s" does not inherit Base.Module.', class(val))
            end
        end
    end
    
end