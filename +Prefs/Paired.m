classdef Paired < Prefs.Numeric
    %PAIRED is a pref that controls other prefs. It is constructed with a array of numeric prefs (the prefs that are controlled) and a
    % cell array of function_handles (correspondences between the first [master] pref and other prefs). If N prefs and N-1
    % functions are given, the identity function @(x)(x) is prepended (the correspondence between the master and itself).
    %
    %   p = Prefs.Paired(   prefs,...   % array of Prefs.Numeric
    %                       pairings)   % cell array of function_handle
    %
    % This structure enables complex superprefs like:
    %
    %   angle   = Prefs.Double('name', 'Unit Circle', 'unit', 'deg')
    %   gx      = Galvos.get_meta_pref('x');    % Pseudocode
    %   gy      = Galvos.get_meta_pref('y');
    %
    %   p = Prefs.Paired([angle, gx, gy], { @(ang)sin(ang*pi/180)   @(ang)cos(ang*pi/180) });
    %                                       % angle -> gx           % angle -> gy
    %
    % This would produce a Pref that scans a unit circle with the galvos.

    properties (Hidden)
        default = NaN;
        ui = [];
    end
    properties (Hidden)
        min = -Inf;
        max = Inf;
    end
    properties (Hidden, Access={?Prefs.Paired, ?Base.Sweep})
        prefs       = Prefs.Numeric.empty(1,0);     % Array of prefs
        pairings    = {};                           % Array of function_handles
%         normalized  = [];                           % If function_handles
    end

    methods
        function obj = Paired(prefs, pairings)
            assert(isa(prefs, 'Prefs.Numeric'), 'Prefs.Paired prefs must be Prefs.Numeric');
            
            assert(iscell(pairings) || isempty(pairings), 'Prefs.Paired pairings must be a cell array of function_handles');
            if numel(prefs)-1 == numel(pairings)    % If we have one less pairing, prepend a first as identity.
                pairings = [{@(x)(x)} pairings];
            end
            assert(numel(prefs) == numel(pairings), 'Prefs.Paired must have the same number of prefs as pairing functions (or -1).');
            
            for ii = 1:length(pairings)
                assert(isa(pairings{ii}, 'function_handle'), 'Prefs.Paired pairings must be a cell array of function_handles');
                assert(nargin(pairings{ii}) == 1, 'Prefs.Paired pairings must be a cell array of function_handles with nargin == 1');
                assert(abs(nargout(pairings{ii})) == 1, 'Prefs.Paired pairings must be a cell array of function_handles with nargout == +/-1');
                try     % Make sure the functions support vectors.
                    assert(numel(pairings{ii}([prefs(1).default prefs(1).default])) == 2, 'Returned vector was not the same size as input');
                catch err
                    warning('Prefs.Paired pairing functions must accept vectors.');
                    rethrow(err);
                end
            end
            
            obj.prefs = prefs;
            obj.pairings = pairings;
            
            % Pull over stuff from Master.
            master = prefs(1);
            
            obj.default = master.default;
            obj.min = master.min;   % This might break if pairings{1} ~= @(x)(x)... Not sure how to deal with this.
            obj.max = master.max;
            
            % Deal with names;
            obj.property_name = master.property_name;
            if isempty(obj.property_name)
                obj.property_name = 'composite';    % Change?
            end
            
            obj.name = master.name;
            if isempty(obj.name)
                obj.name = obj.property_name;
            end
            obj.name = [obj.name ' (+' num2str(numel(obj.prefs)-1) ')'];
            
            % Deal with unit;
            otherunits = '';
            for ii = 2:length(obj.prefs)
                u = obj.prefs(ii).unit;
                if isempty(u)
                    u = '''''';
                end
                
                otherunits = [otherunits '+' u ', ']; %#ok<AGROW>
            end
            
            obj.unit = [obj.unit ' (' otherunits(1:end-2) ')'];
            
            % Deal with help_text
            obj.help_text = ['Paired Pref Composed of ' num2str(numel(obj.prefs)) ' prefs'];
                
            for ii = 1:length(obj.prefs)
                obj.help_text = [obj.help_text '<br/><br/>' '(' num2str(ii) ') '...
                                    obj.prefs(ii).get_label()...
                                    obj.prefs(ii).help_text];
            end
        end
        
        function tf = isnumeric(~)
            tf = true;
        end
        
        function validate(obj, val)
            for ii = 1:length(obj.prefs)
%                 try
                obj.prefs(ii).validate(obj.pairings{ii}(val));
%                 catch err
%                     % Should error descriptively.
%                 end
            end
        end
        function validateScan(obj, scan)
            for x = scan
                obj.validate(x);
            end
        end
        function multiscan = getMultiVector(obj, scan)
            assert(numel(scan) == length(scan), 'Prefs.Paired.getMultiScan(scan) scans must be scalars or vectors.')
            
            multiscan = NaN(length(obj.prefs), length(scan));
            
            for ii = 1:length(obj.prefs)
                multiscan(ii, :) = obj.pairings{ii}(scan);
            end
        end
        
        function val = read(obj)
            val = obj.prefs(1).read();
        end
        function tf = writ(obj, val)
            for ii = 1:length(obj.prefs)
                tf = tf && obj.prefs(ii).writ(obj.paired{ii}(val)); % Write 
            end
        end
    end
end
