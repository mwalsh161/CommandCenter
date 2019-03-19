classdef TrackerPiezo  < Modules.Driver
 
    properties
        dwell = 5;           % ms
        object_size = 0.7;   % Size of object [um]
        thresh = 3;          % Peak must be taller than thresh*noise
        numberPoints = 10;
        counter
    end
    
    properties(SetAccess=private,SetObservable,AbortSet)
        tracking = false;    % Determines if tracking is active
    end
    
    properties(SetAccess=immutable)
        stage          % handle to Stages.* (simply to get correct calibration for object_size)
        stageDriver    % Drivers.NIDAQ.stage handle
    end
    
    methods(Access=protected)
        function obj = TrackerPiezo(stage,stageDriver)
            obj.stage = stage;
            obj.stageDriver = stageDriver;
            obj.counter = Drivers.Counter.instance('APD1','CounterSync');
        end
    end
    
    methods(Static)
        function obj = instance(stage,stageDriver)
            % INSTANCE initialize tracking module
            % INSTANCE(stage,stageDriver)
            mlock;
            id = {stage,stageDriver};
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Tracker.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(id,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.TrackerPiezo(stage,stageDriver);
            obj.singleton_id = id;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access = private)
        
    end
    
    
    methods
        
         function delete(~)
            f = findall(0,'name','Tracker');
            if ~isempty(f)
                delete(f)
            end
         end
        
        function Track(obj,verbose)
            % Because we are going to a driver-level for speedup, we need
            % to manually get the calibration.
            
            %Note: Initial conditions are that NV is centered on Gaussian
            %spot so that we can get some intial conditions
            
            if nargin < 2
                verbose = false;
            end
            obj.tracking = true;
            %% make position matrix
            pos = obj.stage.position; %current stage position assume you are near center of NV
            d = obj.object_size*3; %position limits +/- d will be the search range in all dimensions
            %% 
            try
                x = linspace(-d(1)/2,d(1)/2,obj.numberPoints)+pos(1);
                y = linspace(-d(1)/2,d(1)/2,obj.numberPoints)+pos(2);
                z = linspace(-d(1)/2,d(1)/2,obj.numberPoints)+pos(3);
                
                obj.counter.dwell =obj.dwell;
                DataMatrix = NaN(numel(x),numel(y),numel(z));
                for xpos = 1:numel(xpos)
                    for ypos = 1:numel(ypos)
                        for zpos = 1:numel(zpos)
                            obj.piezoStage.move(x(xpos),y(ypos),x(zpos))
                            DataMatrix(xpos,ypos,zpos) = obj.counter.singleShot(obj.dwell,1);
                        end
                    end
                end
                maxValPos = find(DataMatrix == max(DataMatrix(:)));
                [xpos,ypos,] = ind2sub(size(DataMatrix),maxValPos);
                obj.stage.move(xpos,ypos,zpos)
                   
            catch err
                obj.tracking = false;
                rethrow(err)
            end
        end
       
    end
end
