classdef ModuleInstance < Base.Pref
    %MODULE Allow particular types of module arrays
    %   NOTE: The UI will interpret whatever array size as an Nx1 when displaying
    %   If remove_on_delete is set to true, then the actual data value will 
    %   get reshaped so single entries can be removed.
    %
    %   Optional settings (as property, value pairs)
    %       inherits: cell array of class names that should be returned by
    %           SUPERCLASSES upon validation.
    %       ignore_inherits_on_empty: If ISEMPTY, ignore the superclasses
    %           of the empty vector upon validation. Useful because some
    %           superclasses won't allow an empty set because they
    %           are/contain Abstract entities.
    %       n: The maximum number of simultaneously instantiated Module
    %          instances
    %       empty_val: The value displayed is the dropdown menu when no
    %           module instances exist.
    
    properties (Hidden) % Satisfy abstract
        default = Base.Module.empty(0);
        ui = Prefs.Inputs.ModuleSelectionField;
    end
    properties % Settings
        % Superclasses required for these modules as cell array of char vectors
        inherits = {{}, @(a)true};
        % Ignore "inherits" property if the value being set satisfies ISEMPTY
        ignore_inherits_on_empty = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % Number of allowed instances simultaneously (n > 0)
        n = {1, @(a)validateattributes(a,{'numeric'},{'scalar','positive'})};
        % Value displayed for empty option
        empty_val = {'<None>', @(a)validateattributes(a,{'char'},{'vector'})};
        
        % Future updates
        % Remove instances that get deleted. NOTE: this will reshape arrays to be vectors
    %    remove_on_delete = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};  (requires handle class since we can't reassign property to module)
    end
    
    methods
        function obj = ModuleInstance(varargin)
            obj = obj@Base.Pref(varargin{:});
            % Saving prefs don't support reloading with input params, so leave out drivers
            obj.ui.module_types = {'Experiment','Stage','Imaging','Source','Database'};
        end
        
        function tosave = encodeValue(~, data)
            if ismember('Base.Pref',superclasses(data))
                % THIS SHOULD NOT HAPPEN, but haven't figured
                % out why it does sometimes yet
                data = data.value;
%                 warning('Listener for %s seems to have been deleted before savePrefs!',obj.prefs{i});
            end
                        
            if ismember('Base.Module',superclasses(data))
                tosave = {};
                
                for j = 1:length(data)
%                     tosave{end+1} = class(data(j)); %#ok<AGROW>
                    tosave{end+1} = data(j).encode(); %#ok<AGROW>
                end
            else
                error('Data was not a Base.Module.')
            end
        end
        function [data, obj] = decodeValue(obj, saved)
            if obj.HasDefault && any(ismember([{class(obj.DefaultValue)}; superclasses(obj.DefaultValue)], {'Base.Module','Prefs.ModuleInstance'}))
                if isempty(saved)               % Means it should be the default value, and we want to avoid setting.
                    error('No saved data.')     % Error to prevent setting the value.
                end
                
                for j = 1:length(saved)
%                     data(j) = eval(sprintf('%s.instance', saved{j})); % Grab instance(s) from string
                    data(j) = Base.Module.decode(saved{j}); % Grab instance(s) from string
                end
            end
        end
        
        function obj = set_ui_value(obj,val)
            obj.ui.set_value(val);
        end
        function val = get_ui_value(obj)
            val = obj.ui.get_value();
        end
        function val = clean(obj,val)
            % Future updates
            % Setup listener for deletion
            % if obj.remove_on_delete
            %     if ~isvector(val) && ~isempty(val) % [] is not a vector
            %         sz = num2str(size(val),'%ix'); sz(end) = []; % Remove trailing x
            %         warning('MODULEINSTANCE:notvector',...
            %             'Reshaping %s array to %ix1 vector since remove on delete is true.',sz,numel(val));
            %         val = val(:);
            %     end
            %     for i = 1:length(val)
            %         addlistener(val(i),'ObjectBeingDestroyed',@(~,~)obj.cleanup(val(i)));
            %     end
            % end
        end
        function validate(obj,val)
            if numel(val) > obj.n
                sz = num2str(size(val),'%ix'); sz(end) = []; % Remove trailing x
                error('MODULE:too_many','%s "%s" exceeds the maximum allowed instances of %i.',...
                    sz, class(val), obj.n)
            end
            if obj.ignore_inherits_on_empty && isempty(val)
                return
            end
            supers = [{class(val)}; superclasses(val)];  % class(val) in case of empty placeholder
            if ~all(ismember(obj.inherits, supers))
                error('MODULE:not_all_superclasses',...
                    '"%s" does not inherit required superclasses: %s',...
                    class(val), strjoin(obj.inherits,', '))
            elseif ~(ismember('Base.Module', supers) || isa(val, 'Base.Module'))
                error('MODULE:not_module','"%s" does not inherit Base.Module.', class(val))
            end
        end
    end
    
end