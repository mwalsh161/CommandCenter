function runCW(obj)

voltages = obj.determine_voltage_list;
obj.ni.WriteAOLines(obj.VCO_CTRL_Line,voltages(1));
pause(5)
obj.pixels_of_interest = [];
obj.data.contrast_vector = NaN(1,obj.number_points);
for cur_nAverage = 1:obj.nAverages
    index=0;
    
    for volt = 1:2*obj.number_points
        assert(~obj.abort_request,'User aborted');
        
        if mod(volt,2)
            index = (volt-1)/2+1;
        end
        
        obj.ni.WriteAOLines(obj.VCO_CTRL_Line,voltages(volt));
        pause(obj.waitTimeVCO_s);
        obj.laser.on;
        
        if volt == 1 && cur_nAverage == 1
            obj.camera.snap;
            obj.camera.snap;
        end
        
        image = obj.camera.snap;
        obj.laser.off;
        
        
        if mod(volt,2) % if odd
            obj.data.raw_data(:,:,index,cur_nAverage) = image;
        else
            obj.data.norm_data(:,:,index,cur_nAverage) = image;
        end
        
        if strcmp(obj.Display_Data,'Yes')
            if ~mod(volt,2) %only plot on even because you have at least one data and normalization point
                obj.collect_data_and_plot(index,cur_nAverage,image);
            end
        end
        
    end
end

obj.ni.WriteAOLines(obj.VCO_CTRL_Line,0);
obj.camera.reset;
obj.laser.off;
obj.ChipControl.off;
obj.analyze_data;
obj.plot_data(obj.number_points,'Final')

end