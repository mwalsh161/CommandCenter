classdef MAX373DK1 < Modules.Stage
    %MAX373DK1 Control the nanomax stage.
   
    properties
        calibration = [1 1 1];
        prefs = {'Channel','LoopMode'}
    end
    
    properties(SetObservable)
        Channel = 1
        LoopMode = 'Closed';
    end
    
    properties(SetAccess=private,SetObservable,AbortSet)
        Moving              % Track this to update position
    end
    
    properties(SetAccess=private)
        position 
        currPosition
    end
    
    properties(Access = private)
        listeners
        SG
    end
    properties(SetAccess=immutable)
        piezoDriver
    end
    
    properties(Constant)
        xRange = [0 20]; % um
        yRange = [0 20]; % um
        zRange = [0 20]; % um
        maxVoltage = 75;%V
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Stages.MAX373DK1();
            end
            obj = Object;
        end
    end
    methods(Access=private)
        function obj = MAX373DK1()
            obj.piezoDriver = Drivers.PiezoDrivers.BPC303.instance(class(obj));
            obj.listeners = addlistener(obj.piezoDriver,'Working','PostSet',@obj.movingCallback);
            obj.listeners(end + 1) = addlistener(obj,'Channel','PostSet',@obj.getLoopMode);
            obj.movingCallback;
            obj.loadPrefs;
            if isempty(obj.currPosition)
                obj.piezoDriver.setLoopMode(1,'Open')
                obj.piezoDriver.setLoopMode(2,'Open')
                obj.piezoDriver.setLoopMode(3,'Open')
                obj.move(0,0,0);
            end
        end
    end
    % Callback functions for PiezoControl
    methods(Access=?PiezoControl)
        function movingCallback(obj,varargin)
            obj.Moving = obj.piezoDriver.Working;
        end
        
        function getLoopMode(obj,~,~)
            mode = obj.LoopMode;
            obj.LoopMode = mode;
        end
    end
    
    methods
        function delete(obj)
            delete(obj.listeners)
            obj.piezoDriver.delete;
        end
        
        function pos = get.position(obj)
            cal = obj.calibration;
            if isempty(cal)
                warning('Not Calibrated! Using 1 um/V instead.')
                cal = [1 1 1];
            end
            %% X
            obj.Channel  = 1;
            
            if strcmp(obj.LoopMode,'Open') 
                pos(1) = obj.piezoDriver.getVX;
                pos(1) = pos(1)*cal(1)+min(obj.xRange);
            else
                if strcmp(obj.piezoDriver.PositionSet{1},'No')
                    %if we do not know the position of the piezo switch to
                    %just get current position
                    pos(1) = obj.currPosition(1);
                else
                    pos(1) = obj.piezoDriver.getPosX;
                end
            end
            
            %% Y
            obj.Channel  = 2;
            
            if strcmp(obj.LoopMode,'Open')
                pos(2) = obj.piezoDriver.getVY;
                pos(2) = pos(2)*cal(2)+min(obj.yRange);
            else
                if strcmp(obj.piezoDriver.PositionSet{2},'No')
                     %if we do not know the position of the piezo switch to
                    %just get current position
                     pos(2) = obj.currPosition(2);
                else
                     pos(2) = obj.piezoDriver.getPosY;
                end
            end
            
            %% Z
            obj.Channel  = 3;
           
            if strcmp(obj.LoopMode,'Open')
                pos(3) = obj.piezoDriver.getVZ;
                pos(3) = pos(3)*cal(3)+min(obj.zRange);
            else
                if strcmp(obj.piezoDriver.PositionSet{2},'No')
                    %if we do not know the position of the piezo switch to
                    %just get current position
                     pos(3) = obj.currPosition(3);
                else
                     pos(3) = obj.piezoDriver.getPosZ;
                end
            end
             obj.currPosition = pos;
        end
        
        function set.calibration(obj,val)
            switch numel(val)
                case 1
                    obj.calibration = [val val val];
                case 3
                    obj.calibration = val;
                otherwise
                    error('Calibration needs to be an array of 1 or 3 arguments.')
            end
        end
        
        function set.LoopMode(obj,val)
            assert(ischar(val),'Loop mode must be a character')
            if strcmpi(val,'closed')
                obj.SG = Sources.Signal_Generator.Hewlett_Packard.HP_PB_switch.instance;
                assert(~obj.SG.source_on,'SG is on cannot set to closed loop mode')
            end
            obj.piezoDriver.setLoopMode(obj.Channel,val) %debugging happens here
        end
        
        function mode = get.LoopMode(obj)
            mode = obj.piezoDriver.getLoopMode(obj.Channel);
        end
        
        function move(obj,x,y,z)
            obj.Channel = 1;
            obj.currPosition = [x,y,z];
            if strcmp(obj.LoopMode,'Open')
                cal = obj.calibration;
                x = (x - min(obj.xRange))/cal(1);
            end
            
            obj.Channel = 2;
            if strcmp(obj.LoopMode,'Open')
                cal = obj.calibration;
                y = (y - min(obj.yRange))/cal(2);
            end
            
            obj.Channel = 3;
            if strcmp(obj.LoopMode,'Open')
                cal = obj.calibration;
                z = (z - min(obj.zRange))/cal(3);
            end
            
            if x < 0
                x = 0;
            end
            
            if y < 0
                y = 0;
            end
            
            if z < 0
                z= 0;
            end
            
            obj.piezoDriver.move(x,y,z); % Sets in V or microns
        end
        
        function home(obj)
            if strcmp(obj.piezoDriver.getLoopMode(1),'Closed') && ...
                    strcmp(obj.piezoDriver.getLoopMode(2),'Closed')  && ...
                    strcmp(obj.piezoDriver.getLoopMode(3),'Closed')
                obj.piezoDriver.zero;
            else
                obj.move(0,0,0)
            end
        end
        
        function abort(varargin)
            % Nothing to be done!
        end
        
    end
    
end
