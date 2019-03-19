function start_experiment(obj,statusH,managers,ax)


nAverages = obj.nAverages;
if strcmp(obj.disp_mode,'fast')
    nAverages = 1; %if in fast mode, averages already included in pulse sequence
end

time_list = obj.determine_time_list;
obj.data.time_list = time_list;
obj.data.raw_data = nan(obj.number_points,nAverages);
obj.data.raw_var = nan(obj.number_points,nAverages);
obj.data.norm_data = nan(obj.number_points,nAverages);
obj.data.norm_var = nan(obj.number_points,nAverages);
obj.data.contrast_vector = nan(obj.number_points,1);
obj.data.error_vector = nan(obj.number_points,1);

obj.f = figure('visible','off','name',mfilename);
a = axes('Parent',obj.f);
dataObj = plot(NaN,NaN,'Parent',a);

obj.RF.on; %turn MW on
for cur_ave = 1:nAverages
    for tau = 1:obj.number_points
        obj.tau = time_list(tau);
        [obj.sequence] = obj.setup_PB_sequence();
        
        
        APDpseq = APDPulseSequence(obj.Ni,obj.pulseblaster,obj.sequence);
        
        assert(~obj.abort_request,'User aborted');
        
        APDpseq.start(1e4);
        APDpseq.stream(dataObj)
        
        obj.data.raw_data(tau,cur_ave) = squeeze(mean(dataObj.YData(1:2:end)));
        obj.data.raw_var(tau,cur_ave) = squeeze(var(dataObj.YData(1:2:end)));
        obj.data.norm_data(tau,cur_ave) = squeeze(mean(dataObj.YData(2:2:end)));
        obj.data.norm_var(tau,cur_ave) = squeeze(var(dataObj.YData(2:2:end)));
        num_data_bins = length(dataObj.YData)/2;
        
        %transient calculations for current tau to get
        %contrast and error
        raw_data_total = squeeze(nanmean(obj.data.raw_data(tau,:)));
        raw_err_total = sqrt(squeeze(nanmean(obj.data.raw_var(tau,:)))/(cur_ave*num_data_bins));
        norm_data_total = squeeze(nanmean(obj.data.norm_data(tau,:)));
        norm_err_total = sqrt(squeeze(nanmean(obj.data.norm_data(tau,:)))/(cur_ave*num_data_bins));
        
        obj.data.contrast_vector(tau) = raw_data_total./norm_data_total;
        obj.data.error_vector(tau) = obj.data.contrast_vector(tau)*...
            sqrt((raw_err_total/raw_data_total)^2+(norm_err_total/norm_data_total)^2);
        
        obj.plot_data;
        title(obj.ax,sprintf('Performing Average %i of %i',cur_ave,obj.nAverages))
    end
end
obj.RF.off %turn MW on
delete(obj.f);
end