function start_experiment(obj,statusH,managers,ax)
obj.RF.on;

obj.get_image_axis_handle;

time_list = obj.determine_time_list();

obj.pixels_of_interest=[];
ReadoutTime = obj.camera.getReadoutTime/1000+0.001; %seconds  ; get the readoutime determined by the camera based on exposure, ROI and binning
warning off
for cur_nAverage=1:obj.nAverages
    for index=1:obj.number_points
        
        assert(~obj.abort_request,'User aborted');
        
        obj.MW_on_time = time_list(index);
        
        obj.MW_on=true; %data
        obj.step_sequence;
        obj.pulseblaster.start;
        pause(obj.pause_time)
        obj.pulseblaster.stop;
        pause(ReadoutTime)
        
        pause_time(index)=obj.pause_time;
        
        obj.MW_on=false; %norm
        obj.step_sequence;
        obj.pulseblaster.start;
        pause(obj.pause_time)
        obj.pulseblaster.stop;
        pause(ReadoutTime)
        
        if strcmp(obj.Display_Data,'Yes')
            dat = [];norm = [];
            dat_image = obj.camera.snap;
            norm_image = obj.camera.snap;
            obj.data.raw_data(:,:,index,cur_nAverage) = dat_image;
            obj.data.norm_data(:,:,index,cur_nAverage) = norm_image;
            obj.collect_data_and_plot(index,cur_nAverage,dat_image);
        end
    end
end
obj.RF.off;
if strcmp(obj.Display_Data,'No')
    data_matrix = obj.camera.stopSequenceAcquisition(obj.number_points*2*cur_nAverage);
    data_images = data_matrix(:,:,1:2:end);
    norm_images = data_matrix(:,:,2:2:end);
    obj.data.raw_data = reshape(data_images,size(data_images,1),size(data_images,2),obj.number_points,obj.nAverages);
    obj.data.norm_data = reshape(norm_images,size(data_images,1),size(data_images,2),obj.number_points,obj.nAverages);
    obj.collect_data_and_plot(1,1,data_images(:,:,1));
else
    obj.camera.stopSequenceAcquisition(0);
end
obj.camera.reset;
obj.analyze_data;
obj.plot_data(obj.number_points,'Final')
end