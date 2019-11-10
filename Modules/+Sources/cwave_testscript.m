cwave = Sources.CWave.instance();

cwave.cwave_ip = '192.168.11.3';
cwave.pulseStreamer_ip = '192.168.11.4';
cwave.wavemeter_ip = '192.168.11.2';


disp('starting vals')
disp(cwave.GetPercent())
disp(cwave.getFrequency())

%cwave.TunePercent(10)
cwave.TuneSetpoint(618.9488);
disp('after tunepercent to 10')
disp(cwave.GetPercent())
disp(cwave.getFrequency())