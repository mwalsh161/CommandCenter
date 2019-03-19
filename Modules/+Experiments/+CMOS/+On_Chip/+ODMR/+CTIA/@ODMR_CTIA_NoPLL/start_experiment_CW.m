function start_experiment_CW(obj)

voltage_list = obj.determine_voltage_list;
obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,voltage_list(1));
pause(5); %wait for VCO to settle

obj.data.contrast_vector = NaN(1,obj.number_points);
obj.data.voltageData = NaN(obj.number_points,obj.nAverages);
obj.data.voltageNorm = obj.data.voltageData;
obj.data.errorbars = obj.data.contrast_vector;
obj.data.voltageVector = obj.data.contrast_vector;
obj.data.voltageVectorError = obj.data.errorbars;
obj.data.voltageVectorNorm = obj.data.contrast_vector;
obj.data.voltageVectorErrorNorm = obj.data.errorbars;


obj.laser.off;

sequence = obj.setup_PB_sequence();
[program,s] = sequence.compile;
if strcmpi(obj.LaserOn,'Yes')
  program = sequence.add_fixed_line(program,obj.laser.PBline-1); %set the laser line to be high throughout the sequence
end
obj.pulseblaster.open;
obj.pulseblaster.load(program);
obj.pulseblaster.stop;

pause_time = sequence.determine_length_of_sequence(program);
period = obj.determineBinsData + obj.determineBinsOff;
for cur_nAverage = 1:obj.nAverages
    index=0;
    for v_n = 1:obj.number_points*2
        
        assert(~obj.abort_request,'User aborted');
        
        if mod(v_n,2)
            index = (v_n-1)/2+1;
        end
        
        obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,voltage_list(v_n));
        pause(obj.waitTimeVCOswitch)
                
        obj.CTIA.start;
        
        obj.pulseblaster.start;
        pause(pause_time);
        obj.pulseblaster.stop;
                
        data = obj.CTIA.returnData;
        
        plot((1:2*period).*obj.minSampling,data(1:2*period),'parent',obj.axImage)
        ylabel(obj.axImage,'Voltage Raw Data (V)')
        xlabel(obj.axImage,'Time (microseconds)')
        
        if mod(v_n,2) % if odd
            obj.data.raw_data(:,index,cur_nAverage) = data;
        else
            obj.data.norm_data(:,index,cur_nAverage) = data;
        end
        
        if v_n == 1 && cur_nAverage == 1
            offIndexVector = []; dataIndexVector = [];
            offIndexVector = obj.triggerVector > obj.OutputVoltage/2;
            dataIndexVector = obj.triggerVector < obj.OutputVoltage/2;
            
            offIndexVector(1) = []; %first data point is trash
        end
        
        if ~mod(v_n,2) %only plot on even because you have at least one data and normalization point
            rawdata = obj.data.raw_data(:,index,cur_nAverage);
            normdata = obj.data.norm_data(:,index,cur_nAverage);
            
            offdata = mean(rawdata(offIndexVector));
            offnorm = mean(normdata(offIndexVector));
            
            voltageData = rawdata(dataIndexVector);
            voltageNorm = normdata(dataIndexVector);
            
            obj.data.voltageData(index,cur_nAverage) = nansum(voltageData,1);
            obj.data.voltageNorm(index,cur_nAverage) = nansum(voltageNorm,1);
         
            obj.data.contrast_vector = nansum(obj.data.voltageData,2)./nansum(obj.data.voltageNorm,2);
            obj.data.error_vector = nanstd(obj.data.voltageData,0,2);
            
            obj.data.voltageVector(index) = nanmean(voltageData,1);
            obj.data.voltageVectorError(index) = nanstd(voltageData,0,1);
            
            obj.data.voltageVectorNorm(index) = nanmean(voltageNorm,1);
            obj.data.voltageVectorErrorNorm(index) = nanstd(voltageNorm,0,1);
            
            obj.plot_data;
            title(obj.ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
        end
    end
end
obj.laser.off;
obj.ChipControl.off;
obj.CTIA.stopAllTask
obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,0);
end

