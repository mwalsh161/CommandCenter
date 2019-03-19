classdef ShotNoise  < Modules.Experiment 
    
    properties
        data;
        abort_request = false;  % Request flag for abort
        stage
        laser
        pulseblaster
        pixels_of_interest
        axImage
        camera
        prefs={'NumberOfImages','Exposure','Camera_PB_line','dummyPBLine'}
    end
    
    properties(SetObservable)
        NumberOfImages = 2000;
        Exposure = 20; %ms
        dummyPBLine = 14; %dummy pb line
        Camera_PB_line = 3; %indexed from 1
    end
    
    methods(Access=private)
        function obj = ShotNoise()
            
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.ShotNoise();
            end
            obj = Object;
        end
    end
    
    methods (Access=protected)
      
        function initialize_laser(obj,managers)
            modules = managers.Sources.modules;
            obj.laser = obj.find_active_module(modules,'Green_532Laser');
            obj.laser.off;
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.laser.ip);
        end
        
        function initializeCamera(obj,managers)
            obj.camera = managers.Imaging.active_module.instance;
            obj.camera.reset;
            obj.camera.startSequenceAcquisition(2*obj.NumberOfImages)
            
        end
        
        function s=setup_PB_sequence(obj)
            MeasTime =obj.Exposure*1000; % us (microseconds)
            ReadoutTime = obj.camera.getReadoutTime*1000; %us ; get the readoutime determined by the camera based on exposure, ROI and binning
            
            [laser_hw,camera_hw,dummy_pb_line] = obj.determine_PB_hardware_handles(); %get the pulsblaster hardware handles
            
            % Make some chanels
            claser = channel('laser','color','r','hardware',laser_hw);
            camera= channel('camera','color','g','hardware',camera_hw);
            cdummy = channel('xxx','color','y','hardware',dummy_pb_line);
            
            % Make sequence
            s = sequence('Shot Noise');
            s.channelOrder = [claser,camera,cdummy];
            
            % laser duration
            n_laser = node(s.StartNode,claser,'delta',0,'units','us');
            n_laser = node(n_laser,claser,'delta',MeasTime,'units','us');
            
            % camera exposure duration
            n_camera = node(s.StartNode,camera,'delta',0,'units','us');
            n_camera = node(n_camera,camera,'delta',MeasTime,'units','us');%expose
            
            %delay time for camera readout
            
            n_readoutTime = node(n_camera,cdummy,'delta',ReadoutTime,'units','us');%expose

        end
        
        function plot_data(obj,ax)
           timeVector = (1:obj.NumberOfImages/2)*obj.Exposure;
           plot(timeVector,obj.data.stdDeviationVector,'k*','parent',obj.ax);
           hold on
           plot(timeVector,obj.data.Ideal,'r--','parent',obj.ax);
           title('Shot Noise Analysis')
           xlabel('Integration Time (ms)')
           ylabel('Noise')
           
        end
        
        function [laser_hw,Camera_PB_line,dummyPBLine]=determine_PB_hardware_handles(obj)
            laser_hw = obj.laser.PBline-1;
            Camera_PB_line = obj.Camera_PB_line-1;
            dummyPBLine = obj.dummyPBLine - 1;
        end
    end
    
    methods

        function set.NumberOfImages(obj,val)
            assert(isnumeric(val),'NumberOfImages must be dataType numeric')
            assert(val>1,'NumberOfImages must be greater than 1')
            assert(mod(val,2) == 0,'NumberOfImages must be even')
            obj.NumberOfImages = val;
        end
        
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
        
         function run(obj,statusH,managers,ax)
             
             obj.abort_request=0;
             obj.data = [];
             obj.pixels_of_interest = [];
             obj.data.contrastMatrix = NaN(obj.NumberOfImages/2,obj.NumberOfImages/2);
             
             %%
             
             obj.initialize_experiment(managers)
             obj.laser.off;
             %%
             
             assert(~obj.abort_request,'User aborted');
             sequence = obj.setup_PB_sequence();
             [program,s] = sequence.compile;
             obj.pulseblaster.open;
             obj.pulseblaster.load(program);
             obj.pulseblaster.stop;
             pause_time = sequence.determine_length_of_sequence(program);
             
             %%
             
             for index = 1:obj.NumberOfImages
                 assert(~obj.abort_request,'User aborted');
                 %% data
                 
                 obj.pulseblaster.start;
                 pause(pause_time)
                 obj.pulseblaster.stop;
                 obj.data.dat_images(:,:,index) = obj.camera.snap;
                 %% norm
                 
                 obj.pulseblaster.start;
                 pause(pause_time)
                 obj.pulseblaster.stop;
                 obj.data.norm_images(:,:,index) = obj.camera.snap;
                 %% plot image
                 
                 imagesc(obj.data.norm_images(:,:,index),'parent',obj.axImage);
                 axis image
                 axis xy
                 colorbar(obj.axImage)
                 axis(obj.axImage,'image');
                 drawnow
             end
             obj.camera.stopSequenceAcquisition(0);
             obj.analyzeData;
             obj.plot_data(ax)
             obj.laser.off;
         end
         
        function get_image_axis_handle(obj)
            hObj = findall(0,'name','CommandCenter');
            handles = guidata(hObj);
            obj.axImage = handles.axImage;
        end
        
        function initialize_experiment(obj,managers)
            obj.initialize_laser(managers)
            obj.initializeCamera(managers);
            obj.get_image_axis_handle;
        end
        
        function abort(obj)
            obj.abort_request = true;
            obj.laser.off;
            obj.camera.reset
        end
        
        function analyzeData(obj)
            for binning = 1:obj.NumberOfImages/2
                %% reshape imagestacks so that you have a number of groups that equals binning
                imageStackData = []; imageStackNorm = [];
                imageStackData = obj.data.dat_images;
                imageStackNorm = obj.data.norm_images;
                
                numberImages = size(imageStackData,3);
                delImages = mod(numberImages,binning); %throw away these extra images so that you can reshape into the right number of groups
                imageStackData(:,:,end-delImages-delImages+1) = [];
                imageStackNorm(:,:,end-delImages-delImages+1) = [];
                
                imageStackData_groups = reshape(imageStackData,size(imageStack,1),size(imageStack,2),binning,[]);
                imageStackNorm_groups = reshape(imageStackData,size(imageStack,1),size(imageStack,2),binning,[]);
                imageStackData_groups = squeeze(imageStackData_groups,3);
                imageStackNorm_groups = squeeze(imageStackNorm_groups,3);
                for index = 1:size(imageStackData_groups,3)
                    [contrast,obj.pixels_of_interest] =...
                        QuickESRContrastInImage(imageStackData_groups(:,:,index),imageStackNorm_groups(:,:,index),obj.pixels_of_interest);
                    obj.data.contrastMatrix(binning,index) = contrast;
                end
                obj.data.stdDeviationVector = std(obj.data.contrastMatrix,0,2);
                obj.data.Ideal = obj.data.stdDeviationVector(1)*ones(1,obj.NumberOfImages/2)./(sqrt(1:binning));
            end  
        end
        
        function delete(obj)
            obj.abort;
        end
        
        function data = GetData(obj,~,~)
            data.data= obj.data;
            data.readOutTime = obj.camera.getReadoutTime;
            data.NumberOfImages  = obj.NumberOfImages;
            data.Exposure = obj.Exposure;
        end
        
        
    end
    
end