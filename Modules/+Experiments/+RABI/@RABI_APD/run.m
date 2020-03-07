function run(obj,statusH,managers,ax)
try
    %% initialize some values
    
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    
    message = [];
    obj.data = [];
    
    %% generate subplot axis
    
    assert(~obj.abort_request,'User aborted');
    panel = ax.Parent;
    s1 = subplot(3,1,1,'parent',panel);
    s2 = subplot(3,1,2,'parent',panel);
    s3 = subplot(3,1,3,'parent',panel);
    
    %% determine experimental conditions
    
    assert(~obj.abort_request,'User aborted');
    %sweep parameter
    time_list = linspace(obj.start_time,obj.stop_time,obj.number_points);
    
    %number of averages
    nAverages = obj.nAverages;
    if strcmp(obj.disp_mode,'fast')
        nAverages = 1; %if in fast mode, averages already included in pulse sequence
    end
    
    %% setup SG
    
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.RF = obj.find_active_module(modules,'Signal_Generator');
    obj.RF.serial.reset;
    obj.RF.MWPower = obj.RF_power;
    obj.RF.MWFrequency = obj.CW_freq;
    obj.RF.on; %turn MW on
    pause(5) %let SG heat up
      
    %% setup APD for data collection
    
    assert(~obj.abort_request,'User aborted');
    obj.Ni = Drivers.NIDAQ.dev.instance('Dev1');
    obj.Ni.ClearAllTasks;
    
    obj.f = figure('visible','off','name',mfilename);
    a = axes('Parent',obj.f);
    dataObj = plot(NaN,NaN,'Parent',a);
    
    %%  setup laser
    
    assert(~obj.abort_request,'User aborted');
    obj.Laser = obj.find_active_module(modules,'Green_532Laser');
    obj.Laser.off;
    
      %% setup pulseblaster and sequence
      
    assert(~obj.abort_request,'User aborted');
    obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
    obj.MW_on_time = time_list(1);
    [s,n_MW,n_MW_on] = obj.setup_PB_sequence();
    %% 
%     program = s.compile;
%     
%     obj.pulseblaster.load(program);
%     obj.pulseblaster.stop;
%     obj.pulseblaster.start;
    
    
    %% preallocate memory for experiment
    
    obj.data.time_list = time_list;
    obj.data.raw_data = nan(obj.number_points,nAverages);
    obj.data.raw_var = nan(obj.number_points,nAverages);
    obj.data.norm_data = nan(obj.number_points,nAverages);
    obj.data.norm_var = nan(obj.number_points,nAverages);
    obj.data.contrast_vector = nan(obj.number_points,1);
    obj.data.error_vector = nan(obj.number_points,1);
    obj.data.raw_data_total = nan(obj.number_points,1);
    obj.data.norm_data_total = nan(obj.number_points,1);
    obj.data.raw_err_total = nan(obj.number_points,1);
    obj.data.norm_err_total = nan(obj.number_points,1);
    
    %% run experiment
    isMade = false;
    for cur_ave = 1:nAverages
        for tau = 1:obj.number_points
            
            assert(~obj.abort_request,'User aborted');
            
            obj.MW_on_time = time_list(tau);
            n_MW.delta = -obj.MW_on_time;
            n_MW_on.delta = obj.MW_on_time;

            APDpseq = APDPulseSequence(obj.Ni,obj.pulseblaster,s);
           
            try
                APDpseq.start(1e4);
            catch errorMessage
                warning(errorMessage.message);
                obj.Ni.ClearAllTasks;
                continue
            end
            
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
            
            obj.data.raw_data_total(tau) = raw_data_total;
            obj.data.norm_data_total(tau) = norm_data_total;
            
            obj.data.raw_err_total(tau) = raw_err_total;
            obj.data.norm_err_total(tau) = norm_err_total;
            
            if ~isMade
                %not made so make it
                errorbar(time_list,obj.data.raw_data_total,obj.data.raw_err_total,'parent',s1);
                xlim(s1,time_list([1,end]));
                xlabel(s1,'Microwave on Time (ns)')
                ylabel(s1,'Fluorescence (Counts)')
                title(s1,'raw data')
                
                errorbar(time_list,obj.data.norm_data_total,obj.data.norm_err_total,'parent',s2);
                xlim(s2,time_list([1,end]));
                xlabel(s2,'Microwave on Time (ns)')
                ylabel(s2,'Fluorescence (Counts)')
                title(s2,'norm data')
                
                errorbar(time_list,obj.data.contrast_vector,obj.data.error_vector,'parent',s3);
                xlim(s3,time_list([1,end]));
                xlabel(s3,'Microwave on Time (ns)')
                ylabel(s3,'Normalized Fluorescence')
                
                isMade = true;
                
            else
                %subplots made so just update children
                
                s1.Children.YData = obj.data.raw_data_total;
                s1.Children.YNegativeDelta = obj.data.raw_err_total;
                s1.Children.YPositiveDelta = obj.data.raw_err_total;
                
                s2.Children.YData = obj.data.norm_data_total;
                s2.Children.YNegativeDelta = obj.data.norm_err_total;
                s2.Children.YPositiveDelta = obj.data.norm_err_total;
                
                s3.Children.YData = obj.data.contrast_vector;
                s3.Children.YNegativeDelta = obj.data.error_vector;
                s3.Children.YPositiveDelta = obj.data.error_vector;
            end
            
            if strcmp(obj.disp_mode,'fast')
                title(s3,sprintf('Rabi'))
            else
                title(s3,sprintf('Ratio: Performing Average %i of %i',cur_ave,obj.nAverages))
            end
        end
    end
    
catch message
    
end

%% cleanup
obj.pulseblaster.stop;
obj.RF.off %turn MW on
delete(obj.f);
obj.RF.serial.reset;
obj.Laser.off;

%%
if ~isempty(message)
    rethrow(message)
end

end