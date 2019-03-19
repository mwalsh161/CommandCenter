function start_experiment_CW(obj)
try
freq_list = obj.determine_freq_list();
%% initialize data containers

obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
obj.data.raw_var = NaN(obj.number_points);
obj.data.norm_data = NaN(obj.number_points,obj.nAverages);
obj.data.norm_var = NaN(obj.number_points);
obj.data.contrast_vector = NaN(obj.number_points,1);
obj.data.error_vector = NaN(obj.number_points,1);

error = [];
%% begin experiment

obj.RF.on;
pause(10);
for cur_nAverage = 1:obj.nAverages
    index=0;
    for f_n = 1:obj.number_points*2
        
        assert(~obj.abort_request,'User aborted');
        
        if mod(f_n,2)
            index = (f_n-1)/2+1;
        end
        
        obj.RF.MWFrequency = freq_list(f_n); %this sets the reference PLL frequency
        pause(obj.waitTimeSGswitch)
%         voltage = obj.Ni.ReadAILine(obj.AILine,[obj.minVoltage,obj.maxVoltage]);
        voltage = obj.Multimeter.measureVoltage('1');
        if mod(f_n,2) % if odd
            obj.data.raw_data(index,cur_nAverage) = voltage;
        else
            obj.data.norm_data(index,cur_nAverage) = voltage;
        end
        
        if ~mod(f_n,2) %on even you have at least one data point so analyze data
            rawdDataSummed = nansum(obj.data.raw_data,2);
            normDataSummed = nansum(obj.data.norm_data,2);
            obj.data.contrast_vector = rawdDataSummed./normDataSummed;
            obj.data.raw_var = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
            obj.data.norm_var = nanstd(obj.data.norm_data,0,2)/sqrt(cur_nAverage);
            obj.data.error_vector = squeeze(nanstd(obj.data.raw_data./obj.data.norm_data,0,2)./(sqrt(cur_nAverage)));
        end
        
        if strcmp(obj.Display_Data,'Yes')
            if ~mod(f_n,2) %only plot on even because you have at least one data and normalization point
                obj.plot_data
                title(obj.ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
            end
        end
        
    end
end
catch error
    
end
obj.RF.off;
if ~isempty(error)
    rethrow(error)
end
