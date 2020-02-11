classdef FluorescenceTracking < Modules.Experiment
    
    properties(SetObservable)
        numImages = 1000;
        exposureTime = 10; %ms
        saveImageNum = 100;
        waitTime = 1; %s
    end
    
    properties
        laser
        firstRun
        abort_request
        camera
        data
        prefs = {'numImages','exposureTime','saveImageNum','waitTime'}
    end
    
    methods(Access=private)
        function obj = FluorescenceTracking()
            obj.loadPrefs;
            obj.data = [];
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.NeuroExp.FluorescenceTracking();
            end
            obj = Object;
        end
    end
    
    methods
        
         function module_handle = find_active_module(obj,modules,active_class_to_find)
            module_handle = [];
            for index=1:length(modules)
                class_name=class(modules{index});
                num_levels=strsplit(class_name,'.');
                truth_table=contains(num_levels,active_class_to_find);
                if sum(truth_table)>0
                    module_handle=modules{index};
                end
            end
            assert(~isempty(module_handle)&& isvalid(module_handle),['No actice class under ',active_class_to_find,' in CommandCenter as a source!'])
         end
         
        function set.numImages(obj,val)
            assert(isnumeric(val),'number_points must be a of type numeric.')
            assert(val>0,'number_points must be positive.')
            assert(~logical(mod(val,1)),'number_points must be an integer.')
            if ~isequal(val,obj.numImages)
                obj.numImages = val;
            end
        end
        
        function set.exposureTime(obj,val)
            assert(isnumeric(val),'number_points must be a of type numeric.')
            assert(val>0,'number_points must be positive.')
            assert(~logical(mod(val,1)),'number_points must be an integer.')
            if ~isequal(val,obj.exposureTime)
                obj.exposureTime = val;
            end
        end
        
        function set.saveImageNum(obj,val)
            assert(isnumeric(val),'number_points must be a of type numeric.')
            assert(val>0,'number_points must be positive.')
            assert(~logical(mod(val,1)),'number_points must be an integer.')
            assert(val <= obj.numImages,'saveImageNum must be less than numImages')
            if ~isequal(val,obj.saveImageNum)
                obj.saveImageNum = val;
            end
        end
        
        function delete(obj)
            obj.data = [];
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            %% get experimental data
            data.data = obj.data;
            
            %% metadata
            data.nAverages = 5;
            data.firstRun = obj.firstRun;
            data.numImages = obj.numImages;
            data.exposureTime = obj.exposureTime;
            data.saveImageNum = obj.saveImageNum;
            data.waitTime = obj.waitTime;
            %% camera
            data.camera_expTime = obj.camera.getExposure;
            data.camera_binning = obj.camera.getBinning;
            data.camera.ROI = obj.camera.ROI;
            
        end
        
        
    end
    
end