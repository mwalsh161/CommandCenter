function start_experiment_CW(obj)

freqVector = obj.determine_freq_list;
obj.RF.MWFrequency = freqVector(1);
pause(obj.waitTimeSGswitch_us);

obj.data.contrast_vector = NaN(1,obj.number_points);
obj.data.voltageData = NaN(obj.number_points,obj.nAverages);
obj.data.voltageNorm = obj.data.voltageData;
obj.data.errorbars = obj.data.contrast_vector;


obj.laser.off;
obj.RF.on;
pause(10);

sequence = obj.setup_PB_sequence();
[program,s] = sequence.compile;
%  program = sequence.add_fixed_line(program,obj.laser.PBline-1); %set the laser line to be high throughout the sequence
obj.pulseblaster.open;
obj.pulseblaster.load(program);
obj.pulseblaster.stop;

pause_time = sequence.determine_length_of_sequence(program)+1;
period = obj.determineBinsData + obj.determineBinsOff;

for cur_nAverage = 1:obj.nAverages
    index=0;
    for f_n = 1:obj.number_points*2
        
        assert(~obj.abort_request,'User aborted');
        
        if mod(f_n,2)
            index = (f_n-1)/2+1;
        end
        
        obj.RF.MWFrequency = freqVector(f_n);
        pause(obj.waitTimeSGswitch_us)
                
        obj.CTIA.start;
        
        obj.pulseblaster.start;
        pause(pause_time);
        obj.pulseblaster.stop;
                
        data = obj.CTIA.returnData;
        
        
        
        if mod(f_n,2) % if odd
            obj.data.raw_data(:,index,cur_nAverage) = data;
        else
            obj.data.norm_data(:,index,cur_nAverage) = data;
        end
        
        if f_n == 1 && cur_nAverage == 1
            triggers = 1:obj.determineTrigNum;
            offIndexVector = []; dataIndexVector = [];
            for binNorm = 1:obj.determineBinsOff
                offIndexVector(binNorm,:) = binNorm:period:obj.determineTrigNum;
            end
            offIndexVector = sort(offIndexVector(:));
            offIndexVector(1) = [];%throw away first point because it is garbage
            
            for binData = 1:obj.determineBinsData
                dataIndexVector(binData,:) = obj.determineBinsOff+binData:period:obj.determineTrigNum;
            end
            dataIndexVector = sort(dataIndexVector(:));
        end
        
        if ~mod(f_n,2) %only plot on even because you have at least one data and normalization point
            rawdata = obj.data.raw_data(:,index,cur_nAverage);
            normdata = obj.data.norm_data(:,index,cur_nAverage);
            
            offdata = mean(rawdata(offIndexVector));
            offnorm = mean(normdata(offIndexVector));
            
            voltageData = mean(rawdata(dataIndexVector))-offdata;
            voltageNorm = mean(normdata(dataIndexVector))-offnorm;
            
            obj.data.voltageData(index,cur_nAverage) = voltageData;
            obj.data.voltageNorm(index,cur_nAverage) = voltageNorm;
            obj.data.contrast_vector = nansum(obj.data.voltageData,2)./nansum(obj.data.voltageNorm,2);
%             obj.data.contrast_vector(index) = rawdata;
            obj.data.error_vector = nanstd(obj.data.voltageData./obj.data.voltageNorm,0,2);
            obj.plot_data;
            title(obj.ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
        end
    end
end
obj.RF.off;
obj.laser.off;
obj.ChipControl.off;
obj.CTIA.stopAllTask
end

