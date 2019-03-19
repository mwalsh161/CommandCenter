classdef ODMR_PLL < Experiments.CMOS.CMOS_invisible & Experiments.ODMR.ODMR_invisible
    
    properties
        ni
        trig_type = 'Internal';
        Display_Data = 'Yes'
        axImage
        pixels_of_interest
        camera
        ChipControl
        prefs = {'DriverBias','nAverages','RF_power','start_freq','stop_freq','number_points','freq_step_size',...
            'Exposure','waitTimeSGswitch_us','nOfPoints','switchVoltage','VCO_CTRL_Line','pauseTime','switchOffVoltage'...
            'displayNorm','NormFreq'}
    end
    
    
    properties(SetObservable)
        Exposure = 30;
        nOfPoints = 1000;
        switchVoltage = 1;
        switchOffVoltage = 0;
        VCO_CTRL_Line = 'VCO_CTRL';
        pauseTime = 1;
        displayNorm = {'Yes','No'};
        NormFreq = 2.82e9;
    end
    
    
    methods(Access=private)
        function obj = ODMR_PLL()
            obj.listeners = addlistener(obj,'start_freq','PostSet',@obj.update_freq_step);
            obj.listeners(end+1) = addlistener(obj,'stop_freq','PostSet',@obj.update_freq_step);
            obj.listeners(end+1) = addlistener(obj,'number_points','PostSet',@obj.update_freq_step);
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.Off_Chip.ODMR.ODMR_PLL();
            end
            obj = Object;
        end
    end
    
    methods(Access = protected)
        
        function freq_list = determine_freq_list(obj)
            freq_list = nan(1,2*obj.number_points);
            freq_list1 = linspace(obj.start_freq,obj.stop_freq,obj.number_points);
            freq_list2 = ones(1,obj.number_points).*obj.NormFreq;
            freq_list(1:2:end) = freq_list1;
            freq_list(2:2:end) = freq_list2;
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
            freq_list = obj.determine_freq_list;
            freq_list(2:2:end) = [];
            rawImage = squeeze(mean(obj.data.raw_data(:,:,index,:),4));
            obj.data.data_vector(index) =  sum(rawImage(obj.pixels_of_interest));
            if strcmpi(obj.displayNorm,'Yes')
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
            else
                
                if strcmp(cur_nAverage,'Final')
                    errorbar(freq_list*10^-9,obj.data.data_vector,obj.data.error_vector,'parent',obj.ax);
                    title(obj.ax,['Final ODMR Spectrum'])
                elseif cur_nAverage>1
                    plot(freq_list*10^-9,obj.data.data_vector,'parent',obj.ax);
                    title(obj.ax,['Average ',num2str(cur_nAverage),' of ',num2str(obj.nAverages)])
                else
                    plot(freq_list(1:index)*10^-9,obj.data.data_vector(1:index),'parent',obj.ax);
                    title(obj.ax,['Average ',num2str(cur_nAverage),' of ',num2str(obj.nAverages)])
                end
                xlim(obj.ax,freq_list([1,end])*10^-9);
                xlabel(obj.ax,'Microwave Frequency (GHz)')
                ylabel(obj.ax,'Fluorescence A.U.')
            end
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
        function run(obj,statusH,managers,ax)
            %% set the control voltages
            modules = managers.Sources.modules;
            obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
            obj.ChipControl.off;
            obj.ChipControl.DriverBias = obj.DriverBias;
            %turn on all control channels
            obj.ChipControl.on;
            
            %% get DAQ
            obj.ni = Drivers.NIDAQ.dev.instance('dev1');
            obj.ni.WriteAOLines(obj.VCO_CTRL_Line,obj.switchOffVoltage);
            %% 
            
            run@Experiments.ODMR.ODMR_invisible(obj,statusH,managers,ax);
        end
        
        function get_image_axis_handle(obj)
            hObj = findall(0,'name','CommandCenter');
            handles = guidata(hObj);
            obj.axImage = handles.axImage;
        end
        
        function abort(obj)
            obj.ni.WriteAOLines(obj.VCO_CTRL_Line,obj.switchOffVoltage);
            obj.ChipControl.off;
            obj.camera.reset;
            abort@Experiments.ODMR.ODMR_invisible(obj);
        end
        
        function data = GetData(obj,~,~)
            data.data = obj.data;
            data.RF.freq = obj.determine_freq_list();
            data.RF.amp = obj.RF_power;
            data.RF.freq_step_size  = obj.freq_step_size;
            data.averages = obj.nAverages;
            data.Exposure = obj.Exposure;
            data.nOfPoints = obj.nOfPoints;
            data.switchVoltage = obj.switchVoltage;
            data.VCO_CTRL_Line = obj.VCO_CTRL_Line;
            data.ChipControl.VDD_VCO = obj.ChipControl.VDD_VCO;
            data.ChipControl.V_Capacitor = obj.ChipControl.V_Capacitor;
            data.ChipControl.VDD_Driver = obj.ChipControl.VDD_Driver;
            data.ChipControl.DriverBias = obj.ChipControl.DriverBias;
        end
    end
end