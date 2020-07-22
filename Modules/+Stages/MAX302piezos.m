classdef MAX302piezos < Modules.Stage
    %MAX302piezos Control the piezos of this stage.
    
    properties(SetAccess=private,SetObservable,AbortSet)
        Moving              % Track this to update position
    end
    properties(SetAccess=private)
        position
    end
    properties(Access = private)
        listeners
    end
    properties(SetAccess=immutable)
        piezoDriver
    end
    properties(Constant)
        xRange = [-10 10]; % um
        yRange = [-10 10]; % um
        zRange = [-10 10]; % um
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Stages.MAX302piezos();
            end
            obj = Object;
        end
    end
    methods(Access=private)
        function obj = MAX302piezos()
            obj.piezoDriver = Drivers.PiezoControl.instance;
            if max(obj.piezoDriver.voltLim) > 75*1.05
                error('Voltage limit on piezo controller is too high.  Power down and change to 75V before restarting.')
            end
            obj.listeners=addlistener(obj.piezoDriver,'Working','PostSet',@obj.movingCallback);
            obj.movingCallback;
            obj.loadPrefs;
        end
    end
    % Callback functions for PiezoControl
    methods(Access=?PiezoControl)
        function movingCallback(obj,varargin)
            obj.Moving = obj.piezoDriver.Working;
        end
    end
    methods
        function delete(obj)
            object = {obj.listeners,obj.piezoDriver};
            for i = 1:length(object)
                if ~isempty(object{i})
                    for j = 1:length(object{i})
                        if isvalid(object{i}(j))
                            delete(object{i}(j))
                        end
                    end
                end
            end
        end
        function pos = get.position(obj)
            pos = obj.piezoDriver.Voltage;
            cal = obj.calibration;
            if isempty(cal)
                warning('Not Calibrated! Using 1 um/V instead.')
                cal = [1 1 1];
            end
            pos(1) = pos(1)*cal(1)+min(obj.xRange);
            pos(2) = pos(2)*cal(2)+min(obj.yRange);
            pos(3) = pos(3)*cal(3)+min(obj.zRange);
        end
%         function set.calibration(obj,val)
%             switch numel(val)
%                 case 1
%                     obj.calibration = [val val val];
%                 case 3
%                     obj.calibration = val;
%                 otherwise
%                     error('Calibration needs to be an array of 1 or 3 arguments.')
%             end
%         end

        function move(obj,x,y,z)
            cal = obj.calibration;
            x = (x - min(obj.xRange))/cal(1);
            y = (y - min(obj.yRange))/cal(2);
            z = (z - min(obj.zRange))/cal(3);
            obj.piezoDriver.move(x,y,z); % Sets in V
        end
        function home(obj)
            obj.piezoDriver.setVAll(0)
        end
        function abort(varargin)
            % Nothing to be done!
        end
        
        % Settings and Callback
        function  settings(obj,panel,~,~)
        end
    end
    
end

