classdef BPC303 < Drivers.PiezoDrivers.ClosedLoopPiezoDriversSuper
    %3 channel open and closed loop piezoDriver. Thorlabs BPC303 piezo
    %driver.
    properties 
       Position   
       PositionSet = {'No','No','No'}
    end
    
    properties (SetAccess=private,SetObservable,AbortSet)
        Working = false     % In the middle of changing voltage (closely related to VoltageChange event)
    end
    
    properties
        waitTime = 0.005; %seconds
        visible = 'Off'; %fig visibility status. Supports off or on. Setting status to
        %on shows figure window that contains symbolic representation of
        %piezo control GUI.
        timeout = 10;  %property that determine how long you want to wait (seconds) for piezo to complete operations.
        prefs = {'Position','PositionSet'}
    end
    
    properties(Hidden,SetAccess=private)
        Voltage   % Voltage in um centered at the mean of voltLim/calibration
    end
    
    properties(SetAccess=immutable)
        voltLim
        positionLimit
        hwhandle
        x %channel 1
        y %channel 2
        z %channel 3
        fig %figure handle to figure window that hold symbolic representation of
        %front side of piezo controller. Figure is a GIU to control piezo.
        %Normally is hidden.
    end
    
    properties(Constant,Hidden)
        FriendlyName = 'MG17SYSTEM.MG17SystemCtrl.1'
        piezoChannelID = 'MGPIEZO.MGPiezoCtrl.1';
        HW_Type = 7; %HW type for USB piezo controller specified by thorlabs
    end
    
    properties(Constant)
        dev_id = 'BPC303'
    end
    
    methods(Static)
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PiezoDrivers.BPC303.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PiezoDrivers.BPC303();
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function [obj] = BPC303()
            display(['Connecting to ',obj.dev_id])
            
            obj.fig = figure('Units','normalized','Position', [0.3 0.45 0.47 0.184], 'HandleVisibility', 'off', 'IntegerHandle', 'off', ...
                'Name', 'APT Interface', 'NumberTitle', 'off');
            obj.fig.MenuBar ='none';
            obj.fig.ToolBar ='none';
            obj.fig.Resize = 'off';
            obj.fig.CloseRequestFcn =  @obj.hideFigure;
            set(obj.fig, 'Visible', 'off');
            
            obj.hwhandle = actxcontrol(obj.FriendlyName, [0 0 100 100], obj.fig);
            % Start the control
            obj.hwhandle.StartCtrl;
            
            %% Start the piezo ActiveX controls
            % Verify the number of piezo controls
            [temp, num_piezo] = obj.hwhandle.GetNumHWUnits(obj.HW_Type, 0);
            
            % Get the serial numbers
            for count = 0 : num_piezo-1
                [temp, SN_piezo{count+1}] = obj.hwhandle.GetHWSerialNum(obj.HW_Type, count, 0); % Get the serial number of the devices
            end
            % initialize your hardware channel
            % Piezo 1: x
            obj.x = actxcontrol(obj.piezoChannelID, [0 00 300 200], obj.fig);
            obj.SetPiezo(obj.x, SN_piezo{1});
            
            % Piezo 2: y
            obj.y = actxcontrol(obj.piezoChannelID, [300 0 300 200], obj.fig);
            obj.SetPiezo(obj.y, SN_piezo{2});
            
            % Piezo 3: z
            obj.z = actxcontrol(obj.piezoChannelID, [600 0 300 200], obj.fig);
            obj.SetPiezo(obj.z, SN_piezo{3});
            
            %% set hw limits
            
             obj.voltLim = 75;

             obj.positionLimit = 20;
            %% load prefs
            
            obj.loadPrefs;
        end
        
        function SetPiezo(obj,h, SN)
            
            % Start the control
            h.StartCtrl;
            
            % Set the serial number
            set(h, 'HWSerialNum', SN); pause(0.1);
            
            % Identify the device
            h.Identify;
        end
        
        function channelHandle = getChannelHandle(obj,channelNum)
            switch channelNum
                case  {1,'1','x','X'}
                    channelHandle = obj.x;
                case  {2,'2','y','Y'}
                    channelHandle = obj.y;
                case  {3,'3','z','Z'}
                    channelHandle = obj.z;
                otherwise
                    error('Unsupported channelNum should be channels: 1,2 or 3.')
            end
        end
        
        function moveClosed(obj,channelNum,position)
            switch channelNum
                case 1
                    obj.setPosX(position);
                case 2
                    obj.setPosY(position);
                case 3
                    obj.setPosZ(position);
                otherwise
                    error('Unknown channelNum')
            end
        end
        
        function moveClosedDiff(obj,channelNum,delta)
            switch channelNum
                case 1
                    pos = obj.getPosX;
                    obj.setPosX(pos+delta);
                case 2
                    pos = obj.getPosY;
                    obj.setPosY(pos+delta);
                case 3
                    pos = obj.getPosZ;
                    obj.setPosZ(pos+delta);
                otherwise
                    error('Unknown channelNum')
            end
        end
        
        function moveOpen(obj,channelNum,voltage)
            switch channelNum
                case 1
                    obj.setVX(voltage);
                case 2
                    obj.setVY(voltage);
                case 3
                    obj.setVZ(voltage);
                otherwise
                    error('Unknown channelNum')
            end
        end
        
        function moveOpenDiff(obj,channelNum,delta)
            switch channelNum
                case 1
                    voltage = obj.getVX;
                    obj.setVX(voltage+delta);
                case 2
                    voltage = obj.getVY;
                    obj.setVY(voltage+delta);
                case 3
                    voltage = obj.getVZ;
                    obj.setVZ(voltage+delta);
                otherwise
                    error('Unknown channelNum')
            end
        end
        
        function block(obj,val,method_handle)
            % method that ensure blocking operation until successful or
            % timeout reached.
            
            %success is determined by checking val (desired setting) vs
            %method handle
            
            assert(isnumeric(val),'block only works for numeric dataTypes.')
            obj.Working = true; %device is doing something (ex: moving) so set status of Working to be true
            currValue = method_handle();
            delta = 0.05; %tolerance deviation from val allowed
            lowerBound = val-delta;
            upperBound = val+delta;
            tic
            while ~(currValue <= upperBound && currValue >= lowerBound)
                currValue = method_handle();
                pause(0.1);
                
                if toc > obj.timeout
                    obj.Working = false; %set to false because device did not perform within timeout
                    error([obj.dev_id, ' did not set '...
                        ,num2str(val), ' within ', num2str(obj.timeout), ' seconds'])
                end
            end
            obj.Working = false;
            time = toc;%refresh timer
            
        end
    end
    %% class methods
    
    methods
        function set.visible(obj,val)
            assert(ischar(val),'visible status is either Off or ON')
            if strcmp(val,obj.visible)
                return
            end
            switch val
                case {'Off','OFF','off'}
                    set(obj.fig, 'Visible', 'off');
                case {'On','ON','on'}
                    set(obj.fig, 'Visible', 'on');
                otherwise
                    error('Unrecognized value. Acceptable values are Off or On.')
            end
        end
        
        function set.Voltage(obj,val)
            assert(isnumeric(val),'Voltage must be numeric')
            assert(numel(val) == 3,['Voltage be a vector where each element'...
                'corresponds to a channel. Ex: Voltage(1) set channel 1.'])
            obj.setVX(val(1));
            obj.setVY(val(2));
            obj.setVZ(val(3));
        end
        
        function val = get.Voltage(obj)
            val(1) = obj.getVX;
            val(2) = obj.getVY;
            val(3) = obj.getVZ;
        end
        
        function visibilityStatus = get.visible(obj)
            visibilityStatus = get(obj.fig, 'Visible');
            if strcmp(visibilityStatus,'on')
                visibilityStatus = 'On';
            elseif strcmp(visibilityStatus,'off')
                visibilityStatus = 'Off';
            else
                error('Unrecognized visibility status')
            end
        end
        
        function  hideFigure(obj,~,~)
            obj.visible = 'off';
        end
        
        function delete(obj)
            obj.x.StopCtrl;
            obj.x.delete;
            obj.y.StopCtrl;
            obj.y.delete;
            obj.z.StopCtrl;
            obj.z.delete;
            obj.hwhandle.StopCtrl;
            obj.hwhandle.delete;
            obj.visible = 'Off';
            delete(obj.fig)
        end
    end
    %% closed loop methods
    
    methods
        %% get methods
        function LoopMode = getLoopMode(obj,channelNum)
            channelHandle = obj.getChannelHandle(channelNum);
            [~,val]= channelHandle.GetControlMode(0,0);
            if val == 1
                LoopMode = 'Open';
            else
                LoopMode = 'Closed';
            end
        end
        
        function posX = getPosX(obj)
            assert(strcmp(obj.getLoopMode(1),'Closed'),['X must be set'...
                ' to Closed Loop Mode in order to use getPosX.'])
            %             posX = obj.x.GetPosOutput(0,0);  %not sure why
            %             this doesn't  work
            
            assert(strcmp(obj.PositionSet{1},'Yes'),['Cannot return position '...
                'until a position has been set for channel 1'])
            posX = obj.Position{1};
        end
        
        function posY = getPosY(obj)
            assert(strcmp(obj.getLoopMode(2),'Closed'),['Y must be set'...
                ' to Closed Loop Mode in order to use getPosY.'])
            %             posY = obj.y.GetPosOutput(0,0);%not sure why
            %             this doesn't  work
            
            assert(strcmp(obj.PositionSet{2},'Yes'),['Cannot return position '...
                'until a position has been set for channel 2'])
            posY = obj.Position{2};
        end
        
        function posZ = getPosZ(obj)
            assert(strcmp(obj.getLoopMode(3),'Closed'),['Z must be set'...
                ' to Closed Loop Mode in order to use getPosZ.'])
            %             posZ = obj.z.GetPosOutput(0,0);%not sure why
            %             this doesn't  work
            
            assert(strcmp(obj.PositionSet{3},'Yes'),['Cannot return position '...
                'until a position has been set for channel 2'])
            posZ = obj.Position{3};
        end
        
        %% set methods
        function setLoopMode(obj,channelNum,loopMode)
            channelHandle = obj.getChannelHandle(channelNum);
            switch loopMode
                case {'Open','OPEN','open'}
                    channelHandle.SetControlMode(0,1);
                case {'Closed','CLOSED','closed'}
                    channelHandle.SetControlMode(0,2);
                otherwise
                    error('Unknown loopMode, valid inputs are Open or Closed.')
            end
        end
        
        function setPosX(obj,val)
            assert(isnumeric(val),'input for setPosX should be dataType numeric')
            assert(val >= 0,'input must be positive')
            assert(val <= obj.positionLimit,sprintf('Input must be less than %d',obj.positionLimit))
            assert(strcmp(obj.getLoopMode(1),'Closed'),['X must be set'...
                ' to Closed Loop Mode in order to use setPosX.'])
            try
                if obj.getPosX == val
                    return
                end
            end
            obj.x.SetPosOutput(0,val);

            obj.PositionSet{1} = 'Yes';
            obj.Position{1} = val;
            %piezo has no blocking operation so implement your own
            %do not let matlab escape until successful or timeout
            %            obj.block(val,@obj.getPosX);
            pause(obj.waitTime)
        end
        
        function setPosY(obj,val)
            assert(isnumeric(val),'input for setPosY should be dataType numeric')
            assert(val >= 0,'input must be positive')
            assert(val <= obj.positionLimit,sprintf('Input must be less than %d',obj.positionLimit))
            assert(strcmp(obj.getLoopMode(2),'Closed'),['Y must be set'...
                ' to Closed Loop Mode in order to use setPosY.'])
            try
                if obj.getPosY == val
                    return
                end
            end
            obj.y.SetPosOutput(0,val);

            obj.PositionSet{2} = 'Yes';
            obj.Position{2} = val;
            %piezo has no blocking operation so implement your own
            %do not let matlab escape until successful or timeout
            %            obj.block(val,@obj.getPosY);
            pause(obj.waitTime)
        end
        
        function setPosZ(obj,val)
            assert(isnumeric(val),'input for setPosZ should be dataType numeric')
            assert(val >= 0,'input must be positive')
            assert(val <= obj.positionLimit,sprintf('Input must be less than %d',obj.positionLimit))
            assert(strcmp(obj.getLoopMode(3),'Closed'),['Z must be set'...
                ' to Closed Loop Mode in order to use setPosZ.'])
            try
                if obj.getPosZ == val
                    return
                end
            end
            obj.z.SetPosOutput(0,val);
            obj.PositionSet{3} = 'Yes';
            obj.Position{3} = val;
            %piezo has no blocking operation so implement your own
            %do not let matlab escape until successful or timeout
            %            obj.block(val,@obj.getPosZ);
            pause(obj.waitTime)
        end
        
        %% general methods
        function zero(obj)
            assert(strcmp(obj.getLoopMode(1),'Closed'),['Channel 1 must be in' ...
                ' closed loop mode to zero'])
            assert(strcmp(obj.getLoopMode(2),'Closed'),['Channel 2 must be in' ...
                ' closed loop mode to zero'])
            assert(strcmp(obj.getLoopMode(3),'Closed'),['Channel 3 must be in' ...
                ' closed loop mode to zero'])
            obj.x.ZeroPosition(0);
            obj.y.ZeroPosition(0);
            obj.z.ZeroPosition(0);
            obj.Position = {0,0,0};
            obj.PositionSet = {'Yes','Yes','Yes'};
            pause(30)  %time to allow the piezo to be zeroed
        end
        
        function move(obj,x,y,z)
            assert(isnumeric(x) || isempty(x),['Invalid input for input arg 1.'...
                ' x position needs to be empty or dataType numeric'])
            assert(isnumeric(y) || isempty(y),['Invalid input for input arg 2.'...
                ' y position needs to be empty or dataType numeric'])
            assert(isnumeric(z) || isempty(z),['Invalid input for input arg 3.'...
                ' z position needs to be empty or dataType numeric'])
            argIn = [{x},{y},{z}];
            for channel = 1 : 3
                if isempty(argIn{channel})
                    continue
                end
                switch obj.getLoopMode(channel)
                    case 'Closed'
                        obj.moveClosed(channel,argIn{channel})
                    case 'Open'
                        obj.moveOpen(channel,argIn{channel})
                    otherwise
                        error('Unknown LoopMode.')
                end
            end
        end
        
        function step(obj,dx,dy,dz)
            assert(isnumeric(dx) || isempty(dx),['Invalid input for input arg 1.'...
                ' dx position needs to be empty or dataType numeric'])
            assert(isnumeric(dy) || isempty(dy),['Invalid input for input arg 2.'...
                ' dy position needs to be empty or dataType numeric'])
            assert(isnumeric(dz) || isempty(dz),['Invalid input for input arg 3.'...
                ' dz position needs to be empty or dataType numeric'])
            argIn = [{dx},{dy},{dz}];
            for channel = 1 : 3
                if isempty(argIn{channel})
                    continue
                end
                switch obj.getLoopMode(channel)
                    case 'Closed'
                        obj.moveClosedDiff(channel,argIn{channel})
                    case 'Open'
                        obj.moveOpenDiff(channel,argIn{channel})
                    otherwise
                        error('Unknown LoopMode.')
                end
            end
        end
        
    end
    
    %% open loop Methods
    methods
        %% Get methods
        function val = getVX(obj)
            assert(strcmp(obj.getLoopMode(1),'Open'),['VX must be set'...
                ' to Open Loop Mode in order to use getVX.'])
            [~,val] = obj.x.GetVoltOutput(0,0);
        end
        
        function val = getVY(obj)
            assert(strcmp(obj.getLoopMode(2),'Open'),['VY must be set'...
                ' to Open Loop Mode in order to use getVY.'])
            [~,val] = obj.y.GetVoltOutput(0,0);
        end
        
        function val = getVZ(obj)
            assert(strcmp(obj.getLoopMode(3),'Open'),['VZ must be set'...
                ' to Open Loop Mode in order to use getVZ.'])
            [~,val] = obj.z.GetVoltOutput(0,0);
        end
        
        %% Set methods
        
        function setVX(obj,val)
            assert(isnumeric(val),'input for setVX should be dataType numeric')
            assert(val >= 0,'input must be positive')
            assert(val <= obj.voltLim,sprintf('Input must be less than %d',obj.voltLim))
            assert(strcmp(obj.getLoopMode(1),'Open'),['VX must be set'...
                ' to Open Loop Mode in order to use setVX.'])
            obj.x.SetVoltOutput(0,val);
            obj.PositionSet{1} = 'No';
            %piezo has no blocking operation so implement your own
            %do not let matlab escape until successful or timeout
            obj.block(val,@obj.getVX);
        end
        
        function setVY(obj,val)
            assert(isnumeric(val),'input for setVY should be dataType numeric')
            assert(val >= 0,'input must be positive')
            assert(val <= obj.voltLim,sprintf('Input must be less than %d',obj.voltLim))
            assert(strcmp(obj.getLoopMode(2),'Open'),['VY must be set'...
                ' to Open Loop Mode in order to use setVY.'])
            obj.y.SetVoltOutput(0,val);
            obj.PositionSet{2} = 'No';
            %piezo has no blocking operation so implement your own
            %do not let matlab escape until successful or timeout
            obj.block(val,@obj.getVY);
        end
        
        function setVZ(obj,val)
            assert(isnumeric(val),'input for setVZ should be dataType numeric')
            assert(val >= 0,'input must be positive')
            assert(val <= obj.voltLim,sprintf('Input must be less than %d',obj.voltLim))
            assert(strcmp(obj.getLoopMode(3),'Open'),['VZ must be set'...
                ' to Open Loop Mode in order to use setVZ.'])
            obj.z.SetVoltOutput(0,val);
            obj.PositionSet{3} = 'No';
            %piezo has no blocking operation so implement your own
            %do not let matlab escape until successful or timeout
            obj.block(val,@obj.getVZ);
        end
        
        function setVAll(obj,val)
            assert(isnumeric(val),'input to VALL must be numeric')
            obj.setVX(val);
            obj.setVY(val);
            obj.setVZ(val);
        end
        
    end
end