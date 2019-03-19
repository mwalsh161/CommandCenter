function start_experiment_CW(obj)

voltage_list = obj.determine_voltage_list;
obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,voltage_list(1));
pause(5); %wait for VCO to settle

obj.data.contrast_vector = NaN(1,obj.number_points);
obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
obj.data.norm_data = obj.data.raw_data;
obj.data.errorbars = obj.data.contrast_vector;

obj.laser.off;


for cur_nAverage = 1:obj.nAverages
    index=0;
    for v_n = 1:obj.number_points*2
        
        assert(~obj.abort_request,'User aborted');
        
        if mod(v_n,2)
            index = (v_n-1)/2+1;
        end
        
        obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,voltage_list(v_n));
        pause(obj.waitTimeVCOswitch)
        
        if strcmpi(obj.LaserOn,'Yes')
            obj.laser.on
            pause(0.1);
        end
        data = obj.ChipControl.Yokogawa_handle.Current;
        obj.laser.off
        if mod(v_n,2) % if odd
            obj.data.raw_data(index,cur_nAverage) = data;
        else
            obj.data.norm_data(index,cur_nAverage) = data;
        end
        
        if ~mod(v_n,2) %only plot on even because you have at least one data and normalization point
%             
%                         obj.data.contrast_vector = nansum(obj.data.raw_data,2)./nansum(obj.data.norm_data,2);
%                         obj.data.error_vector = nanstd(obj.data.raw_data./obj.data.norm_data,0,2);
            obj.data.contrast_vector = nanmean(obj.data.raw_data,2)*1e9;
            obj.data.error_vector = nanstd(obj.data.raw_data,0,2);
            obj.plot_data;
            title(obj.ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
        end
    end
end
obj.laser.off;
obj.ChipControl.off;
obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,0);
end

