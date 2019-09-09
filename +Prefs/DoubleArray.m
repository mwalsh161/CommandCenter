classdef DoubleArray < Prefs.Double
    %ARRAY Maintain an array of double values
    %   Limitations: display_precision is not implemented in UI
    
    properties(Hidden)
        default = false;
        ui = Prefs.Inputs.TableField;
    end
    properties
        props = {{}, @iscell};
        hide_label = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
    end
    
    methods
        function obj = DoubleArray(varargin)
            obj = obj@Prefs.Double(varargin{:});
            obj.ui.ColumnFormat = {'numeric'};
            obj.ui.hide_label = obj.hide_label;
        end
        function val = clean(obj,val)
            if obj.truncate
                val = arrayfun(@(a)str2double(num2str(a,obj.display_precision)),val);
            end
        end
        function validate(obj,val)
            % Call parent validator on all elements
            arrayfun(@(a)validate@Prefs.Double(obj,a),val)
        end
    end
    methods
        function obj = set.props(obj,val)
            obj.ui.props = val; % Runs obj.ui.set.props "validator"
            obj.props = val;
        end
        function CellEdit(obj,UI,eventdata)
            eventdata = struct(eventdata);
            if isnan(eventdata.NewData)
                num = num2str(eventdata.EditData);
                if numel(num)==1 && ~isnan(num)
                    % Then update with calculated value
                    subs = num2cell(eventdata.Indices);
                    I = sub2ind(size(UI.Data),subs{:});
                    UI.Data(I) = num;
                    eventdata.NewData = num;
                end
            end
            obj.callback(UI,eventdata);
        end
    end
    
end