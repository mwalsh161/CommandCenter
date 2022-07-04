classdef PrefRegister < Base.Singleton
    % PREFREGISTER records every Base.Pref that is created. Base.Module notifies
    % Base.PrefRegister via the .addPref(parent, pref) function. The Base.Module itself is also
    % recorded, and Base.PrefRegister checks if this object is deleted before reporting Base.Prefs to the
    % user. Note that memory is session-based.
    
    properties (SetAccess = private)
        register = {};
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
        function removeDead(obj)
            for ii = length(obj.register):-1:1
                if isempty(obj.register{ii}.parent) || ~isvalid(obj.register{ii}.parent)
                    obj.register(ii) = [];
                end
            end
        end
        function modules = getModules(obj, isHTML)
            if nargin < 2
                isHTML = false;
            end
            
            modules = cell(1, length(obj.register));
            for ii = 1:length(obj.register)
                modules{ii} = obj.register{ii}.parent.encodeReadable(isHTML);
            end
        end
        function menu = getMenu(obj, parentObject, callback, varargin)
            % .getMenu returns a uimenu object with Base.PrefHanders as menus and child Base.Prefs as submenus.
            % When a submenu is clicked, `callback` is called with the clicked Base.Pref as argument. This is
            % intended to return the clicked Base.Pref to whichever UI element requested the menu in the first
            % place.
            assert(nargin > 2, 'Base.PrefRegister.getMenu: parentObject (figure or uimenu) and callback (function_handle) must be provided as arguments of getMenu().')
            
            nargin(callback)
            
%             assert(nargin(callback) == 1, 'Base.PrefRegister.getMenu: Callback must accept exactly one argument.');
            assert(mod(numel(varargin), 2) == 0, 'Base.PrefRegister.getMenu expects an even number of ''Name'', Value pairs.');
            
            obj.removeDead()
            [modules, I] = sort(obj.getModules(true));
            
            deleteAfter = isempty(parentObject);
            
            if isempty(parentObject)
                parentObject = figure('name','Select Module','IntegerHandle','off','menu','none','HitTest','off',...
                 'toolbar','none','visible','off','units','characters','resize','off');
                parentObject.Position(3:4) = [60 ,0];
            end
            
            switch parentObject.Type
                case 'figure'
%                     menu = uicontextmenu; %('Parent', parent);
%                     parentObject.UIContextMenu = menu;
                    menu = uimenu(parentObject, 'Text', 'Prefs');
                    parentObject.Visible = 'on';
                case {'uicontextmenu', 'uimenu'}
                    menu = parentObject;
                otherwise
                    error([parentObject.Type ' is an unrecognized object for Base.PrefRegister.getMenu.']);
            end
            
            preffound = false;
            
            if ~isempty(modules)
                for ii = 1:length(modules)
                    prefs = fields(obj.register{I(ii)}.prefs);

                    folder = uimenu(menu);

                    localpreffound = false;

                    for jj = 1:length(prefs)    % First fields will always be .parent
                        pref = obj.register{I(ii)}.prefs.(prefs{jj});

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

                            parent_classFull = obj.register{I(ii)}.parent.encodeReadable(true); %makeParentString(obj.register.(modules{ii}).parent, pref, true);
%                                 pref.parent_class = parent_classFull;

                            folder.Label = ['<html>' parent_classFull];

                            readonly = '';
                            if pref.readonly
                                readonly = ', <font face="Courier" color="blue"><i>readonly</i></font>';
                            end

                            prefclass = strsplit(class(pref), '.');

                            label = ['<html>' pref.get_label() ' (<font face="Courier" color="green">.' pref.property_name '</font>, <font face="Courier" color="blue">' prefclass{end} '</font>' readonly ')</html>'];

                            if deleteAfter
                                uimenu(folder, 'Text', label, 'UserData', struct('callback', callback, 'pref', pref), 'Callback', @menu_Callback);
%                                 uimenu(folder, 'Text', label, 'UserData', pref, 'Callback', @(s,e)(delete(s.Parent)&&delete(s)&&callback(pref)));
%                                 uimenu(folder, 'Text', label, 'UserData', pref, 'Callback', @(s,e)(test(s,e),callback(pref)));
                            else
                                uimenu(folder, 'Text', label, 'UserData', pref, 'Callback', @(s,e)(callback(pref)));
                            end
                        end
                    end

                    if ~localpreffound
                        delete(folder);
                    end
                end
            end
            
            if isempty(obj.register)
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
            for ii = 1:length(obj.register)
                if isequal(obj.register{ii}.parent, parent)
                    obj.register{ii}.prefs.(pref.property_name) = pref;
                    
                    return;
                end
            end

            obj.register{end+1} = struct('parent', pref.parent, 'prefs', struct(pref.property_name, pref));
        end
        function val = getPref(obj, pref_name, parent_singleton_id)
            % Find preference by name in PrefRegister in case the preference cannot be accessed by module name directly.
            obj.removeDead();
            [modules, I] = sort(obj.getModules(true));
            for ii = 1:length(modules)
                prefs = fields(obj.register{I(ii)}.prefs);
                for jj = 1:length(prefs)    % First fields will always be .parent
                    pref = obj.register{I(ii)}.prefs.(prefs{jj});
                    if strcmp(pref_name, pref.property_name) && strcmp(parent_singleton_id, pref.parent.singleton_id)
                        val = pref;
                        fprintf("Find pref %s.%s(%s) by name %s\n", pref.parent.namespace, pref.name, pref.property_name, pref_name);
                        return;
                    end
                end
            end
            warning("Pref %s not found in PrefRegister.\n", pref_name);

        end
        function delete(obj)
            obj.register = [];    % Prevent objects from being deleted by getting rid of reference to the struct beforehand. Note that record of these objects will be erased.
        end
    end
end

function menu_Callback(s,~)
    s.UserData.callback(s.UserData.pref);
    while isa(s, 'matlab.ui.container.Menu')
        s = s.Parent;
    end
    delete(s)
end