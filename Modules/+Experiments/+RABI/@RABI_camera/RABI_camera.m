classdef RABI_camera < Experiments.RABI.RABI_invisible
    
    properties
        pause_time
        MW_on
        axImage
        camera
        pixels_of_interest
        prefs = {'CW_freq','RF_power','nAverages','Integration_time',...
            'laser_read_time','start_time','stop_time','number_points',...
            'time_step_size','Camera_PB_line','Display_Data','dummy_PB_line'}
    end
    
    properties (SetObservable)
        Camera_PB_line = 3; %indexed from 1
        dummy_PB_line = 14; %dummy pb line to set mw hw line to when you want no MW
        Display_Data = {'Yes','No'};
    end
    
    methods(Access=private)
        function obj = RABI_camera()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.RABI.RABI_camera();
            end
            obj = Object;
        end
    end
    
    methods (Access=protected)
        
        function [laser_hw,Camera_PB_line,MW_switch_hw]=determine_PB_hardware_handles(obj)
            laser_hw = obj.Laser.PBline-1;
            
            Camera_PB_line = obj.Camera_PB_line-1;
            
            try
                MW_switch_hw = obj.RF.MW_switch_PB_line -1;
            catch
                error('SG has no MW switch enabled.')
            end
        end
        
        function plot_image(obj,im)
            imagesc(im,'parent',obj.axImage);
            axis image
            axis xy
            colorbar(obj.axImage)
            axis(obj.axImage,'image');
            drawnow
        end
        
        function collect_data_and_plot(obj,index,cur_nAverage,image)
            [obj.data.contrast_vector(index)]=obj.determine_contrast(index);
            obj.plot_data(index,cur_nAverage)
            obj.plot_image(image)
            if index==1 && cur_nAverage == 1
                [row,col] = ind2sub(size(image),obj.pixels_of_interest);
                obj.data.pixels_of_interest_rows = row;
                obj.data.pixels_of_interest_col = col;
            end
            hold(obj.axImage,'on')
            plot(obj.data.pixels_of_interest_col,obj.data.pixels_of_interest_rows,'g*','parent',obj.axImage)
            hold(obj.axImage,'off')
        end
        
        function step_sequence(obj)
            [obj.sequence,camera_hw] = obj.setup_PB_sequence();
            [program,s] = obj.sequence.compile;
            program = obj.sequence.add_fixed_line(program,camera_hw); %set the camera line to be high throughout the sequence
            obj.pulseblaster.stop;
            obj.pulseblaster.open;
            obj.pulseblaster.load(program);
            obj.pause_time = obj.sequence.determine_length_of_sequence(program)+0.001;%determine the length of the sequence
            
            f = figure('visible','on','name','100');
            a = axes('Parent',f);
            obj.sequence.draw(a)
            pause(1)
            delete(f)
        end
        
        function [s,camera_hw] = setup_PB_sequence(obj)
            
            Integration_time = obj.Integration_time*1e3;% in us
            
            laser_read_time = obj.laser_read_time/1000; %in us
            
            %solve for how many samples you need to get desired integration
            %time.
            nSamples = round(Integration_time/laser_read_time);
            
            wait_time_between_laserandtrigger=0;
            NV_shelving_time=0.5;
            dead_time_camera=0.2;% in microseconds;
            padding=0.1;
            
            %% get hw lines for different pieces of equipment
            
            [laser_hw,camera_hw,MW_switch_hw]=obj.determine_PB_hardware_handles(); %get the pulsblaster hardware handles
            
            if ~obj.MW_on
                MW_switch_hw = obj.dummy_PB_line;%change mw hw handle to something random for normalization
            end
            %%
            
            % Make some chanels
            cLaser = channel('laser','color','r','hardware',laser_hw);
            camera= channel('camera','color','g','hardware',camera_hw);
            cMWswitch = channel('MWswitch','color','b','hardware',MW_switch_hw);
            
            % Make sequence
            s = sequence('RABI_sequence');
            s.channelOrder = [cLaser,camera,cMWswitch];
            
            % start looping over samples for data
            nloop = node(s.StartNode,'Loop the number of samples for averaging','type','start','delta',dead_time_camera,'units','us');
            
            % Laser duration for data
            n_Laser = node(nloop,cLaser,'delta',0,'units','us');
            n_Laser = node(n_Laser,cLaser,'delta',laser_read_time,'units','us');
            
            % MW gate duration for data
            n_MW = node(nloop,cMWswitch,'delta',wait_time_between_laserandtrigger+laser_read_time+NV_shelving_time,'units','us');
            n_MW = node(n_MW,cMWswitch,'delta',obj.MW_on_time,'units','us');
            
            % end loop for data
            nloop = node(n_MW,nSamples,'type','end','delta',padding,'units','us');
        end
        
        function initialize_data_acquisition_device(obj,managers)
            obj.camera = managers.Imaging.active_module.instance;
            obj.camera.reset;
            obj.camera.startSequenceAcquisition(obj.nAverages*2*obj.number_points)
        end
        
    end
    
    methods
        
        function [contrast]=determine_contrast(obj,index)
            datas_images = sum(obj.data.raw_data(:,:,index,:),4); %sum up all averages
            norm_images = sum(obj.data.norm_data(:,:,index,:),4);%sum up all averages
            [contrast,obj.pixels_of_interest] = QuickESRContrastInImage(datas_images,norm_images,obj.pixels_of_interest);
        end
        
        function plot_data(obj,index,cur_nAverage)
            time_list = obj.determine_time_list();
            if strcmp(cur_nAverage,'Final')
                errorbar(time_list,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax);
            elseif cur_nAverage>1
                plot(time_list,obj.data.contrast_vector,'parent',obj.ax);
            else
                plot(time_list(1:index),obj.data.contrast_vector(1:index),'parent',obj.ax);
            end
            xlim(obj.ax,time_list([1,end]));
            xlabel(obj.ax,'Microwave on Time (us)')
            ylabel(obj.ax,'Normalized Fluorescence')
        end
        
        function get_image_axis_handle(obj)
            hObj = findall(0,'name','CommandCenter');
            handles = guidata(hObj);
            obj.axImage = handles.axImage;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.im = obj.data;
                data.camera_binning = obj.camera.getBinning;
                data.camera.ROI = obj.camera.ROI;
                data.camera_readout_time = obj.camera.getReadoutTime;
                
                GetData@Experiments.RABI.RABI_invisible(obj);
            else
                data = [];
            end
        end
        
        function abort(obj)
            obj.camera.reset;
            abort@Experiments.RABI.RABI_invisible(obj)%handles everything else
        end
        
    end
end