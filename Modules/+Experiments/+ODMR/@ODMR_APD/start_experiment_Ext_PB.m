function start_experiment_Ext_PB(obj,statusH,managers,ax)
            pulse_sequence = obj.setup_PB_sequence();
            APDseq = APDPulseSequence(obj.Ni,obj.pulseblaster,pulse_sequence);
            
            if strcmp(obj.disp_mode,'fast')
                obj.nAverages = 1; %if in fast mode, averages already included in pulse sequence
            end
            
            obj.data.raw_data = nan(obj.number_points,obj.nAverages);
            obj.data.raw_var = nan(obj.number_points,obj.nAverages);
            obj.data.norm_data = nan(obj.number_points,obj.nAverages);
            obj.data.norm_var = nan(obj.number_points,obj.nAverages);
            obj.data.contrast_vector = nan(obj.number_points,1);
            obj.data.error_vector = nan(obj.number_points,1);
            
            obj.f = figure('visible','off','name',mfilename);
            a = axes('Parent',obj.f);
            dataObj = plot(NaN,NaN,'Parent',a);
            
            obj.RF.on %turn MW on
            for cur_ave = 1:obj.nAverages
                for freq = 1:obj.number_points
                    
                    assert(~obj.abort_request,'User aborted');
                    
                    APDseq.start(1e4);
                    APDseq.stream(dataObj);
                    
                    obj.data.raw_data(freq,cur_ave) = squeeze(mean(dataObj.YData(1:2:end)));
                    obj.data.raw_var(freq,cur_ave) = squeeze(var(dataObj.YData(1:2:end)));
                    obj.data.norm_data(freq,cur_ave) = squeeze(mean(dataObj.YData(2:2:end)));
                    obj.data.norm_var(freq,cur_ave) = squeeze(var(dataObj.YData(2:2:end)));
                    num_data_bins = length(dataObj.YData)/2;
                    
                    %transient calculations for current frequency to get
                    %contrast and error
                    raw_data_total = squeeze(nanmean(obj.data.raw_data(freq,:)));
                    raw_err_total = sqrt(squeeze(nanmean(obj.data.raw_var(freq,:)))/(cur_ave*num_data_bins));
                    norm_data_total = squeeze(nanmean(obj.data.norm_data(freq,:)));
                    norm_err_total = sqrt(squeeze(nanmean(obj.data.norm_data(freq,:)))/(cur_ave*num_data_bins));
                    
                    obj.data.contrast_vector(freq) = raw_data_total./norm_data_total;
                    obj.data.error_vector(freq) = obj.data.contrast_vector(freq)*...
                        sqrt((raw_err_total/raw_data_total)^2+(norm_err_total/norm_data_total)^2);
                    obj.plot_data
                    title(obj.ax,sprintf('Performing Average %i of %i',cur_ave,obj.nAverages))
                end
            end
            obj.RF.off %turn MW off
            delete(obj.f);
            obj.plot_data;
            title('Final ODMR Contrast')
        end