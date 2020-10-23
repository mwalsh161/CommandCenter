classdef DoubleArray < Base.Pref
    %ARRAY Maintain an array of double values. STR2NUM is used to attempt
    %to convert any text data to a value. This means expressions will be
    %evaluated and any text representing a number to MATLAB (e.g. 'pi')
    %will be converted to a double. Text that can't be converted will be
    %set to NaN. Obviously if allow_nan is false, this will error and not
    %set a new value.
    
    properties (Hidden)
        default = 0;
        ui = Prefs.Inputs.TableField;
        callback = [];
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
            obj = obj@Base.Pref(varargin{:});
            obj.ui.ColumnFormat = {'numeric'};
            obj.ui.hide_label = obj.hide_label;
        end
        function validate(obj,val)
            val = val(:); % 1 dim for all function
            validateattributes(val,{'numeric'},{})
            if ~obj.allow_nan
                assert(all(~isnan(val)),'Attempted to set NaN. allow_nan is set to false.')
            end
            mask = ~isnan(val);
            assert(all(val(mask) <= obj.max), 'Cannot set value greater than max.')
            assert(all(val(mask) >= obj.min), 'Cannot set value less than min.')
        end
        function obj = link_callback(obj,callback)
            assert(isa(callback,'function_handle')||iscell(callback),...
                sprintf('%s only supports function handle or cell array callbacks (received %s).',...
                mfilename,class(callback)));
            obj.callback = callback;
            obj.ui = obj.ui.link_callback(@obj.CellEdit);
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
                num = str2num(eventdata.EditData);%#ok<ST2NM> % str2num will evaluate expressions 
                if numel(num)==1 && ~isnan(num)
                    % Then update with calculated value
                    subs = num2cell(eventdata.Indices);
                    I = sub2ind(size(UI.Data),subs{:});
                    UI.Data(I) = num;
                    eventdata.NewData = num;
                end
            end
            if ~isempty(obj.callback)
                switch class(obj.callback)
                    case 'cell'
                        obj.callback{1}(UI,eventdata,obj,obj.callback{2:end});
                    case 'function_handle'
                        obj.callback(UI,eventdata,obj);
                end
            end
        end
    end
    
end