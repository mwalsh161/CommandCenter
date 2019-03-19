classdef ODMR_camera < Experiments.ODMR.ODMR_invisible
    
    properties
        axImage
        pixels_of_interest
        camera
        prefs={'RF_power','nAverages','start_freq','stop_freq','number_points','freq_step_size',...
            'dummy_pb_line','Exposure','trig_type','Camera_PB_line','Norm_freq',...
            'Display_Data','waitTimeSGswitch_us','nOfPoints'}
    end
    
    properties(SetObservable)
        Exposure = 30;
        trig_type = {'Internal','DAQ','PulseBlaster'};
        Camera_PB_line = 3;
        Norm_freq = 2e9;
        Display_Data ={'Yes','No'};
        nOfPoints = 1000;
    end
    
    methods(Access=private)
        function obj = ODMR_camera()
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.ODMR.ODMR_camera();
            end
            obj = Object;
            obj.loadPrefs;
        end
    end
    
    methods(Access=protected)
        
        function [laser_hw,Camera_PB_line,MW_switch_hw,SG_trig_hw,dummy_pb_line]=determine_PB_hardware_handles(obj)
            laser_hw = obj.laser.PBline-1;
            
            Camera_PB_line = obj.Camera_PB_line-1;
            
            MW_switch_hw = obj.RF.MW_switch_PB_line-1;
            
            SG_trig_hw = obj.RF.SG_trig_PB_line-1;
            
            dummy_pb_line = obj.dummy_pb_line-1;
        end
        
        function freq_list=determine_freq_list(obj)
            freq_list = zeros(1,2*obj.number_points);
            freq_list_data = linspace(obj.start_freq,obj.stop_freq,obj.number_points);
            freq_list_norm = ones(1,obj.number_points).*obj.Norm_freq;
            freq_list(1:2:end) = freq_list_data;
            freq_list(2:2:end) = freq_list_norm;
        end
        
        function s=setup_PB_sequence(obj)
            
            MeasTime =obj.Exposure*1000; % us (microseconds)
            ReadoutTime = obj.camera.getReadoutTime*1000; %us ; get the readoutime determined by the camera based on exposure, ROI and binning
            if ReadoutTime<obj.waitTimeSGswitch_us
                ReadoutTime = obj.waitTimeSGswitch_us+1;
            end
            [laser_hw,camera_hw,MW_switch_hw,SG_trig_hw,dummy_pb_line]=obj.determine_PB_hardware_handles(); %get the pulsblaster hardware handles
            
            % Make some chanels
            claser = channel('laser','color','r','hardware',laser_hw);
            camera= channel('camera','color','g','hardware',camera_hw);
            cMWswitch = channel('MWswitch','color','b','hardware',MW_switch_hw,'offset',[0,0]);
            cSGtrig = channel('SGtrig','color','k','hardware',SG_trig_hw);
            cdummy = channel('xxx','color','y','hardware',dummy_pb_line);
            
            % Make sequence
            s = sequence('ODMR_sequence');
            s.channelOrder = [claser,camera,cMWswitch,cSGtrig,cdummy];
            
            % laser duration
            n_laser = node(s.StartNode,claser,'delta',0,'units','us');
            n_laser = node(n_laser,claser,'delta',MeasTime,'units','us');
            n_laser = node(n_laser,claser,'delta',ReadoutTime,'units','us');
            n_laser = node(n_laser,claser,'delta',MeasTime,'units','us');
            
            % camera exposure duration
            n_camera = node(s.StartNode,camera,'delta',0,'units','us');
            n_camera_first_begin = node(n_camera,camera,'delta',MeasTime,'units','us');%expose
            n_camera_first_read_out = node(n_camera_first_begin,camera,'delta',ReadoutTime,'units','us');%readout frame
            n_camera_second_begin = node(n_camera_first_read_out,camera,'delta',MeasTime,'units','us');
            
            % MW gate duration
            n_MW = node(s.StartNode,cMWswitch,'delta',0,'units','us');
            n_MW = node(n_MW,cMWswitch,'delta',MeasTime,'units','us');
            
            % % Signal Generator Trigger
            trigger_start=1;
            n_sigtrig = node(n_camera_first_begin,cSGtrig,'delta',trigger_start,'units','us'); % trigger the SG while reading out the camera
            n_sigtrig = node(n_sigtrig,cSGtrig,'delta',obj.waitTimeSGswitch_us,'units','us');
            n_sigtrig = node(n_camera_second_begin,cSGtrig,'delta',trigger_start,'units','us');
            n_sigtrig = node(n_sigtrig,cSGtrig,'delta',obj.waitTimeSGswitch_us,'units','us');
            
            % dummy channel
            dummy = node(s.StartNode,cdummy,'delta',0,'units','us');
            dummy = node(dummy,cdummy,'delta',2*(MeasTime+ReadoutTime),'units','us');
            
        end
        
        function initialize_data_acquisition_device(obj,managers)
            obj.camera = managers.Imaging.active_module.instance;
            obj.camera.reset;
            switch obj.trig_type
                case 'Internal'
                case 'DAQ'
                    error('DAQ triggering not implemented!')
                case {'PulseBlaster'}
                    obj.camera.startSequenceAcquisition(obj.nAverages*2*obj.number_points)
                    ip = obj.RF.ip;
                    obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(ip);
            end
            obj.data = [];
        end
        
        function plot_data(obj,index,cur_nAverage)
            freq_list = obj.determine_freq_list();
            freq_list(2:2:end) = [];
            if strcmp(cur_nAverage,'Final')
                errorbar(freq_list*10^-9,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax);
                title(obj.ax,['Final ODMR Spectrum'])
            elseif cur_nAverage>1
                plot(freq_list*10^-9,obj.data.contrast_vector,'parent',obj.ax);
                title(obj.ax,['Average ',num2str(cur_nAverage),' of ',num2str(obj.nAverages)])
            else
                plot(freq_list(1:index)*10^-9,obj.data.contrast_vector(1:index),'parent',obj.ax);
                title(obj.ax,['Average ',num2str(cur_nAverage),' of ',num2str(obj.nAverages)])
            end
            xlim(obj.ax,freq_list([1,end])*10^-9);
            xlabel(obj.ax,'Microwave Frequency (GHz)')
            ylabel(obj.ax,'Normalized Fluorescence')
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
        
        function plot_image(obj,im)
            imagesc(im,'parent',obj.axImage);
            axis image
            axis xy
            colorbar(obj.axImage)
            axis(obj.axImage,'image');
            drawnow
        end
        
        function [contrast]=determine_contrast(obj,index)
            datas_images = sum(obj.data.raw_data(:,:,index,:),4); %sum up all averages
            norm_images = sum(obj.data.norm_data(:,:,index,:),4);%sum up all averages
             if isempty(obj.pixels_of_interest)
                im = obj.data.raw_data(:,:,1,1);
                [~, Pixel_ind_descend] = sort(im(:), 'descend');
                obj.pixels_of_interest = Pixel_ind_descend(1:obj.nOfPoints);
            end
            [contrast,obj.pixels_of_interest] = QuickESRContrastInImage(datas_images,norm_images,obj.pixels_of_interest);
        end
        
        function analyze_data(obj)
            
            raw_data = double(obj.data.raw_data);
            norm_data = double(obj.data.norm_data);
            
            row = obj.data.pixels_of_interest_rows;
            col = obj.data.pixels_of_interest_col;
            
            for index = 1:length(row)
                raw_data_all(index,:,:) = raw_data(row(index),col(index),:,:);
                norm_data_all(index,:,:) = norm_data(row(index),col(index),:,:);
            end
           
            raw_data_sum = squeeze(sum(raw_data_all,3));
            norm_data_sum = squeeze(sum(norm_data_all,3));
            contrast_matrix = raw_data_sum./norm_data_sum;
            contrast_vector = sum(raw_data_sum,1)./sum(norm_data_sum,1);
            
            error_matrix = squeeze(std(raw_data_all./norm_data_all,0,3))./sqrt(obj.nAverages); %by normalizing by sqrt of averages this is the standard error
            error_vector = (std(sum(raw_data_all,1)./sum(norm_data_all,1),0,3))./sqrt(obj.nAverages); %sum all the data and take standard error across nAverages dimension
            
            obj.data.raw_data = raw_data;
            obj.data.norm_data = norm_data;
            obj.data.raw_data_sum = raw_data_sum;
            obj.data.norm_data_sum = norm_data_sum;
            obj.data.contrast_matrix = contrast_matrix;
            obj.data.contrast_vector = contrast_vector;
            obj.data.error_vector = error_vector;
            obj.data.error_matrix = error_matrix;
        end
    end
    
    methods
        
        function get_image_axis_handle(obj)
            hObj = findall(0,'name','CommandCenter');
            handles = guidata(hObj);
            obj.axImage = handles.axImage;
        end
             
        function abort(obj)
            %clean up camera
            obj.camera.reset;
            abort@Experiments.ODMR.ODMR_invisible(obj)
        end

        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data = GetData@Experiments.ODMR.ODMR_invisible(obj);
                data.im = obj.data;
                data.camera_expTime = obj.camera.getExposure;
                data.camera_readout_time = obj.camera.getReadoutTime;
                data.camera_binning = obj.camera.getBinning;
                data.camera.ROI = obj.camera.ROI;
            else
                data = [];
            end
        end
    end
end