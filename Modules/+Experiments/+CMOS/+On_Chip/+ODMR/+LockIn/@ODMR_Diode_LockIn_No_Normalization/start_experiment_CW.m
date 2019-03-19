function start_experiment_CW(obj)
%% start pulsing

obj.pulseblaster.start;
%% 

voltage_list = obj.determine_voltage_list;
obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,voltage_list(1));
pause(5); %wait for VCO to settle

obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
obj.data.errorbars = obj.data.raw_data;

for cur_nAverage = 1:obj.nAverages
    for v_n = 1:obj.number_points
        
        assert(~obj.abort_request,'User aborted');
        
        obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,voltage_list(v_n));
        pause(obj.waitTimeVCOswitch)
        obj.data.raw_data(v_n,cur_nAverage) = obj.LockIn.getDataChannelValue(str2double(obj.DataChanel));%Get current from LockIn
        
        
        obj.data.voltageVector = nanmean(obj.data.raw_data,2);
        obj.data.voltageVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
  
        obj.cur_nAverage = cur_nAverage;
        obj.plot_data;
    end
end

end

