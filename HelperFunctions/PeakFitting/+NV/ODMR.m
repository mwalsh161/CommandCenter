function outstruct = ODMR(frequency,intensity,varargin)
%ODMR Fit an NV single-sided ODMR model to frequency and normalized intensity data
%   Will fit N14 and/or N15 models with optional C13 splittings
%   C13 Ref: https://iopscience.iop.org/article/10.1088/1367-2630/13/2/025021
%      Table 1, A_{hfs} < 50 G
%   N isotope Ref: https://journals.aps.org/prb/abstract/10.1103/PhysRevB.99.161203
%
%   The model consists of peaks of the form 1-peak(a,b,c), where a is the
%   amplitude, b is the location, and c is the FWHM.
%   Each peak in the hyperfine transitions will share a, c. The splittings
%   are also defined. For a full model, the free parameters are:
%       NV14: 1 - (peak(a,b-2.2,c) + peak(a,b,c) + peak(a,b+2.2,c)
%       NV15: 1 - (peak(a,b-3.1/2,c) + peak(a,b+3.1/2,c)
%   The user can specify 'fitNormalization' as true to include an
%   additional free parameter, d, which is the normalization value
%   (replacing 1 in the above equation).
%   The free parameters are: (a, b, c, [d]).
%
%   Inputs; brackets indicate name,value optional pairs:
%     frequency: vector of frequency values in GHz
%     intensity: vector of normalized intensity values
%     [FitType]: "gauss" or "lorentz" (default "lorentz")
%       Default: "lorenz"
%     [isotope]: Character array in: {"14","15","both"}
%       Default: "14"
%     [C13]: Character array of any combination of sites referenced in above
%       paper (with an additinal "Z" meaning none): 
%       {"Z","0","A","B","C","D","E","G"} OR the value true to test all
%       Default: 'Z'
%     [fitNormalization]: boolean. If true, the normalization level is a
%       free parameter too.
%       Default: false
%     *The following inputs are passed directly to the fit function options*
%     [StartPoint]: See 'fit' help
%       Default: (0.05, 2.87, 5/1000, [1])
%     [Lower]: See 'fit' help
%       Default: (0, 0, 0, [Inf])
%     [Upper]: See 'fit' help
%       Default: (Inf, Inf, Inf, [Inf])
%   Outputs:
%     An array of structs with fieldnames:
%       C13: One of the characters from the input options
%       iso: One of the character arrays from the input options
%       fit: The fit object associated with the model
%       gof: The goodness of fit returned by the fit function

% Note, below all references (indices) will be inexed into these two constants
isotope_opts = {'14','15','both'};
C13_sites = 'Z0ABCDEG'; % labels from table 1 in ref

p = inputParser;
addRequired(p,'frequency',@(n)validateattributes(n,{'numeric'},{'row'}))
addRequired(p,'intensity',@(n)validateattributes(n,{'numeric'},{'row'}))
addParameter(p,'FitType','lorentz',@(x)any(validatestring(x,{'gauss','lorentz'})));
addParameter(p,'isotope','14',@(n)any(validatestring(n,isotope_opts)));
addParameter(p,'C13','',@(n)islogical(n)||ischar(n))
addParameter(p,'fitNormalization',false,@(n)validateattributes(n,{'logical'},{'scalar'}))
addParameter(p,'StartPoint',NaN,@(n)validateattributes(n,{'numeric'},{'vector','finite'}))
addParameter(p,'Lower',NaN,@(n)validateattributes(n,{'numeric'},{'vector','finite'}))
addParameter(p,'Upper',NaN,@(n)validateattributes(n,{'numeric'},{'vector','finite'}))

parse(p,frequency,intensity,varargin{:});

p = p.Results;

% Futher validation and index preparation
isotopes = find(strcmp(isotope_opts,p.isotope));
if isotopes == 3; isotopes = [1,2]; end
C13s = [];
if islogical(p.C13)
    if p.C13
        C13s = 1:length(C13_sites);
    end
else % Verify user input is valid
    for c = p.C13
        mask = ismember(C13_sites,upper(c));
        assert(any(mask),sprintf(['The value of ''C13'' is invalid. ',...
            'Expected input to match one or a combination of these values:\n\n%s (or the logical true)\n\n',...
            'The input, ''%s'', did not match any of the valid values.'],C13_sites,p.C13))
        C13s(end+1) = find(mask); % Grab index
    end
end

% Constants
C13 = [0, 130, 13.723, 12.781, -8.923, -6.524, 4.21, 2.43]; % splittings (MHz)
N = {[3, 2.2], [2, 3.1/2]};  % {[(3 dips), N14], [(2 dips), N15/2]} splittings (MHz)
norm = {'1','d'};
% Prepare equation basics with a %s representing splitting value
% and a %%s for C13 splittings (e.g. a second round of sprintf
peak.lorentz = struct('amp','1/4*c^2','eq','1/((x-b%s%%s)^2+(1/2*c)^2)');
peak.gauss = struct('amp','1','eq','exp(-((x-b%s%%s)^2/2/(c/2.3548)^2))');

outstruct = struct('C13',{},'iso',{},'fit',{},'gof',{});
for iso = isotopes
    for Csplit = C13s
        % Prepare model with N splitting
        subeq = {};
        ms = linspace(-1,1,N{iso}(1)); % multiplier to splitting
        for m = ms
            Nsplit_val = ''; % case for m = 0;
            if m
                Nsplit_val = num2str(m*N{iso}(2)/1000,'%+d'); % '%+d' includes "+" for positive
            end
            % First sprintf
            subeq{end+1} = sprintf(peak.(p.FitType).eq, Nsplit_val);
        end
        % Add in C splitting
        if C13(Csplit) % Finite splitting, double terms
            subeq = [subeq subeq];
            sub_ind = 1;
            for m = [-1, 1]
                Csplit_val = num2str(m*C13(Csplit)/1000,'%+d');
                for i = 1:length(subeq)/2
                    % Second sprintf
                    subeq{sub_ind} = sprintf(subeq{sub_ind},Csplit_val);
                    sub_ind = sub_ind + 1;
                end
            end
        else
            for i = 1:length(subeq)
                % Second sprintf
                subeq{i} = sprintf(subeq{i},'');
            end
        end
        % Combine terms
        eq = sprintf('%s - a*%s*(%s)',norm{p.fitNormalization+1},...
            peak.(p.FitType).amp,...
            strjoin(subeq,' + '));
        fprintf('Iso: %s, C13: %s ->\n  %s\n',isotope_opts{iso},C13_sites(Csplit),eq);
        % Prepare fitoptions
        opts = fitoptions(eq);
        
        % Fit
        %[f,gof] = fit(frequency, intensity, opts, eq);
        outstruct(end+1).C13 = C13_sites(Csplit);
        outstruct(end).iso = isotope_opts{iso};
        %outstruct(end).fit = f;
        %outstruct(end).gof = gof;
    end
end
end

