classdef ComObject < Base.pref
    %BUTTON for access to a "set" method that the user can activate on click.
    
    properties(Hidden)
        default = [];    % Value must be struct with field comType, comAddress, comProperties (see Connect_Device function)
        ui = Prefs.Inputs.ButtonField;
    end
    properties
        string = {'Set device connection', @(a)validateattributes(a,{'char'},{'vector'})};   % String to display on the button
        serial_object = { [], @(a)true}; % Object that will call the driver methods within class that has the ComObject pref
        driver_instantiation = { [], @(a)true}; % Method to call to instantiate driver when COM properties reset. Method should accept comObject, and comObjectInfo (struct with comType, comAddress, and comProperties) as output by Connect_Device
    end
    
    methods
        function obj = ComObject(varargin)
            obj = obj@Base.pref(varargin{:});
        end
        function val = clean(~, ~)
            val = false;
        end
        function val = set(obj,val,~)
            % Use Connect_Device interface to attempt to connect to
            [comObject,comType,comAddress,comProperties] = Connect_Device()
            % if ~isempty(obj.val)
            %     [comObject,comType,comAddress,comProperties] = Connect_Device(obj.value.comType, obj.value.comAddress, obj.value.comProperties)
            % else
            %     [comObject,comType,comAddress,comProperties] = Connect_Device()
            % end
            val = struct('comObject', comObject, 'comObjectInfo', struct('comType',comType,'comAddress',comAddress,'comProperties',comProperties))
            obj.driver_instantiation(val.comObject, val.comObjectInfo)
        end
    end
    
end