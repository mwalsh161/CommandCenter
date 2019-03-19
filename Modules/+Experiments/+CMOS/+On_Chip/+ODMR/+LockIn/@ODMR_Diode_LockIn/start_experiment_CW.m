function start_experiment_CW(obj)
%% start pulsing

obj.pulseblaster.start;
%% 

voltage_list = obj.determine_voltage_list;
obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,voltage_list(1));
pause(5); %wait for VCO to settle

obj.data.contrast_vector = NaN(1,obj.number_points);
obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
obj.data.norm_data = obj.data.raw_data;
obj.data.errorbars = obj.data.contrast_vector;

for cur_nAverage = 1:obj.nAverages
    index=0;
    for v_n = 1:obj.number_points*2
        
        assert(~obj.abort_request,'User aborted');
        
        if mod(v_n,2)
            index = (v_n-1)/2+1;
        end
        
        obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,voltage_list(v_n));
        pause(obj.waitTimeVCOswitch)
        data = obj.LockIn.getDataChannelValue(str2num(obj.DataChanel));%Get current from LockIn

        if mod(v_n,2) % if odd
            obj.data.raw_data(index,cur_nAverage) = data;
        else
            obj.data.norm_data(index,cur_nAverage) = data;
        end
        
        if ~mod(v_n,2) %only plot on even because you have at least one data and normalization point
       
            obj.data.contrast_vector = nanmean(obj.data.raw_data./obj.data.norm_data,2);
            obj.data.error_vector = nanstd(obj.data.raw_data./obj.data.norm_data,0,2)./sqrt(cur_nAverage);
            
            obj.data.voltageVector = nanmean(obj.data.raw_data,2);
            obj.data.voltageVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
            
            obj.data.voltageVectorNorm = nanmean(obj.data.norm_data,2);
            obj.data.voltageVectorErrorNorm = nanstd(obj.data.norm_data,0,2)./sqrt(cur_nAverage);
            obj.cur_nAverage = cur_nAverage;
            obj.plot_data;
        end
    end
end

end

