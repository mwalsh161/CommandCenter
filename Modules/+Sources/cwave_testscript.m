cwave = Sources.CWave.instance();

cwave.cwave_ip = '192.168.11.3';
cwave.wavemeter_ip = '0.0.0.0';

cwave.wavemeter_channel(1);

disp(cwave.GetPercent())
disp(cwave.getFrequency())