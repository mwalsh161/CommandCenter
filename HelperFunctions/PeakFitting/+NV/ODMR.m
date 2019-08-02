function outstruct = ODMR(x,y,varargin)
%ODMR Fit an NV single-sided ODMR model to frequency and normalized intensity data
%   Will fit N14 and/or N15 models with optional C13 splittings. If a
%   parallel pool is avaiable, it will be used (but not created).
%   ***********************************************************************
%   WARNING: For some combinations of C13 splittings and Zeeman splittings
%       used in the experiment, there could be models NOT accounted for in this
%       function where the other ms state's split level is visible/close to the
%       "single-sided" ms level under inspection. However, this is rare.
%   ***********************************************************************
%   The model consists of dips of the form 1-peak(a,b,c), where a is the
%   amplitude, b is the location (GHz), and c is the FWHM (MHz).
%   Each peak in the hyperfine transitions will share a and c. The splittings
%   are also defined. For a full model, the free parameters are:
%       NV14: 1 - (peak(a,b-2.2,c) + peak(a,b,c) + peak(a,b+2.2,c)
%       NV15: 1 - (peak(a,b-3.1/2,c) + peak(a,b+3.1/2,c)
%   The user can specify 'fitNormalization' as true to include an
%   additional free parameter, d, which is the normalization value
%   (replacing 1 in the above equation).
%   The free parameters are: (a, b, c, [d]).
%
%   Inputs; brackets indicate name,value optional pairs:
%     x: vector of frequency values in GHz
%     y: vector of normalized intensity values
%     [FitType]: "gauss" or "lorentz" (default "lorentz")
%       Default: "lorentz"
%     [isotope]: Character array in: {"14","15","both"}
%       Default: "14"
%     [C13]: Cell array of any combination of sites referenced in above
%       paper (with the additional "all"): {"0","A","B","C","D","E","G","all",""}
%       Default: {''}
%       NOTE: cells can be nested to test combinations of C13s. A nested cell
%       with n elements will produce combinations of n C13s corresponding to 
%       each combination possible. Examples:
%       {'all',{'all','all'}} -> all singles and double combos
%       {'a','b',{'a','b'}} -> {'a','b','ab',}
%       {'a', b', 'c',{'abc','abc'}} ->
%           {'a', 'b', 'c', 'aa', 'ab', 'ac', 'bc', 'bb', 'cc'}
%       {{'ab','ab','ab'}} -> {'aaa','aab','abb','bbb'}
%     [fitNormalization]: boolean. If true, the normalization level is a
%       free parameter too.
%       Default: false
%     *The following inputs are passed directly to the fit function options*
%     [StartPoint]: See 'fit' help
%       Default: (0.05, 2.87, 5, [1])
%     [Lower]: See 'fit' help
%       Default: (0, 0, 0, [0])
%     [Upper]: See 'fit' help
%       Default: (Inf, Inf, Inf, [Inf])
%     [fitoptions]: a struct with same/subset of fields as that produced by
%       fitoptions. Everything other than StartPoint, Lower and Upper will
%       be used.
%   Outputs:
%     An array of structs with fieldnames:
%       C13: One of the characters from the input options
%       iso: One of the character arrays from the input options
%       fit: The fit object associated with the model
%       gof: The goodness of fit returned by the fit function
%   Refs:
%   C13: https://iopscience.iop.org/article/10.1088/1367-2630/13/2/025021 (Table 1, A_{hfs} < 50 G)
%   N isotope: https://journals.aps.org/prb/abstract/10.1103/PhysRevB.99.161203

% Note, below all references (indices) will be inexed into these two constants
isotope_opts = {'14','15','both'};
C13_sites = {'0','A','B','C','D','E','G',''}; % labels from table 1 in ref

p = inputParser;
addRequired(p,'frequency',@(n)validateattributes(n,{'numeric'},{'column'}))
addRequired(p,'intensity',@(n)validateattributes(n,{'numeric'},{'column'}))
addParameter(p,'FitType','lorentz',@(x)any(validatestring(x,{'gauss','lorentz'})));
addParameter(p,'isotope','14',@(n)any(validatestring(n,isotope_opts)));
addParameter(p,'C13',{''},@(n)validateattributes(n,{'cell'},{'vector'}))
addParameter(p,'fitNormalization',false,@(n)validateattributes(n,{'logical'},{'scalar'}))
% Default for these will assume fitting normalization
addParameter(p,'StartPoint',[0.05, 2.87, 5, 1],@(n)validateattributes(n,{'numeric'},{'vector','finite'}))
addParameter(p,'Lower',[0,0,0,0],@(n)validateattributes(n,{'numeric'},{'vector','nonnan'}))
addParameter(p,'Upper',[Inf,Inf,Inf,Inf],@(n)validateattributes(n,{'numeric'},{'vector','nonnan'}))
addParameter(p,'fitoptions',struct(),@(n)validateattributes(n,{'struct'},{}))

parse(p,x,y,varargin{:});
UsingDefaults = p.UsingDefaults;
p = p.Results;

% Futher validation and index preparation
isotopes = find(strcmp(isotope_opts,p.isotope));
if isotopes == 3; isotopes = [1,2]; end

C13s = parse_C13(p.C13,C13_sites);

fitting_settings = {'StartPoint','Lower','Upper'};
for i = 1:length(fitting_settings)
    if ismember(fitting_settings{i},UsingDefaults)
        if ~p.fitNormalization
            p.(fitting_settings{i}) = p.(fitting_settings{i})(1:3);
        end
    else % User supplied
        n = 3 + p.fitNormalization;
        n_supplied = length(p.(fitting_settings{i}));
        assert(n_supplied==n,...
            sprintf(['Incorrect number of fitting parameters supplied for ''%s''.\n\n',...
                     'Expected %i, received %i.'],fitting_settings{i},n,n_supplied));
    end
    if isfield(p.fitoptions,fitting_settings{i})
        p.fitoptions = rmfield(p.fitoptions,fitting_settings{i});
        warning('Removed ''%s'' from fitoptions parameter.',fitting_settings{i})
    end
end

% Constants
C13 = [130, 13.723, 12.781, -8.923, -6.524, 4.21, 2.43, 0]; % splittings (MHz)
N = {[3, 2.2], [2, 3.1/2]};  % {[(3 dips), N14], [(2 dips), N15/2]} splittings (MHz)
norm = '1';
if p.fitNormalization
    norm = 'd';
end
% Prepare equation generators with a %s representing splitting value
if strcmp(p.FitType,'lorentz')
    peak = struct('amp','1/4*(c/1000)^2','eq','1/((x-b%s)^2+(1/2*c/1000)^2)');
else % gauss
    peak = struct('amp','1','eq','exp(-((x-b%s)^2/2/(c/1000/2.3548)^2))');
end

outstruct = struct('C13',[],'iso',[],'fit',[],...
        'sse',[],'rsquare',[],'dfe',[],'adjrsquare',[],'rmse',{});
pp = gcp('nocreate'); % If no pool, do not create new one.
if isempty(pp)
    nworkers = 0;
else
    nworkers = pp.NumWorkers;
end
for isoIND = 1:length(isotopes)
    iso = isotopes(isoIND);
    iso_name = isotope_opts{iso};
    % partial_out is necessary for MATLAB's simplistic indexing requirement for parfor
    partial_out = struct('C13',[],'iso',[],'fit',[],...
        'sse',[],'rsquare',[],'dfe',[],'adjrsquare',[],'rmse',cell(1,length(C13s)));
    %parfor (CsplitIND = 1:length(C13s), nworkers)
    for CsplitIND = 1:length(C13s)
        Csplits = C13s{CsplitIND};
        % Prepare initial model
        sub_model.eq = {peak.eq};
        sub_model.splitting = 0;  % MHz
        sub_model = split(sub_model, N{iso}(1), N{iso}(2)); % N splitting
        for Csplit = Csplits
            sub_model = split(sub_model, 2, C13(Csplit)); % C13 splitting
        end
        % Put model together
        for i = 1:length(sub_model.eq)
            splittingVal = ''; % If zero
            if sub_model.splitting(i)
                % '%+d' includes "+" for positive
                splittingVal = num2str(sub_model.splitting(i)/1000,'%+d'); % Splittings (MHz -> GHz)
            end
            sub_model.eq{i} = sprintf(sub_model.eq{i},splittingVal);
        end
        eq = sprintf('%s - a*%s*(%s)',norm,...
                                      peak.amp,...
                                      strjoin(sub_model.eq,' + '));
        eq = fittype(eq);
        
        % Prepare fitoptions
        opts = fitoptions(eq);
        opts.StartPoint = p.StartPoint;
        opts.Lower = p.Lower;
        opts.Upper = p.Upper;
        f = fieldnames(p.fitoptions);
        for i = 1:length(f)
            opts.(f{i}) = p.fitoptions.(f{i});
        end
        
        % Fit
        [f,gof] = fit(x, y, eq, opts);
        partial_out(CsplitIND).C13 = [C13_sites{Csplits}];
        partial_out(CsplitIND).iso = iso_name;
        partial_out(CsplitIND).fit = f;
        % Add gof to root level struct
        f = fieldnames(gof);
        for i = 1:length(f)
            partial_out(CsplitIND).(f{i}) = gof.(f{i});
        end
    end
    outstruct = [outstruct, partial_out];
end
end

function C13s = parse_C13(C13,C13_sites,~)
% C13s is a cell array of lists with indexes into the C13 constant
C13s = {};

% Take care of all shortcut
mask = strcmpi(C13,'all'); % works if C13 has nested cells too
if any(mask)
    n = sum(mask);
    C13(mask) = []; % Remove "all"
    include = C13_sites;
    if nargin == 3 % recursive call
        % all combinations will be made, so don't want to include "''"
        include = {strjoin(include,'')};
    end
    for i = 1:n
        C13 = [include, C13];
    end
end
% Parse all items in C13
for i = 1:length(C13)
    item = C13{i};
    if ischar(item)
        C13s{end+1} = [];
        if isempty(item) % The no C13 case
            C13s{end} = find(strcmp(C13_sites,item));
        else % Loop through to validate and add index for C13 sites
            C13s{end} = NaN(1,length(item));
            for j = 1:length(item)
                mask = ismember(C13_sites,upper(item(j)));
                assert(any(mask),sprintf(['A value of ''C13{%i}'' is invalid. ',...
                    'All chars must match one of these values:\n\n%s\n\n',...
                    'The char, ''%s'', did not match any of the valid values.'],...
                    i,strjoin(C13_sites,', '),upper(item(j))))
                C13s{end}(j) = find(mask); % Grab index
            end
        end
    elseif iscell(item) % Indicates we must calculate combination
        if nargin == 3 % recursive call
            error('A nested cell array cannot have a further nested cell array.')
        end
        temp = parse_C13(item,C13_sites,true); % chars -> (validated) indices
        % Combine to form all options and remove repeated combinations
        temp = combvec(temp{:});
        temp = unique(sort(temp,1)','rows'); % Grab unique ones only (order doesn't matter)
        temp = num2cell(temp,2); % Convert to cell array
        C13s = [C13s, temp'];
    else
        error('C13{%i} is of type ''%s''. Expected a char or a cell.',i,class(item))
    end
end
if nargin~=3
    % remove repeated combinations at very end of root call
    duplicates = [];
    for i = 1:length(C13s)
        if ~any(duplicates==i)
            for j = 1:length(C13s)
                if i~=j && isequal(C13s{i},C13s{j})
                    duplicates(end+1) = j;
                end
            end
        end
    end
    C13s(duplicates) = [];
end
end

function new_model = split(model,n,splitting)
% n is the branching number of the splitting
if ~splitting % If splitting is zero, do nothing
    new_model = model;
    return
end
new_model.eq = {};
new_model.splitting = [];
split_val = ((1:n)-mean(1:n))*splitting;
for i = 1:n
    new_model.eq = [new_model.eq, model.eq];
    new_model.splitting = [new_model.splitting, model.splitting + split_val(i)];
end
end
