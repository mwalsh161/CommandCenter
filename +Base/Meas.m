classdef Meas < handle %matlab.mixin.Heterogeneous
    properties (SetAccess=private)
        field   = 'data';   % Programatic name of this measurement (defaults to "data").
%         parent_class = '';  % 
    end
    properties
        name    = '';       % Displayed name of this measurement (defaults to field).
        unit    = '';       % Displayed unit of the data from this measurement (e.g. cts, V, ...)
        
        size    = [];       % Size of numeric data returned by this Meas.
        dims    = {};       % 
        scans   = {};       % 
        
        
    end
    
    methods
        function obj = Meas(varargin)
            obj = obj.init(varargin{:});
        end
        function obj = init(obj, varargin)
            try % Try is to throw all errors as caller
                % Process input (subclasses should use set methods to validate)
                p = inputParser;

                % If user supplied odd number of inputs, then we expect the
                % call syntax to be: subclass(default,property1,value1,...);
                if mod(length(varargin), 2)
                    size_in_parser = false;
                    size = varargin{1}; %#ok<*PROPLC>
                    varargin(1) = [];
                else % subclass(property1,value1,...); (where default could be a property)
                    size_in_parser = true;
                    % Default gets set to value at end of function, so will go through
                    % the validate method; no validation necessary here
                    addParameter(p, 'size', obj.size);
                end

%                 % Go through all public properties (removing Hidden and Abstract ones)
%                 mc = metaclass(obj);
%                 mps = mc.PropertyList;
%                 nprops = length(mps);
%                 for ii = 1:nprops % Need to bypass get methods using the metaprop
%                     mp = mps(ii);
%                     if ~mp.Hidden && ~mp.Abstract && ~mp.Constant
%                         assert(mp.HasDefault && iscell(mp.DefaultValue) && length(mp.DefaultValue)==2,...
%                             'Default value of "%s" should be cell array: {default, validation_function}',mp.Name);
%                         addParameter(p,mp.Name,mp.DefaultValue{1},mp.DefaultValue{2});
%                     end
%                 end
                
                addParameter(p, 'field', '');
                addParameter(p, 'name', '');
                addParameter(p, 'unit', 'arb');
                addParameter(p, 'dims', {});
                addParameter(p, 'scans', {});
                

                parse(p,varargin{:});
                
                if size_in_parser
                    size = p.Results.size;
                end
                
                assert(~(isempty(p.Results.field) && isempty(p.Results.name)))

                if isempty(p.Results.field)
                    obj.field = 'data';     %  Default to "data"
                    obj.name =  p.Results.name;
                elseif isempty(p.Results.name)
                    obj.field = p.Results.field;
                    obj.name =  p.Results.field;
                else
                    obj.field = p.Results.field;
                    obj.name =  p.Results.name;
                end
                
                obj.unit =  p.Results.unit;
                
                obj.dims =  p.Results.dims;
                obj.scans = p.Results.scans;
                
                if isempty(obj.dims)
                    
                end
                if isempty(obj.scans)
                    
                end
                
                % Assign props
%                 for ii = 1:nprops
%                     mp = mps(ii);
%                     if ~mp.Hidden && ~mp.Abstract && ~mp.Constant
%                         obj.(mp.Name) = p.Results.(mp.Name);
%                     end
%                 end

%                 if isempty(obj.name)
%                     obj.name = obj.property_name;
%                 end

                % Finally assign default (dont ignore if empty, because
                % subclass might have validation preventing empty, in which
                % case we should error
                obj.size = size;

            catch err
                rethrow(err);
            end
%             obj.initialized = true;
        end
    end
        
    methods
        function obj = set.field(obj, val)
            assert(ischar(val),     'Base.Meas.field must be a string')
            assert(~isempty(val),   'Base.Meas.field cannot be empty.')
            assert(isvarname(val), ['Base.Meas.field must be a valid struct field name, but "' val '" is not according to isvarname()']);
            
            obj.field = val;
        end
        function obj = set.name(obj, val)
            assert(ischar(val),     'Base.Meas.name must be a string')
            
            obj.name = val;
        end
        function obj = set.unit(obj, val)
            assert(ischar(val),     'Base.Meas.unit must be a string')
            
            obj.unit = val;
        end
        
        function obj = set.size(obj, val)
            obj.size = val;
        end
        function obj = set.dims(obj, val)
            obj.dims = val;
        end
        function obj = set.scans(obj, val)
            obj.scans = val;
        end
        
        function label = get_label(obj)
            if isempty(obj.unit)
                label = obj.name;
            else
                label = sprintf('%s [%s]', obj.name, obj.unit);
            end
        end
        
%         function md = metadata(obj)
%             md = struct('size', obj.size,...
%                         'name', obj.name,...
%                         'unit', obj.unit,...
%                         'dims', obj.dims,...
%                         'scans', obj.scans)
%         end
    end
    
    methods
        function extendedMeas = extendBySweep(obj, sweep, tag)
            extendedMeas = Base.Meas(   [sweep.size() obj.size(obj.size > 1)], ...
                               'field', [tag obj.field], ...
                                'unit', obj.unit, ...
                                'name', obj.name, ...
                                'dims', [sweep.sdims obj.dims], ...
                               'scans', [sweep.sscans obj.scans]);
        end
    end
end
