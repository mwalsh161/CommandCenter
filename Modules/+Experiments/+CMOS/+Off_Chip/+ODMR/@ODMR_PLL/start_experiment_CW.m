function start_experiment_CW(obj,statusH,managers,ax)
try
    
    %% run experiment
    
    obj.get_image_axis_handle();
    
    freq_list = obj.determine_freq_list();
    obj.pixels_of_interest = [];
    obj.data.contrast_vector = NaN(1,obj.number_points);
    obj.data.data_vector = NaN(1,obj.number_points);
    obj.RF.MWFrequency = freq_list(1);
    obj.RF.on;
    pause(10); %to allow for settling
    obj.laser.off;
    for cur_nAverage = 1:obj.nAverages
        index=0;
        for f_n = 1:obj.number_points*2
            
            assert(~obj.abort_request,'User aborted');
            
            if mod(f_n,2)
                index = (f_n-1)/2+1;
                obj.ni.WriteAOLines(obj.VCO_CTRL_Line,obj.switchOffVoltage);
            else
                obj.ni.WriteAOLines(obj.VCO_CTRL_Line,obj.switchVoltage);
            end
            obj.RF.MWFrequency = freq_list(f_n);
            pause(obj.pauseTime)
            
            obj.laser.on;
            if index == 1 && cur_nAverage ==1
                obj.camera.snap;
                obj.camera.snap;
            end
            image = obj.camera.snap;
            obj.laser.off;
            
            if mod(f_n,2) % if odd
                obj.data.raw_data(:,:,index,cur_nAverage) = image;
            else
                obj.data.norm_data(:,:,index,cur_nAverage) = image;
            end
            
            if strcmp(obj.Display_Data,'Yes')
                if ~mod(f_n,2) %only plot on even because you have at least one data and normalization point
                    obj.collect_data_and_plot(index,cur_nAverage,image);
                end
            end
        end
    end
    
    obj.RF.off;
    obj.ni.WriteAOLines(obj.VCO_CTRL_Line,obj.switchOffVoltage);
    obj.camera.reset;
    obj.ChipControl.off;
    obj.analyze_data;
    obj.plot_data(obj.number_points,'Final')
    
catch error
    obj.logger.log(error.message);
    obj.abort;
end
end

