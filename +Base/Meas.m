classdef Meas < matlab.mixin.Heterogeneous
    properties
        size    = [1 1];    % Size of numeric data returned by this Meas.
        
        name    = '';
        unit    = '';
        
        dims    = {};
        scns    = {};
    end
    
    methods
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
                
                parse(p,varargin{:});
                
                if size_in_parser
                    size = p.Results.size;
                end

                % Assign props
                for ii = 1:nprops
                    mp = mps(ii);
                    if ~mp.Hidden && ~mp.Abstract && ~mp.Constant
                        obj.(mp.Name) = p.Results.(mp.Name);
                    end
                end

                if isempty(obj.name)
                    obj.name = obj.property_name;
                end

                % Finally assign default (dont ignore if empty, because
                % subclass might have validation preventing empty, in which
                % case we should error
                obj.size = size;

            catch err
                rethrow(err);
            end
            obj.initialized = true;
        end
        
        function md = metadata(obj)
            md = struct('size', obj.size,...
                        'name', obj.name,...
                        'unit', obj.unit,...
                        'dims', obj.dims,...
                        'scns', obj.scns,...
            )
        end
    end
end
