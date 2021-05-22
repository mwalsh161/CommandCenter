classdef MeasurementRegister < Base.Singleton
    % MEASUREMENTREGISTER records every Base.MeasurementHandler that is created. Base.MeasurementHandler notifies
    % Base.MeasurementRegister via the .addMeasurement(Base.MeasurementHandler) function.
    % Base.MeasurementRegister checks if this object is deleted before reporting Base.Prefs to the 
    % user. Note that memory is session-based.
    
    properties (SetAccess = private)
        % Format:
        %
        %   register.Measurement1_name  : Base.Measurement
        %   register.Measurement2_name  : Base.Measurement
        %   register.Measurement3_name  : Base.Measurement
        %
        register = struct();
    end
    
    methods (Access = private)
        function obj = MeasurementRegister()
            
        end
    end
    
    methods (Static)
        function singleton = instance
            mlock
            persistent local
            if isempty(local) || ~isvalid(local)
                local = Base.MeasurementRegister;
            end
            singleton = local;
        end
    end
        
    methods
        function menu = getMenu(obj, parentObject, callback)
            % .getMenu returns a uimenu object with Base.PrefHanders as menus and child Base.Prefs as submenus.
            % When a submenu is clicked, `callback` is called with the cliced Base.Pref as argument. This is
            % intended to return the clicked Base.Pref to whichever UI element requested the menu in the first
            % place.
            
            assert(nargin(callback) == 1, 'Base.PrefRegister.getMenu: Callback must accept exactly one argument.');
%             assert(mod(numel(varargin), 2) == 0, 'Base.PrefRegister.getMenu expects an even number of ''Name'', Value pairs.');
            
            modules = sort(fields(obj.register));
            
            if isempty(parentObject)
                parentObject = figure;
            end
            
            switch parentObject.Type
                case 'figure'
                    menu = uicontextmenu; %('Parent', parent);
                    parentObject.UIContextMenu = menu;
                case {'uicontextmenu', 'menu'}
                    menu = parentObject;
                otherwise
                    error([parentObject.Type ' is an unrecognized object for Base.PrefRegister.getMenu.']);
            end
            
            if isempty(modules)
                uimenu(menu, 'Label', '<html>No Measurements found', 'Enable', 'off', 'Tag', 'module');
            else
                for ii = 1:length(modules)
                    if isempty(obj.register.(modules{ii})) || ~isvalid(obj.register.(modules{ii}))
                        obj.register = rmfield(obj.register, modules{ii});      % Remove the field if the module has been deleted
                    else
                        m =     obj.register.(modules{ii});
                        
                        sd =    m.subdata;
                        l =     m.getLabels;
                        s =     m.getSizes;
                        
                        str =   makeParentString(m, true);
                        
                        label = ['<html>' str ':'];

                        for ii = 1:length(sd) %#ok<FXSET>
                            label = [label '<br>' char(8594) ' ' l.(sd{ii}) ' (<font face="Courier" color="green">.' sd{ii} '</font>, <font face="Courier" color="blue">[' num2str(s.(sd{ii})) ']</font>)']; %#ok<AGROW>
                        end

                        uimenu(menu, 'Text', [label '</html>'], 'UserData', [], 'Callback', @(s,e)(callback(m)));
                    end
                end
            end
            
            % Make a menu for prefs which can be measured...
            prefs = uimenu(menu, 'Label', 'Prefs');
            
            % And populate this menu with info from PrefRegister.
            pr = Base.PrefRegister.instance();
            pr.getMenu(prefs, callback, 'isnumeric', true);
        end
    end
    
    methods
        function addMeasurement(obj, varargin)
            % Adds measurement to the register corresponding to the parent.
            if numel(varargin) == 2
                m = varargin{1};
                name = varargin{2};
            elseif numel(varargin) == 1
                m = varargin{1};
                name = strrep(class(m), '.', '_');
            end
            
            if ~isfield(obj.register, name)
                obj.register.(name) = m;
            elseif isvalid(obj.register.(name))
                if ~isequal(obj.register.(name), m) % If this class isn't the same class...
                    name = [name '_'];              % ...then add an underscore and recurse.
                    obj.addMeasurement(m, name)
                    return;
                end
            elseif ~isvalid(obj.register.(name))
                obj.register.(name) = m;
            end
        end
        function delete(obj)
            obj.register = [];    % Prevent objects from being deleted by getting rid of reference to the struct beforehand. Note that record of these objects will be erased.
        end
    end
end

function str = makeParentString(parent, isHTML)
    str = strrep(strip(class(parent), '_'), '_', '.');
    if isa(parent, 'Base.Singleton') && ~isempty(parent.singleton_id) && ischar(parent.singleton_id)
        if isHTML
            str = [str '(<font face="Courier New" color="purple">''' parent.singleton_id '''</font>)'];
        else
            str = [str '(''' parent.singleton_id ''')'];
        end
    end
end