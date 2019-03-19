function plot_data(obj)
voltage_list = (obj.determine_voltage_list); %frequencies in GHz
errorbar(voltage_list,obj.data.voltageVector,obj.data.voltageVectorError,'r*--','parent',obj.ax)
ylabel(obj.ax,'Current (A)')
legend(obj.ax,'Data')
xlim(obj.ax,voltage_list([1,end]));
title(obj.ax,sprintf('Performing Average %i of %i',obj.cur_nAverage,obj.nAverages))

end
