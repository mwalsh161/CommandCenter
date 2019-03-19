classdef ODMR_No_PLL < Experiments.CMOS.CMOS_invisible
    
    properties
        abort_request = false;  % Request flag for abort
        data
        pixels_of_interest
        axImage
        ax
        ChipControl
        camera
        laser
        ni
        prefs = {'V_Capacitor','DriverBias','Exposure','nAverages','start_voltage','stop_voltage','number_points',...
            'trig_type','norm_voltage','Display_Data','waitTimeVCO_s','nOfPoints','VCO_CTRL_Line'}
    end
    
    properties(SetObservable)
        V_Capacitor = 2;
        Exposure = 30;
        trig_type = {'Internal'};
        norm_voltage = 0;
        Display_Data ={'Yes','No'};
        nAverages = 5;
        start_voltage = 0.5;
        stop_voltage = 1.5;
        number_points = 60; %number of frequency points desired
        waitTimeVCO_s = 0.1; %time to wait for VCO to step in voltage in seconds
        VCO_CTRL_Line = 'VCO_CTRL';
        nOfPoints = 5;
    end
    
    methods(Access=private)
        function obj = ODMR_No_PLL()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.Off_Chip.ODMR.ODMR_No_PLL();
            end
            obj = Object;
        end
    end
    
    methods
        
         function voltage_list = determine_voltage_list(obj)
            voltage_list = zeros(1,2*obj.number_points);
            voltage_list_data = linspace(obj.start_voltage,obj.stop_voltage,obj.number_points);
            voltage_list_norm = ones(1,obj.number_points).*obj.norm_voltage;
            voltage_list(1:2:end) = voltage_list_data;
            voltage_list(2:2:end) = voltage_list_norm;
         end
        
        function run(obj,statusH,managers,ax)
            try
                %% initialize some values
                obj.ax = ax;
                obj.get_image_axis_handle;
                obj.abort_request = false;
                %% get DAQ
                obj.ni = Drivers.NIDAQ.dev.instance('dev1');
                obj.ni.WriteAOLines(obj.VCO_CTRL_Line,0);
                %% get laser
                modules = managers.Sources.modules;
                obj.laser = obj.find_active_module(modules,'Green_532Laser');
                obj.laser.off;
                %% set the control voltages
                modules = managers.Sources.modules;
                obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
                obj.ChipControl.off;
                obj.ChipControl.DriverBias = obj.DriverBias;
                obj.ChipControl.V_Capacitor = obj.V_Capacitor;
                obj.ChipControl.on;%turn on all control channels
                %% camera
                obj.camera = managers.Imaging.active_module.instance;
                assert(~obj.camera.continuous,'Camera must be turned off')
                obj.camera.reset;
                obj.data = [];
                %% run ODMR experiment
                obj.runCW;
            catch
                obj.abort;
            end
        end
        
        function get_image_axis_handle(obj)
            hObj = findall(0,'name','CommandCenter');
            handles = guidata(hObj);
            obj.axImage = handles.axImage;
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
         
        function abort(obj)
            obj.abort_request = true;
            obj.ChipControl.off;
            obj.camera.reset;
            obj.laser.off;
            obj.ni.WriteAOLines(obj.VCO_CTRL_Line,0);
        end
        
         function plot_data(obj,index,cur_nAverage)
            voltage_list = obj.determine_voltage_list();
            voltage_list(2:2:end) = [];
            if strcmp(cur_nAverage,'Final')
                errorbar(voltage_list,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax);
                title(obj.ax,['Final ODMR Spectrum'])
            elseif cur_nAverage>1
                plot(voltage_list,obj.data.contrast_vector,'parent',obj.ax);
                title(obj.ax,['Average ',num2str(cur_nAverage),' of ',num2str(obj.nAverages)])
            else
                plot(voltage_list(1:index),obj.data.contrast_vector(1:index),'parent',obj.ax);
                title(obj.ax,['Average ',num2str(cur_nAverage),' of ',num2str(obj.nAverages)])
            end
            xlim(obj.ax,voltage_list([1,end]));
            xlabel(obj.ax,'VCO Voltage (V)')
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
        
        function plot_image(obj,im)
            imagesc(im,'parent',obj.axImage);
            axis image
            axis xy
            colorbar(obj.axImage)
            axis(obj.axImage,'image');
            drawnow
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
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.VCO.voltage_list = obj.determine_voltage_list();
                data.averages = obj.nAverages;
                data.DriverBias = obj.DriverBias;
                data.trig_type = obj.trig_type;
                data.norm_voltage = obj.norm_voltage;
                data.Display_Data = obj.Display_Data;
                data.waitTimeVCO_s = obj.waitTimeVCO_s;
                data.ChipControl.VCO_CTRL_Line = obj.VCO_CTRL_Line;
                data.ChipControl.VDD_VCO = obj.ChipControl.VDD_VCO; 
                data.ChipControl.V_Capacitor = obj.ChipControl.V_Capacitor;
                data.ChipControl.VDD_Driver = obj.ChipControl.VDD_Driver;
                data.ChipControl.DriverBias = obj.ChipControl.DriverBias;
                data.camera.Exposure = obj.Exposure;
                data.camera.binning = obj.camera.binning;
                data.camera.readOutTime = obj.camera.getReadoutTime;
                data.camera.gain = obj.camera.getEMGain;
                data.camera.ROI = obj.camera.ROI;
                data.data = obj.data;
            else
                data = [];
            end
        end
    end
end