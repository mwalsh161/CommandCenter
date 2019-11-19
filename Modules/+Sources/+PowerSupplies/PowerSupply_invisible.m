classdef PowerSupply_invisible < Modules.Source
    %SuperClass for power supply sources
    % ***IMPORTANT NOTE***** Experiments should use getVal methods, not
    % corresponding Val property, to get true power supply setting, as
    % these can theoretically be different from the properties if the user 
    % manually sets them on the power supply.
    % 
    % Setting up the communication with the power supply (e.g. serial
    % connection) should be handled on a case by case basis by the
    % subclass.
    
    properties(SetObservable,GetObservable,AbortSet)
        prefs = {'Voltages','Currents','SourceModes'};
        show_prefs = {'Channel','Source_Mode','Voltage','Current'};
        Source_Mode = Prefs.MultipleChoice('Voltage','allow_empty',false,'choices',{'Voltage','Current'},'help_text','Whether current or voltage mode active for selected channel','set','changeSource_Mode');
        Current = 0.05; % Set current for selected channel (amps).
        Voltage = 1;  % Set voltage for selected channel (volts).
        Channel_Name = '1'; % User-defined name for selected channel
    end
    
    properties(SetAccess=private, SetObservable)
        source_on=false; % Boolean describing whether source is on
    end
    
    properties(SetAccess=private,Hidden)
        path_button
    end

    properties(SetAccess=protected)
        power_supply_connected=false; % Boolean describing whether there is a connected power supply object
    end

    properties(Abstract)
        power_supply % Handle to the power supply driver
    end
    
    properties(Abstract,SetObservable,AbortSet)
        Channel % Cell array denoting selected channels for the power supply
        Currents % Memory of what all the voltages are to be saved in prefs
        Voltages % Memory of what all the currents are to be saved in prefs
        SourceModes % Memory of what all the Source_Modes are to be saved in prefs
    end
    
    properties(Abstract,Constant)
        Power_Supply_Name % String containing ame of the power supply
        ChannelNames % Cell array denoting hardware channel names
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.PowerSupplies.PowerSupply_invisible();
            end
            obj = Object;
        end
        
    end

    methods(Access=protected)
        function varargout = queryPowerSupply(obj,command,varargin)
            % Only attempt to pass command to power_supply if device is connected
            if obj.power_supply_connected
                % Perform command specified by command (string), with varargin as arguments, return output if requested
                if nargout > 0
                    varargout{:} = obj.power_supply.(command)(varargin{:});
                else
                    obj.power_supply.(command)(varargin{:});
                end
            end
        end

        function obj = PowerSupply_invisible()
        end
    end
    
    methods
        %% set methods are wrappers for set (no dot) methods
        
        function val = changeSource_Mode(obj,val,pref)
            obj.setSource_Mode(val);
        end
        
        function set.Current(obj,val)
            obj.setCurrent(val);
            obj.Current = val;            
        end
        
        function set.Voltage(obj,val)
            obj.setVoltage(val);
            obj.Voltage = val;
        end

        %% set (no dot) methods that can be overloaded by subclasses. They set power supply value and populate appropriate array pref with new value.
                
        function setSource_Mode(obj,val)
            obj.queryPowerSupply('setSourceMode', obj.Channel ,val);
            obj.SourceModes{obj.getHWIndex(obj.Channel)} = val;
            obj.updateValues();
        end
        
        function setCurrent(obj,val)
            obj.queryPowerSupply('setCurrent',obj.Channel,val);
            obj.Currents(obj.getHWIndex(obj.Channel)) = val;
        end
        
        function setVoltage(obj,val)
            obj.queryPowerSupply('setVoltage',obj.Channel,val);
            obj.Voltages(obj.getHWIndex(obj.Channel)) = val;
        end

        %% get methods because these properties are interdependant.
        % each get method has an optional boolean argument whether to
        % measure true value (default) otherwise measure set value. If
        % source is off, set value will always be measured.
        
        function val = getCurrent(obj, measure)
            if nargin<2
                measure = true;
            end
            if measure && obj.source_on
                %if on return the actual current being output
                val = obj.queryPowerSupply('measureCurrent',obj.Channel);
            else
                val = obj.queryPowerSupply('getCurrent',obj.Channel);%if the source isn't on return the programmed values
                obj.Currents(obj.getHWIndex(obj.Channel)) = val;
            end
        end
        
        function val = getVoltage(obj, measure)
            if nargin<2
                measure = true;
            end
            if measure && obj.source_on
                %if on return the actual voltage being output
                val = obj.queryPowerSupply('measureVoltage',obj.Channel);
            else
                val = obj.queryPowerSupply('getVoltage',obj.Channel);%if the source isn't on return the programmed values
                obj.Voltages(obj.getHWIndex(obj.Channel)) = val;
            end
        end

        function val = getSource_Mode(obj)
           val = obj.queryPowerSupply('getSourceMode',obj.Channel);
           obj.SourceModes{obj.getHWIndex(obj.Channel)} = val;
        end
        
        function val = getHWIndex(obj,channel)
            % Given the a channel name, get the channel index in
            % ChannelNames
            val = contains(obj.ChannelNames,channel);
            assert(sum(val)~=0,'Channel not found')
            assert(sum(val)<2,'More than one channel match this name')
            val = find(val);
        end

        %% generic control functions
        function checkChannel(obj, channel)
            obj.queryPowerSupply('check_channel', channel)
        end

        function delete(obj)
            delete(obj.power_supply);
            obj.power_supply_connected=false;
        end
        
        function on(obj)
            obj.queryPowerSupply('on');
            obj.source_on=1;
        end
        
        function off(obj)
            obj.queryPowerSupply('off');
            obj.source_on=0;
        end
        
        function updateValues(obj,~,~)
            %Updates voltage, current and source mode that are diplayed by
            %getting them from the driver by calling get methods (only
            %updates current channel). If not connected, use save values
            %**note** this will be overriden when new power supply is connected!
            if obj.power_supply_connected
                sourceMode = obj.getSource_Mode;
                Current = obj.getCurrent(false);
                Voltage = obj.getVoltage(false);
            else
                sourceMode = obj.SourceModes{obj.getHWIndex(obj.Channel)};
                Current = obj.Currents(obj.getHWIndex(obj.Channel));
                Voltage = obj.Voltages(obj.getHWIndex(obj.Channel));
            end
            % reassign their values
            obj.Source_Mode = sourceMode;
            obj.Current = Current;
            obj.Voltage = Voltage;
        end
        
        function updatePrefs(obj)
            %Updates voltage, current and source mode prefs that are
            %diplayed are saved by using get methods (updates all channels)
            if obj.power_supply_connected
                % Go through updating values of each channel
                for i = numel(obj.ChannelNames):-1:1
                    obj.Channel = obj.ChannelNames{i};
                    obj.updateValues;
                end
            end
        end
        
    end
end

