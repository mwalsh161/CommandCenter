classdef PrefRegister < Base.Singleton
    % PREFREGISTER records every Base.Pref that is created. Base.PrefHandler notifies
    % Base.PrefRegister via the .addPref(parent, pref) function. The Base.PrefHandler itself is also
    % recorded, and Base.PrefRegister checks if this object is deleted before reporting Base.Prefs to the
    % user. Note that memory is session-based.
    
    properties (SetAccess = private)
        % Format:
        %
        %   register.PrefHandler1_name.parent           : Base.PrefHandler
        %
        %   register.PrefHandler1_name.prefs.pref1_name : Base.Pref
        %   register.PrefHandler1_name.prefs.pref2_name : Base.Pref
        %   register.PrefHandler1_name.prefs....
        %
        %   register.PrefHandler2_name....
        %
        %   register....
        %
        register = struct();
    end
    
    methods (Access = private)
        function obj = PrefRegister()
            
        end
    end
    
    methods (Static)
        function singleton = instance
            mlock
            persistent local
            if isempty(local) || ~isvalid(local)
                local = Base.PrefRegister;
            end
            singleton = local;
        end
    end
        
    methods
        function menu = getMenu(obj, parentObject, callback, varargin)
            % .getMenu returns a uimenu object with Base.PrefHanders as menus and child Base.Prefs as submenus.
            % When a submenu is clicked, `callback` is called with the cliced Base.Pref as argument. This is
            % intended to return the clicked Base.Pref to whichever UI element requested the menu in the first
            % place.
            
            assert(nargin(callback) == 1, 'Base.PrefRegister.getMenu: Callback must accept exactly one argument.');
            assert(mod(numel(varargin), 2) == 0, 'Base.PrefRegister.getMenu expects an even number of ''Name'', Value pairs.');
            
            modules = sort(fields(obj.register));
            
            if isempty(parentObject)
                parentObject = figure;
            end
            
            switch parentObject.Type
                case 'figure'
                    menu = uicontextmenu; %('Parent', parent);
                    parentObject.UIContextMenu = menu;
                case {'uicontextmenu', 'uimenu'}
                    menu = parentObject;
                otherwise
                    error([parentObject.Type ' is an unrecognized object for Base.PrefRegister.getMenu.']);
            end
            
            preffound = false;
            
            if ~isempty(modules)
                for ii = 1:length(modules)
                    if isempty(obj.register.(modules{ii}).parent) || ~isvalid(obj.register.(modules{ii}).parent)
                        obj.register = rmfield(obj.register, modules{ii});      % Remove the field if the module has been deleted
                    else
                        prefs = fields(obj.register.(modules{ii}).prefs);

                        folder = uimenu(menu);

                        localpreffound = false;

                        for jj = 1:length(prefs)    % First fields will always be .parent
                            pref = obj.register.(modules{ii}).prefs.(prefs{jj});

                            shouldAdd = true;

                            for kk = 1:2:numel(varargin)    % Check that it satisfies the properties in varargin
                                name = varargin{kk};
                                value = varargin{kk+1};

                                assert(ischar(name), 'Base.PrefRegister.getMenu requires that Names in Name, Value pairs be strings')

                                if isprop(pref, name) || ismethod(pref, name)   % If the property is not equal to the value, or the property does not exist, then the user doesn't want this pref. Change this to include hidden properties?
                                    shouldAdd = shouldAdd && isequal(pref.(name), value);
                                else                 
                                    shouldAdd = false;
                                end
                            end

                            if shouldAdd
                                preffound = true;
                                localpreffound = true;

                                parent_classFull = makeParentString(obj.register.(modules{ii}).parent, pref, true);
                                pref.parent_class = parent_classFull;

                                folder.Label = ['<html>' parent_classFull];

                                readonly = '';
                                if pref.readonly
                                    readonly = ', <font face="Courier" color="blue"><i>readonly</i></font>';
                                end

                                prefclass = strsplit(class(pref), '.');

                                label = ['<html>' pref.get_label() ' (<font face="Courier" color="green">.' pref.property_name '</font>, <font face="Courier" color="blue">' prefclass{end} '</font>' readonly ')</html>'];

                                uimenu(folder, 'Text', label, 'UserData', pref, 'Callback', @(s,e)(callback(pref)));
                            end
                        end

                        if ~localpreffound
                            delete(folder);
                        end
                    end
                end
            end
            
            if isempty(fields(obj.register))
                uimenu(menu, 'Label', '<html>No Modules found', 'Enable', 'off', 'Tag', 'module');
                return
            end
            
            if ~preffound
                noprefmessage = '<html>No valid prefs found';
                
                try
                    betterprefmessage = ' with properties satisfying';
                    for kk = 1:2:numel(varargin)    % Check that it satisfies the properties in varargin
                        name = varargin{kk};
                        value = varargin{kk+1};
                        
                        betterprefmessage = [betterprefmessage '<br><font face="Courier New" color="red">  ' name ' : ' num2str(value)]; %#ok<AGROW>
                    end
                    
                    noprefmessage = [noprefmessage betterprefmessage];
                catch
                end
                    
                uimenu(menu, 'Label', noprefmessage, 'Enable', 'off', 'Tag', 'module');
            end
        end
    end
    
    methods
        function addPref(obj, parent, pref)
            % Adds pref to the register under the field corresponding to the parent.
            parent_name = pref.parent_class;
            parent_name = strrep(parent_name, '.', '_');
            
            if ~isfield(obj.register, parent_name)
                obj.register.(parent_name).parent = parent;
            elseif isvalid(obj.register.(parent_name).parent)
                if ~isequal(obj.register.(parent_name).parent, parent)    % If this class isn't the same class...
                    pref.parent_class = [pref.parent_class '_'];    % ...then add an underscore and recurse.
                    obj.addPref(parent, pref)
                    return;
                end
            elseif ~isvalid(obj.register.(parent_name).parent)
                obj.register.(parent_name).parent = parent;
            end

            obj.register.(parent_name).prefs.(pref.property_name) = pref;   % This still works if set_meta_pref is called on the same pref.
        end
        function delete(obj)
            obj.register = [];    % Prevent objects from being deleted by getting rid of reference to the struct beforehand. Note that record of these objects will be erased.
        end
    end
end

function str = makeParentString(parent, pref, isHTML)
    str = strrep(strip(pref.parent_class, '_'), '_', '.');
    if ~isempty(parent.singleton_id) && ischar(parent.singleton_id)
        if isHTML
            str = [str '(<font face="Courier New" color="purple">''' parent.singleton_id '''</font>)'];
        else
            str = [str '(''' parent.singleton_id ''')'];
        end
    end
end