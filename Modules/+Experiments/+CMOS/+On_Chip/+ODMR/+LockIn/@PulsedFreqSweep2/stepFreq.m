function stepFreq(obj,freq)

obj.RF.serial.turnModulationOffAll;
obj.RF.SGref.serial.setFreqMode('CW');
obj.RF.SGref.serial.setPowerMode('CW')

power_list = obj.MWPower.*ones(1,2);
obj.RF.SGref.serial.program_list([freq,obj.normFreq]./obj.RF.PLLDivisionRatio,power_list)
obj.RF.SGref.on; %turn on SG but not the switch
end