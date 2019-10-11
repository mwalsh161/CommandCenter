cwave = Sources.CWave.instance();

cwave.cwave_ip = '192.168.11.3';
cwave.wavemeter_ip = '0.0.0.0';

cwave.wavemeter_channel(1);

disp('starting vals')
disp(cwave.GetPercent())
%disp(cwave.getFrequency())

cwave.TunePercent(10)

disp('after tunepercent to 10')
disp(cwave.GetPercent())
%disp(cwave.getFrequency())