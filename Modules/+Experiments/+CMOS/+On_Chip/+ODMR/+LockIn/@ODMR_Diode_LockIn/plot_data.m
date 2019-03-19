function plot_data(obj)
voltage_list = (obj.determine_voltage_list); %frequencies in GHz
voltage_list(2:2:end) = [];
errorbar(obj.ax(1),voltage_list,obj.data.contrast_vector,obj.data.error_vector)
xlim(obj.ax(1),voltage_list([1,end]));
xlabel(obj.ax(1),'VCO Voltage (V)')
ylabel(obj.ax(1),'Normalized Current (A.U.)')
legend(obj.ax(1),{'NormData'})
title(obj.ax(1),sprintf('Performing Average %i of %i',obj.cur_nAverage,obj.nAverages))
plot(voltage_list,obj.data.voltageVector,'r*--','parent',obj.ax(2))
hold(obj.ax(2),'on')
plot(voltage_list,obj.data.voltageVectorNorm,'k--','parent',obj.ax(2))
ylabel(obj.ax(2),'Current (A)')
hold(obj.ax(2),'off')
legend(obj.ax(2),{'Data','Norm'})
title(obj.ax(2),sprintf('Performing Average %i of %i',obj.cur_nAverage,obj.nAverages))

end
