classdef TrackerRings < Modules.Driver
    %TRACKER Control Galvo position to maximize count rate of gaussian spot
    
    properties
        dwell = 15;           % ms
        object_size = 0.7;   % Size of object [um]
        thresh = 3;          % Peak must be taller than thresh*noise
    end
    properties(SetAccess=private,SetObservable,AbortSet)
        tracking = false;    % Determines if tracking is active
    end
    properties(SetAccess=immutable)
        stage          % handle to Stages.* (simply to get correct calibration for object_size)
        stageDriver    % Drivers.NIDAQ.stage handle
    end
    
    methods(Access=protected)
        function obj = TrackerRings(stage,stageDriver)
            obj.stage = stage;
            obj.stageDriver = stageDriver;
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
                Objects = Drivers.TrackerRings.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(id,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.TrackerRings(stage,stageDriver);
            obj.singleton_id = id;
            Objects(end+1) = obj;
        end
    end
    methods
        function Track(obj,verbose)
            % Because we are going to a driver-level for speedup, we need
            % to manually get the calibration.
            if nargin < 2
                verbose = false;
            end
            cal = obj.stage.calibration;  % um/V
            assert(isnumeric(cal),'Calibration not numeric!')
            assert(~sum(isnan(cal)),'Calibration is NaN!')
            assert(numel(cal)==3,'Calibration dimension is not 3!')
            obj.tracking = true;
            % Convert object_size to voltages
            pos = obj.stage.position;
            d = obj.object_size*3*[0.8 0.8 1]./cal;
            f = figure('name','TrackerData','Visible','off','HitTest','off');
            ax = axes('parent',f);
            if verbose
                fverbose = findall(0,'name','Tracker');
                if isempty(fverbose)
                    fverbose = figure('name','Tracker');
                else
                    clf(fverbose);
                end
                figure(fverbose);
                verbose = subplot(3,1,1);
                verbose(2) = subplot(3,1,2);
                verbose(3) = subplot(3,1,3);
                titles = 'xyz';
                for i = 1:3
                    title(verbose(i),sprintf('%s-axis',titles(i)));
                    ylabel(verbose(i),'Counts');
                end
                xlabel(verbose(i),'Position (um)');
            else
                verbose = [1 1 1]*verbose;
            end
            fit_type = gaussN(1);
            fit_options = fitoptions(fit_type);
            try
                % x-axis
                V = linspace(-d(1)/2,d(1)/2,60)+pos(1);
                data = imagesc(V,pos(2),NaN(numel(V),1));
                obj.stageDriver.SetupScan(V,pos(2),obj.dwell)
                obj.stageDriver.StartScan;
                obj.stageDriver.StreamToImage(data);
                data = data.CData'/(obj.dwell/1000);
                pos(1) = obj.findPeak(V*cal(1),data,fit_type,fit_options,'x',verbose(1))/cal(1);
                obj.stage.move(pos(1),pos(2),pos(3))
                drawnow;
                
                % y-axis
                V = linspace(-d(2)/2,d(2)/2,60)+pos(2);
                data = imagesc(pos(1),V,NaN(1,numel(V)));
                obj.stageDriver.SetupScan(pos(1),V,obj.dwell)
                obj.stageDriver.StartScan;
                obj.stageDriver.StreamToImage(data);
                data = data.CData/(obj.dwell/1000);
                pos(2) = obj.findPeak(V*cal(2),data,fit_type,fit_options,'y',verbose(2))/cal(2);
                obj.stage.move(pos(1),pos(2),pos(3))
                drawnow;
                
                % z-axis
%                 counter = Drivers.Counter.instance('APD1','CounterSync');
%                 
%                 V = linspace(-d(3)/2,d(3)/2,20)+pos(3);
%                 data = NaN(length(V),1);
%                 for i = 1:length(V)
%                     obj.stage.move(pos(1),pos(2),V(i));
%                     data(i) = counter.singleShot(obj.dwell,1);
%                 end
%                 pos(3) = obj.findPeak(V*cal(3),data,fit_type,fit_options,'z',verbose(3))/cal(3);
%                 obj.stage.move(pos(1),pos(2),pos(3))
            catch err
                obj.tracking = false;
                delete(f)
                rethrow(err)
            end
            delete(f)
        end
        function pos = findPeak(obj,V,data,fit_type,fit_options,axislabel,ax)
            fit_options.StartPoint = [max(data)-min(data),(V(end)-V(1))/2,obj.object_size,data(1)];
            sortedDat = sort(data);
            fit_options.Lower = [0 V(1) (V(end)-V(1))/length(V)*3 mean(sortedDat(1:round(end/3)))];
            fit_options.Upper = [Inf V(end) obj.object_size Inf];
            [myfit] = fit(V',data,fit_type,fit_options);
            ideal = myfit(V);
            noise = std(data-ideal);
            if isa(ax,'matlab.graphics.axis.Axes')
                hold(ax,'on')
                plot(ax,V,data);
                x = linspace(V(1),V(end),1000);
                plot(ax,x,myfit(x))
                plot(ax,[V(1) V(end)],noise*obj.thresh*[1 1]+myfit.d,'k')
                hold(ax,'off')
            end
            
%             assert(myfit.a1 > noise*obj.thresh,...
%                 sprintf('Could not find peak greater than %i*noise in %s-axis.',obj.thresh,axislabel));
            pos = myfit.b1;
        end
    end
end

