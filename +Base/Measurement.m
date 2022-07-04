classdef (HandleCompatible) Measurement
    % MEASUREMENT Superclass for objects that return values.
    % Base.MeasurementHandler intends to:
    %
    %       1) Standardize data structure format, while maintaining backwards compatibility.
    %       2) Provide formatted and checked numeric data that is easy for other functions to use.
    %       3) Guide both the user and other scripts with enforced, yet opt-in, metadata. That is, the
    %           output will always include formatted metadata, which is autogenerated if the user does
    %           not opt-in.
    %
    % Base.Measurement enforces the following struct() format upon returned data:
    %
    %   d.subdata1      % Any number of fields ('subdata') which contain *formatted* and *error-checked* numeric data (with the option of error storage).
    %   d.subdata2
    %   d.subdata3
    %   d...
    %   d.meta          % *Unformatted* and *unchecked* potentially-non-numeric data.
    %   d.metadata      % Autogenerated metadata that the user can embellish based on the settings of class variables.
    %
    % This structure is enforced by the validation function which checks and potentially rearranges data before
    % returning to the user:
    %
    %   data_clean = Base.Measurement.validate(data_raw)
    %
    
    % This function uses the required property Base.Measurement.sizes to determine how many fields the
    % output should have, along with error checking and imposing size restrictions. Other unrecognized
    % fields passed via data_raw are shoved into d.meta. sizes can be in one of two formats:
    %
    %    + A struct with one field for each subdata, containing the expected numeric dimension [sz1, sz2, ...] of the subdata (i.e. the output of size(dat)).
    %    + A single numeric dimension, for which the subdata field is autoset to be .data
    %
    % Note that validate errors if the size restrictions are not followed. A use case would be imposing
    % the restriction of [1 512] data from a spectrometer.
    %
    % Other properties are optional to set, but provide useful information to the user:
    % 
    %    + names (empty OR single string OR struct of strings)
    %    + units (empty OR single string OR struct of strings)
    %    + dims  (empty OR struct of cell arrays of Base.Prefs)
    %    + scans (empty OR struct of cell arrays of 1D numeric arrays)
    %
    % If these are structs, they should have the same fields as the subdata fields. This is strict
    % for names and units, but Base.Measurement will compensate for unused fields in dims and scans. A
    % cleaned version of these properties is provided in the metadata, which contains:
    %
    %   metadata.version : Base.Measurement.version;    % Constant; not used right now.
    %   metadata.subdata : obj.subdata();       % Returns a cell array the subdata names.
    %                                           % fieldnames(d) == [obj.subdata()  {'meta', 'metadata'}]
    % 
    %   metadata.sizes   : obj.getSizes;        % If obj.sizes isn't a struct, returns struct('data', obj.sizes)
    %   metadata.names   : obj.getNames;        % If names is a string, Base.Measurement will fill a
    %                                           %   struct with struct(subdata{1}, [names ' ' subdata{1}],
    %                                           %   subdata{2}, [names ' ' subdata{2}], ... to
    %                                           %   differentiate the different subdatas to the user.  
    %   metadata.units   : obj.getUnits;        % If units is a string, then all of the subdata are assumed to have the same units
    %   metadata.dims    : obj.getDims;         % Autogenerates Base.Pref with units 'pixels' and name
    %                                           %   'X', 'Y', ... according to direction of dimension.
    %   metadata.scans   : obj.getScans;        % Autogenerates integer 1:N
    %
    % Better understanding can be gained by playing with the static function Base.Measurement.tests() to
    % see what validate will spit out for various inputs and settings.
    % 
    % Lastly, this superclass integrates with existing modules by providing the function .measure() to be
    % overwritten by subclasses. The main function .snap() calls .measure() with validation (future work:
    % adding support for custom function handles to be called instead of the .measure() function).
    %
    %%% OUTPUT FORMAT EXAMPLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % When subdata are not provided by sizes, defaults to single subdata called .data:
    %
    %   d.metadata.subdata     : {'data'}
    %    .metadata.sizes.data  : size(d.data.dat)
    %    .metadata.names.data  : 'Astounding Data'
    %    .metadata.units.data  : 'dataunits'
    %    .metadata.dims .data  : {Base.Pref     for every nonsinular dimension of size(d.data.dat)}
    %    .metadata.scans.data  : {numeric array for every nonsinular dimension of size(d.data.dat), with length equaling dimension}
    %
    %    .data.dat             : numeric array of data!
    %    .data.std             : Either 1) NaN, 2) a single number representing global std, or 3) a numeric array with the same size as size(d.data.dat)
    %
    %    .meta                 : A struct containing whatever else the user wants.
    %
    % When subdata are provided by sizes, uses the subdata field names (.data1, .data2 in the below case):
    %
    %   d.metadata.subdata     : {'data1', 'data2', ...}
    %
    %    .metadata.sizes.data1 : size(d.data1.dat)
    %    .metadata.sizes.data2 : size(d.data2.dat)
    %    .metadata.sizes...
    %
    %    .metadata.names.data1 : 'Remarkable Data'
    %    .metadata.names.data2 : 'Spectacular Data'
    %    .metadata.names...
    %
    %    .metadata.units.data1 : 'data1units'
    %    .metadata.units.data2 : 'data2units'
    %    .metadata.units...
    %
    %    .metadata.scans.data1 : {numeric array for every nonsinular dimension of size(d.data1.dat), with length equaling dimension}
    %    .metadata.scans.data2 : {numeric array for every nonsinular dimension of size(d.data2.dat), with length equaling dimension}
    %    .metadata.scans...
    %
    %    .metadata.dims .data1 : {Base.Pref     for every nonsinular dimension of size(d.data1.dat)}
    %    .metadata.dims .data2 : {Base.Pref     for every nonsinular dimension of size(d.data2.dat)}
    %    .metadata.dims ...
    %
    %    .data1.dat            : numeric array of data!
    %    .data1.std            : Either 1) empty or 2) a numeric array with the same size as size(d.data1.dat)
    %
    %    .data2.dat            : numeric array of data!
    %    .data1.std            : Either 1) empty or 2) a numeric array with the same size as size(d.data2.dat)
    %    ...
    %    .meta                 : A struct containing whatever else the user wants.
    %
    % Yet another example:
    %
    %   d.metadata.subdata     : {'noise'}
    %    .metadata.names.noise : 'Random Yet Extraordinary Data'
    %    .metadata.units.noise : 'arb'
    %    .metadata.sizes.noise : [5, 6]
    %    .metadata.scans.noise : { 1:5, 1:6 }
    %    .metadata.dims .noise : { Prefs.Empty('name', 'X', ...), Prefs.Empty('name', 'Y', ...) }
    %
    %    .noise.dat            : normrnd(0, 42, 5, 6)       % normrnd(mu, sigma, sz1, sz2)
    %    .noise.std            : 42*ones(5, 6)
    %
    %    .meta.description     : 'Look at my 5 x 6 data! It has the best error bars!'
    %    .meta.solicitation    : 'Do you want to buy some death sticks?'
    
%     properties (Hidden)
%         sizes = [1 1];      % struct of 1D numeric arrays               % Expected size of the Measurement (e.g. [512 512] ==> a 512x512 image).
%     end
%     properties (Hidden)
%         names = '';         % struct of strings                         % A name to display to the user. Should be short and succinct.
%                                                                         %       Can also be a single string, in which case the names are [names ' ' subdata]
%         units = '';         % struct of strings                         % Units of the Measurement signal (e.g. 'cts/sec' or 'V').
%                                                                         %       Can also be a single string, in which case all units for all subdatas are the same.
%     end
%     properties (Hidden) %(SetAccess = private)
% 		dims  = struct();   % struct of cell arrays of Base.Prefs       % Can be empty, in which case returned Base.Prefs will be autogenerated with units pixels
%         scans = struct();   % struct of cell arrays of numeric arrays   % Can be empty, in which case returned scans will be autogenerated 1:N
%     end

    properties(Hidden)
        measurements = [];
    end

    properties(Hidden, Constant)
        defaultstd = NaN;
    end

	methods
		function obj = Measurement()
            if ~isa(obj, 'Base.Pref') && ~isa(obj, 'Base.Sweep')
                mr = Base.MeasurementRegister.instance();
                mr.addMeasurement(obj);
            end
            
%             obj.names = 'aquatic sea mammals';
%             obj.units = 'mammals';
%             obj.sizes = struct('whale', [2 2], 'orca', [1 4], 'walrus', [1 1], 'seal', [5 1], 'seaotter', [2 2 2 2 2 2 2 2 2 2]);
		end
    end

    methods (Sealed)
        function data = measureValidated(obj, varargin)
            if numel(varargin) == 0
                try
                    data = obj.validateData(obj.measure());
                catch err
%                     warning(err.message)
                    % Throw warning?
                    data = obj.validateData(obj.blank());
                end
            else
                try
                    data = obj.validateData(obj.measure(), varargin);
                catch err
%                     warning(err.message)
                    % Throw warning?
                    data = obj.validateData(obj.blank(), varargin);
                end
            end
        end
    end
    
    methods (Hidden)
        function data = measure(obj) %#ok<STOUT> % 
%             error('Base.Measurement.measure() NotImplemented.');
            error([class(obj) '.measure() NotImplemented. See Base.Measurement to opt-in.']);
		end
    end
    
    methods (Sealed)            % The bulk of this class. 
        function md = metadata(obj)
            md.subdata = obj.subdata();
            
            md.sizes = obj.getSizes;
            md.names = obj.getNames;
            md.units = obj.getUnits;
            md.scans = obj.getScans;
            md.dims  = obj.getDims;
        end
        function d = validateData(obj, raw, varargin)
            raw_but_structured =    validateStructure(obj, raw);
            d =                     validateDimension(obj, raw_but_structured);
            
            if isempty(d.metadata) && numel(varargin) == 0  % If no other var is given, generate metadata if necessary.
                d.metadata = obj.metadata;
            end
        end
        
        function blank = blank(obj, varargin) % Gets blank data (filled with NaNs) corresponding to the expected structure and dimensions of the Measurement.
            subdata = obj.subdata;
            sizes_ = obj.getSizes();
            
            if numel(varargin) == 1 && isa(varargin{1}, 'function_handle')
                default = varargin{1};
            else
                default = @rand;
            end
            
            for ii = 1:numel(subdata)
                s = sizes_.(subdata{ii});
                if numel(s) == 1
                    s = [1 s];
                end
                blank.(subdata{ii}).dat = default(s);
%                 blank.(subdata{ii}).dat = NaN(sizes_.(subdata{ii}));
                blank.(subdata{ii}).std = Base.Measurement.defaultstd;
            end
        end
        function str = get_label_measurement(obj)
            subdata = obj.subdata;
            names_ = obj.getNames();
            units_ = obj.getUnits();
            
            for ii = 1:numel(subdata)
                str.(subdata{ii}) = [names_.(subdata{ii}) ' [' units_.(subdata{ii}) ']'];
            end
        end
        function str = get_label_measurement_single(obj, whichsubdata)
			str = get_label(obj);
            str = str.(whichsubdata);
        end
    end
    
    methods (Static, Hidden, Sealed)
        function d = validateStructureStatic(raw, sizes)
            if isstruct(raw)
                raw_fields = fieldnames(raw);
                
                assert(~isempty(raw_fields), 'Empty data cannot be validated.');     % Or return blank?
                
                metadata = [];
                
                if isfieldfast(raw_fields, 'metadata')  % Metadata takes a while to generate sometimes, so if it exists, we store it and put it back afterward.
                    metadata = raw.metadata;
                    raw = rmfield(raw, 'metadata');
                    raw_fields = fieldnames(raw);
                end
                
                if isstruct(sizes)
                    %%%%% If this Measurement has an expected structure...
                    size_fields = fieldnames(sizes);
                    
%                     assert(~isfieldfast(raw_fields, 'dat'), 'dat may not be a field of d when obj.sizes is a struct. Please put the data in the fields specified by obj.sizes.');
%                     assert(~isfieldfast(raw_fields, 'std'), 'std may not be a field of d when obj.sizes is a struct. Please put the data in the fields specified by obj.sizes.');
                    
                    
                    if numel(size_fields) == 1 && ~isfieldfast(raw_fields, size_fields{1})  % If there's only one field to fill, but this field is not present.
                        assert(~(isfieldfast(raw_fields, 'data') && isfieldfast(raw_fields, 'dat')), 'd.dat may not exist if d.data does.');
                        
                        % Then, look for things that could fit. We look for...
                        
                        if isfieldfast(raw_fields, 'dat')               % ...Either d.dat
                            d.(size_fields{1}).dat = raw.dat;
                            
                            if isfieldfast(raw_fields, 'std')
                                d.(size_fields{1}).std = raw.std;
                                meta = rmfield(raw, {'data', 'std'});
                            else
                                d.(size_fields{1}).std = Base.Measurement.defaultstd;
                                meta = rmfield(raw, 'dat');
                            end
                        elseif isfieldfast(raw_fields, 'data')          % ...Or d.data
                            assert(~isfieldfast(raw_fields, 'std'), 'd.std is alone, but must be paired with d.dat.');

                            d.(size_fields{1}) = raw.data;
                            meta = rmfield(raw, size_fields{1});
                        end
                    elseif numel(raw_fields) ~= numel(size_fields)
                        toremove = {};
                        
                        jj = 1;
                        
                        for ii = 1:numel(raw_fields)
                            if ~isfieldfast(size_fields, raw_fields{ii})    % If the field doesn't belong in d.data...
                                toremove{jj} = raw_fields{ii}; %#ok<AGROW>  % Then, plan to remove it.
                                jj = jj + 1;
                            end
                        end
                        
                        if numel(raw_fields) - numel(toremove) == numel(size_fields)
                            d = rmfield(raw, toremove);
                            meta = rmfield(raw, size_fields);     % Execute the plan.
                        else
                            % arefieldssame(raw_fields, size_fields) must be false
                            error('Data does not conform with structure assumed by obj.sizes.')
                        end
                    else
                        assert(arefieldssame(raw_fields, size_fields), 'Data does not conform with structure assumed by obj.sizes.')
                        
                        d = raw;
                        meta = struct();
                    end
                        
                    if isfieldfast(raw_fields, 'meta') && isstruct(meta.meta)   % If d.meta was also present and a struct...
                        d.meta = mergestructures(meta.meta, rmfield(meta, 'meta'));
                    else                                                        % ...Otherwise, just set the residuals to d.meta
                        d.meta = meta;
                    end

                    % At this point, we know that d has 1) fields size_fields, and 2) field .meta which is a
                    % struct. These should be the only fields of d. We need to make the size_fields fields make sense
                    % (i.e. have .dat and .std fields).
                        
                    for ii = 1:numel(size_fields)
                        subraw = d.(size_fields{ii});
                        
                        if isstruct(subraw)
                            subraw_fields = fieldnames(subraw);
                            
%                             assert(~isfieldfast(subraw_fields, 'data'), ['d.' size_fields{ii} '.data must not exist.']);
                            
                            if isfieldfast(subraw_fields, 'dat')
                                if ~isfieldfast(subraw_fields, 'std')
                                    d.(size_fields{ii}).std = Base.Measurement.defaultstd;
                                end
                                
                                if numel(subraw_fields) + ~isfieldfast(subraw_fields, 'std') == 2
                                    % All good.
                                else
                                    d.meta.(size_fields{ii}) = rmfield(d.(size_fields{ii}), {'dat', 'std'});   % d.meta.(size_fields{ii}) might be overwritten.
                                    d.(size_fields{ii}) = rmfield(d.(size_fields{ii}), fieldnames(d.meta.(size_fields{ii})));
                                end
                            else
                                assert(~isfieldfast(subraw_fields, 'std'), '.std may not exist without .dat.');
                                assert(numel(subraw_fields) == 1, ['If no fields inside d.' size_fields{ii} ' are named .dat, and there are multiple fields, we don''t know what to do.'])
                                
                                d.(size_fields{ii}).dat = d.(size_fields{ii}).(subraw_fields{1});
                                d.(size_fields{ii}).dat = rmfield(d.(size_fields{ii}), subraw_fields{1});
                                d.(size_fields{ii}).std = Base.Measurement.defaultstd;
                            end
                        else
                            temp.dat = d.(size_fields{ii});
                            temp.std = Base.Measurement.defaultstd;
                            d.(size_fields{ii}) = temp;
                        end
                    end
                    
                    d.metadata = metadata;
                    
                    return;
                else
                    %%%%% ...Otherwise, try to make the best of things and interpret a structure.
                    
                    if isfieldfast(raw_fields, 'dat')                               % If d.dat exists...
                        assert(~isfieldfast(raw_fields, 'data'), 'd.dat may not exist if d.data does.');
                        
                        if ~isfieldfast(raw_fields, 'std')
                            raw.std = Base.Measurement.defaultstd;
                        end

                        if numel(raw_fields) + ~isfieldfast(raw_fields, 'std') == 2     % If d.dat and d.std are the only structs... (raw_fields is not updated, so we correct the numel).
%                             d = struct('data', raw, 'meta', []);
                            d.data = raw;
                            d.meta = struct();
                        else                                                            % ...otherwise, shove the rest in d.meta
                            d.data.dat = raw.dat;
                            d.data.std = raw.std;
                            
                            if isfieldfast(raw_fields, 'meta')                          % Merge everything else into meta, creating meta if it doesn't exist
                                if ~isstruct(raw.meta)              % Meta must be a struct.
                                    warning(['Preexisting d.meta must be a struct, but it is a ' class(raw.meta) '; storing in this object in d.meta.meta'])
                                    d.meta = rmfield(raw, {'dat', 'std', 'meta'});
                                    d.meta.meta = raw.meta;
                                else
                                    d.meta = mergestructures(raw.meta, rmfield(raw, {'dat', 'std', 'meta'}));
                                end
                            else
                                d.meta = rmfield(raw, {'dat', 'std'});
                            end
                        end
                        
                        d.metadata = metadata;o

                        return;
                    end
                    
                    if numel(raw_fields) == 1 && ~isfieldfast(raw_fields, 'data')   % If one (non-.data) field exists, then we assume that this is the correct one and switch the name to .data.
                        assert(~isfieldfast(raw_fields, 'std'),     'd.std is alone, but must be paired with d.dat');
                        assert(~isfieldfast(raw_fields, 'meta'),    'd.meta is alone, but there''s nothing to be meta about without data.');
                        assert(~isfieldfast(raw_fields, 'metadata'),'d.metadata is alone, but there''s nothing to be metadata about without data.');
                        
                        raw.data = raw.(raw_fields{1});     % Use the raw.data logic to sort this one field by renaming the field to 'data'.
                        raw = rmfield(raw, raw_fields{1});  % But be sure to remove the old name after transfering to .data.
                        raw_fields = {'data'};              % And tell it that everything is kosher.
                    end

                    if isfieldfast(raw_fields, 'data')                              % if d.data exists...
                        if isfieldfast(raw_fields, 'meta')                          % Merge everything else into meta, creating meta if it doesn't exist
                            if ~isstruct(raw.meta)              % Meta must be a struct.
                                warning(['Preexisting d.meta must be a struct, but it is a ' class(raw.meta) '; storing in this object in d.meta.meta'])
                                meta = rmfield(raw, {'data', 'meta'});
                                meta.meta = raw.meta;
                            else
                                meta = mergestructures(raw.meta, rmfield(raw, {'data', 'meta'}));
                            end
                        else
                            meta = rmfield(raw, 'data');
                        end
                        
                        if isstruct(raw.data)
                            data_fields = fieldnames(raw.data);
                            
                            assert(~isempty(data_fields), 'd.data must not be an empty struct.');

                            assert(isfieldfast(data_fields, 'dat'), 'If d.data is a struct, then d.data.dat must exist.')

                            d.data.dat = raw.data.dat;
                            
                            if isfieldfast(data_fields, 'std')
                                d.data.std = raw.data.std;
                            else
                                d.data.std = Base.Measurement.defaultstd;
                            end
                            
                            assert(~isfieldfast(data_fields, 'meta'), 'd.data.meta must not exist.')
                            
                            % Push the rest of the fields in .data to .meta
                            meta = rmfield(raw.data, {'dat', 'std'});
                        else
                            d.data.dat = raw.data;  % Leave it for validateDimension to check numeric.
                            d.data.std = Base.Measurement.defaultstd;
                        end
                        
                        d.meta = meta;
                        d.metadata = metadata;
                        
                        return;
                    end
                    
                    error('Cannot interpret obj.sizes-less data struct d if it is not singular and has neither d.dat nor d.data.');
                end
            else
                if isstruct(sizes)
                    size_fields = fieldnames(sizes);
                    
                    assert(length(size_fields) == 1, ['Non-struct data can only go into one field, but we received ' num2str(length(size_fields))]);
                    
                    d.(size_fields{1}).dat = raw;
                    d.(size_fields{1}).std = Base.Measurement.defaultstd;
                    d.meta = struct();
                    d.metadata = [];
                elseif ~isempty(raw)
                    d.data.dat = raw;
                    d.data.std = Base.Measurement.defaultstd;
                    d.meta = struct();
                    d.metadata = [];
                else
                    error('Empty data cannot be validated.')
                end
            end
        end
    end
    methods (Hidden, Sealed)    % Helper functions for the above.
        function d = validateStructure(obj, raw)
            d = Base.Measurement.validateStructureStatic(raw, obj.getSizes);
        end
        function raw = validateDimension(obj, raw)
            subdata = obj.subdata;
            sizes_ = obj.getSizes();
            
            for ii = 1:numel(subdata)
                this = raw.(subdata{ii});
                
                if ~isnumeric(this.dat)
                    error(['d.' subdata{ii} '.dat must be numeric.']);
                end
                if ~isnumeric(this.std)
                    error(['d.' subdata{ii} '.std must be numeric.']);
                end
                
                datsize = size(this.dat);
                stdsize = size(this.std);
                expsize = sizes_.(subdata{ii});
                
                datsizeNonsingleton = datsize(datsize ~= 1);
                expsizeNonsingleton = expsize(expsize ~= 1);
                
                if ~all(datsizeNonsingleton == expsizeNonsingleton)
                    error(['d.' subdata{ii} '.dat (size [ ' num2str(datsize) ' ]) must be the same size as obj.getSizes().' subdata{ii} ' (size [ ' num2str(expsize) ' ]).']);
                end
                if all(stdsize == [1 1])
                    % Good.
                elseif ~(all(~stdsize) || all(datsize == stdsize))
                   	error(['d.' subdata{ii} '.std (size [ ' num2str(stdsize) ' ]) must be either empty or the same size and shape as d.' subdata{ii} '.dat (size [ ' num2str(datsize) ' ]).']);
                end
            end
        end
    end
    
    methods (Hidden)
        function subdata = subdata(obj)
%             obj.measurements
            subdata = arrayfun(@(m)(m.field), obj.measurements, 'UniformOutput', false);
%             subdata
%             if isstruct(obj.sizes)
%                 subdata = fieldnames(obj.sizes);
%                 
%                 if numel(subdata)
%                     return;         % If all is good, return, but...
%                 end                 % If subdata = struct([]), continue...
%             end
%             
%             subdata = {'data'};
        end
        function tf = subdataDefined(obj)
            tf = true;
%             tf = isstruct(obj.sizes);
%             switch 'data'
%                 case fieldnames(obj.sizes)
%                     tf = false;
%                 otherwise
%                     tf = true;
%             end
        end
        function N = getN(obj)
            N = numel(obj.subdata());
        end
        function N = subdatas(obj)
            warning('This will be removed.')
            N = numel(obj.subdata());
        end
        function N = nmeas(obj)
            N = numel(obj.subdata());
        end
        function D = dimensions(obj)
            s = obj.getSizes;
            sd = obj.subdata;
            
            D = [];
            
            for ii = 1:numel(sd)
                this = s.(sd{ii});
%                 D = [D this(this > 1)]; %#ok<AGROW>
                D = [D sum(this > 1)]; %#ok<AGROW>
            end
        end
    end
    
    methods (Hidden)            % Get the main vars. Not get.var() cleaned versions are returned.
        function sizes = getSizes(obj)
            sizes = struct();
            
            for meas = obj.measurements
                sizes.(meas.field) = meas.size;
            end
        end
        function names = getNames(obj)
            names = struct();
            
            for meas = obj.measurements
                names.(meas.field) = meas.name;
            end
        end
        function units = getUnits(obj)
            units = struct();
            
            for meas = obj.measurements
                units.(meas.field) = meas.unit;
            end
        end
        function dims  = getDims(obj)
            dims = struct();
            
            for meas = obj.measurements
                if isempty(meas.scans)
                    [dims.(meas.field), ~] = Base.Measurement.makeAutogeneratedDimsScans(meas.size, meas.name, 'dims');
                    meas.dims = dims.(meas.field);
                else
                    dims.(meas.field) = meas.dims;
                end
            end
        end
        function scans = getScans(obj)
            scans = struct();
            
            for meas = obj.measurements
                if isempty(meas.scans)
                    [~, scans.(meas.field)] = Base.Measurement.makeAutogeneratedDimsScans(meas.size, meas.name, 'scans');
                    meas.scans = scans.(meas.field);
                else
                    scans.(meas.field) = meas.scans;
                end
            end
        end
        function l     = getLabels(obj)
            n = obj.getNames();
            u = obj.getUnits();
            
            sd = obj.subdata();

            for ii = 1:length(sd)
                if isempty(u.(sd{ii}))
                    l.(sd{ii}) = n.(sd{ii});
                else
                    l.(sd{ii}) = [n.(sd{ii}) ' [' u.(sd{ii}) ']'];
                end
            end
        end
%         function obj = set_measurements(obj, measurements_)
%             obj.measurements = measurements_;
%         end
    end
    
    methods (Hidden, Static)
        function [dims, scans] = makeAutogeneratedDimsScans(size_, name, varargin)
            X = 1:length(size_);
            nonsingular = X(size_ > 1);
            
            N = sum(size_ > 1);
            
            dims  = cell(1, N);
            scans = cell(1, N);
            
            if N == 0
                return;
            elseif N <= 6
                dimchar = 'XYZUVW';
            elseif N <= 26
                dimchar = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
            else
                error(['Insanity exceeds maximum allowable levels: ' num2str(N) ' > 26.']);
            end
            
            assert(numel(varargin) <= 1);
            
            for ii = 1:N
                if isempty(varargin) || strcmp(varargin{1}, 'dims')
                    dims{ii} = Prefs.Empty([name ' ' dimchar(ii)], size_(nonsingular(ii)));
                end
                if isempty(varargin) || strcmp(varargin{1}, 'scans')
                    scans{ii} = 1:size_(nonsingular(ii));
                end
            end
        end
    end
    
    methods (Hidden, Static)
        function tests()        % Helps with debugging .validation(). Needs more tests.
            obj = Base.Measurement();
            
%             test = {NaN,...
%                     [],...
%                     struct(),...
%                     struct('std', []),...
%                     struct('data', [], 'dat', []),...
%                     struct('std', [], 'dat', []),...
%                     struct('dat', [], 'std', []),...
%                     struct('dat', 1, 'std', 2, 'meta', 3,                                   'many', 'a', 'junk', 'b', 'fields', 'c'),...
%                     struct('dat', 1, 'std', 2, 'meta', struct(),                            'many', 'a', 'junk', 'b', 'fields', 'c'),...
%                     struct('dat', 1, 'std', 2, 'meta', struct('junk', 'oops, duplicate'),   'many', 'a', 'junk', 'b', 'fields', 'c'),...
%                     struct('whale', [2 2], 'orca', [1 4], 'seal', [5 1], 'walrus', [1 1], 'seaotter', [2 2 2 2 2 2 2 2 2 2],...
%                             'dat', 1, 'std', 2, 'meta', struct('junk', 'oops, duplicate'),   'many', 'a', 'junk', 'b', 'fields', 'c'),...
%                     struct('whale', [2 2], 'orca', [1 4], 'seal', [5 1], 'walrus', [1 1], 'seaotter', [2 2 2 2 2 2 2 2 2 2],...
%                             'meta', struct('junk', 'oops, duplicate'),   'many', 'a', 'junk', 'b', 'fields', 'c'),...
%                     struct('whale', [2 2], 'orca', [1 4], 'seal', [5 1], 'walrus', [1 1], 'seaotter', [2 2 2 2 2 2 2 2 2 2],...
%                             'meta', struct('notjunk', 'no duplicate'),   'many', 'a', 'junk', 'b', 'fields', 'c'),...
%                     obj.blank()};
                
%             test = {struct('dat', 1, 'std', 2, 'meta', struct(), 'many', 'a', 'junk', 'b', 'fields', 'c')};
            
            test = {obj.blank()};
            
            test{1}.metadata = obj.metadata();

            clc
            
            N = 1000;
            
            for ii = 1:length(test)
                disp('Before:   ===== ===== ===== ===== =====')
                fn_structdisp(test{ii})
                try
                    d = obj.validate(test{ii});
                    disp('After:    ----- ----- ----- ----- -----')
                    fn_structdisp(d)
%                     try
%                         e = obj.validate(d);
%                     catch err
%                         disp('Repeat Failed:  !!!!! !!!!! !!!!! !!!!!')
%                         disp( getReport( err, 'extended', 'hyperlinks', 'on' ) )
%                     end
%                     
%                     if ~isequal(d, e)   % Repeated validations should leave data unchanged.
%                         disp('Repeat Changed: !!!!! !!!!! !!!!! !!!!!')
%                         fn_structdisp(obj.validate(e))
%                     end
                catch err
                    disp('Invalid because: ---- ----- ----- -----')
                    disp( getReport( err, 'extended', 'hyperlinks', 'on' ) )
                end
                
                try
                    tic
                    for jj = 1:N
                        d = obj.validate(test{ii}); %#ok<NASGU>
                    end
                    disp(['...' num2str(toc/N*1e3,4) ' ms']);
                catch
                end
            end
        end
    end
end

function tf = isfieldfast(fields, str)
    switch str
        case fields
            tf = true;
        otherwise
            tf = false;
    end
end
function tf = arefieldssame(afields, bfields)
    if numel(afields) ~= numel(bfields)
        tf = false;
        return;
    end

    tf = true;
    
    for ii = 1:length(afields)
        tf = tf && isfieldfast(bfields, afields{ii});
    end
    
    for ii = 1:length(bfields)
        tf = tf && isfieldfast(afields, bfields{ii});
    end
end
function c = mergestructures(a, b)
    afields = fieldnames(a);
    bfields = fieldnames(b);
    
    if numel(afields) > numel(bfields)
        for ii = 1:length(bfields)
            assert(~isfieldfast(afields, bfields{ii}), ['Cannot merge structures; duplicate field "' bfields{ii} '".']);
            a.(bfields{ii}) = b.(bfields{ii});
        end
        c = a;
    else
        for ii = 1:length(afields)
            assert(~isfieldfast(bfields, afields{ii}), ['Cannot merge structures; duplicate field "' afields{ii} '".']);
            b.(afields{ii}) = a.(afields{ii});
        end
        c = b;
    end
end