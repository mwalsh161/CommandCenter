classdef SuperResTest < Modules.Experiment
    %Spectrum Experimental wrapper for Drivers.WinSpec
    
    properties(SetObservable,AbortSet)
        data
       number_scans = 1;
        prefs = {'number_scans'}; % Not including winspec stuff because it can take a long time!
        show_prefs = {'number_scans'};
    end
    properties(SetAccess=private,Hidden)
        listeners
    end
    methods(Access=private)
        function obj = SuperResTest()

            try
                obj.loadPrefs; % Load prefs should load WinSpec via set.ip
            catch err % Don't need to raise alert here
                if ~strcmp(err.message,'WinSpec not set')
                    rethrow(err)
                end
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.SuperResTest();
            end
            obj = Object;
        end
       
    end
    
    methods
        function run( obj,status,managers,ax )
             obj.data = [];
          imagingManager = managers.Imaging;
          
          numberPoints = 3;
          pointLocations(1,:) = [0.2,0.48];
          pointLocations(2,:) = [0.92,-0.1];
          pointLocations(3,:) = [0.97,-0.73];

          scanRange = 0.3;
          totalRunTime = 7200;
          fitFWHM = [];
          time = 0;
          n = 1;
          tic;
          figure;
          while time < totalRunTime
              for i = 1:numberPoints
                  ROImatrix = [pointLocations(i,1)-scanRange, pointLocations(i,1)+scanRange; pointLocations(i,2)-scanRange, pointLocations(i,2)+scanRange];
                  imagingManager.setROI(ROImatrix);
         
                  info = imagingManager.snap();
%                   obj.data.images(n,i,:,:) = info.image;
                  obj.data.ROI(n,i,:,:) = info.ROI;

                  obj.data.timestamp(n,i) = toc;
                  [center,width,outstruct] =gaussfit2D(ROImatrix(1,:),ROImatrix(2,:),info.image);
                  
                  obj.data.fittedPositions(n,i,:) = [center(1), center(2)];
                  obj.data.rsq(n,i) = outstruct.gof.rsquare;
                  obj.data.width(n,i) = width;
                  fitFWHM(i) = width;
                  pointLocations(i,:) = [center(1), center(2)];

                  
                  time = toc;
              end
             % managers.Experiment.forceSave;
              n = n+1;
          hold on
          errorbar(pointLocations(1,1),pointLocations(1,2),fitFWHM(1),'r*');
          errorbar(pointLocations(2,1),pointLocations(2,2),fitFWHM(1),'b*');
          errorbar(pointLocations(3,1),pointLocations(3,2),fitFWHM(1),'g*');
          hold off
          end
        end
        
     
        function delete(obj)
            delete(obj.listeners)
        end
        function abort(obj)
        end
        
        function dat = GetData(obj,~,~)
            dat = [];
            if ~isempty(obj.data)
                dat.diamondbase.data_name = 'SuperResTest';
                dat.diamondbase.data_type = 'local';
                dat.images = obj.data;
                dat.meta = 'test';
            end
        end
        
      
       
      
    end
    
end

