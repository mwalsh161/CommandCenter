function start_experiment_Ext_PB(obj)
obj.RF.on;

obj.get_image_axis_handle;

obj.pixels_of_interest = [];

sequence = obj.setup_PB_sequence();
[program,s] = sequence.compile;
obj.pulseblaster.open;
obj.pulseblaster.load(program);
obj.pulseblaster.stop;

obj.data.contrast_vector = NaN(1,obj.number_points);
pause_time = sequence.determine_length_of_sequence(program);

for cur_nAverage = 1:obj.nAverages
    for index = 1:obj.number_points
        
        assert(~obj.abort_request,'User aborted');
        
        obj.pulseblaster.start;
        pause(pause_time)
        obj.pulseblaster.stop;
        
        if strcmp(obj.Display_Data,'Yes')
            dat_image = [];norm_image = [];
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
obj.analyze_data;
obj.plot_data(obj.number_points,'Final')

end
