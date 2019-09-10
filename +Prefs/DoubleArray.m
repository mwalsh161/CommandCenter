classdef DoubleArray < Base.pref
    %ARRAY Maintain an array of double values. 
    
    properties(Hidden)
        default = 0;
        ui = Prefs.Inputs.TableField;
    end
    properties
        allow_nan = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        max = {Inf, @(a)validateattributes(a,{'numeric'},{'scalar'})};
        min = {-Inf, @(a)validateattributes(a,{'numeric'},{'scalar'})};
        props = {{}, @iscell};
        hide_label = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
    end
    
    methods
        function obj = DoubleArray(varargin)
            obj = obj@Base.pref(varargin{:});
            obj.ui.ColumnFormat = {'numeric'};
            obj.ui.hide_label = obj.hide_label;
        end
        function validate(obj,val)
            validateattributes(val,{'numeric'},{})
            if ~obj.allow_nan
                assert(all(~isnan(val)),'Attempted to set NaN. allow_nan is set to false.')
            end
            mask = ~isnan(val);
            assert(all(val(mask) <= obj.max), 'Cannot set value greater than max.')
            assert(all(val(mask) >= obj.min), 'Cannot set value less than min.')
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