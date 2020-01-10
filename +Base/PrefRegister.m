classdef PrefRegister < handle
    properties (Hidden, Access = private)
        register = struct();
    end
    
    properties (Hidden, Constant)
        parent_storage = 'parent____';
    end
    
    methods (Static)
        function singleton = instance
            mlock
            persistent local
            if isempty(local) || ~isvalid(local)
                local = Base.prefList;
            end
            singleton = local;
        end
    end
    
    methods (Access = protected)
        function obj = PrefRegister
            
        end
    end
        
    methods
        function menu = getMenu(obj, parentObject, callback, varargin)
            assert(nargin(callback) == 3);
            
            assert(mod(numel(varargin), 2) == 0);   % Must be an even number of 'Name', Value pairs.
            
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
                    error([parentObject.Type ' is an unrecognized object for Base.PrefRegister.getMenu.');
            end
            
            if isempty(modules)
                uimenu(menu,'label','<html>No Modules found','enable','off','tag','module');
                return
            end
            
            preffound = false;
            
            for ii = 1:length(modules)
                if isempty(obj.register.(modules{ii}).(obj.parent_storage)) || ~isvalid(obj.register.(modules{ii}).(obj.parent_storage))
                    obj.register = rmfield(obj.register, modules{ii});      % Remove the field if the module has been deleted
                else
                    prefs = fields(obj.register.(modules{ii}));
                    
                    folder = uimenu(menu, 'Text', strrep(modules{ii}, '_', '.'));
                    
                    localpreffound = false;
                    
                    for jj = 2:length(prefs)    % First field will always be .(parent_storage)
                        pref = obj.register.(modules{ii}).(prefs{jj});

                        shouldAdd = true;

                        for kk = 1:2:numel(varargin)    % Check that it satisfies the properties in varargin
                            name = varargin{kk};
                            value = varargin{kk+1};

                            shouldAdd = shouldAdd && isequal(pref.(name), value);
                        end

                        if shouldAdd
                            preffound = true;
                            localpreffound = true;
                            
                            prefclass = strsplit(class(pref), '.');
                            
                            readonly = '';
                            
                            if pref.readonly
                                readonly = ', <font face="Courier New" color="blue"><i>readonly</i></font>';
                            end
                            
                            label = ['<html>' pref.get_label() ' (<font face="Courier New" color="red">' pref.property_name '</font>, <font face="Courier New" color="blue">' prefclass{end} '</font>' readonly ')</html>'];

                            uimenu(folder, 'Text', label, 'UserData', pref, 'Callback', @(s,e)(callback(s, e, pref)));
                        end
                    end
                    
                    if ~localpreffound
                        delete(folder);
                    end
                end
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
                    
                uimenu(menu,'label', noprefmessage,'enable','off','tag','module');
            end
        end
    end
    
    methods
        function addPref(obj, parent, pref)
            mc = metaclass(parent);
            parent_name = strrep(mc.Name, '.', '_');
            
            if ~isfield(obj.register, parent_name)
                obj.register.(parent_name) = struct(obj.parent_storage, parent);
            end
            
            assert(~strcmp(obj.parent_storage, pref.property_name), ['Invalid Base.Pref property name ' obj.parent_storage]);
            
            obj.register.(parent_name).(pref.property_name) = pref;
        end
        function delete(obj)
            obj.register = [];    % Prevent objects from being deleted by getting rid of reference to the struct beforehand. Note that record of these objects will be erased.
        end
    end
end