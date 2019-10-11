clear CWave;
clc;

cwave = Drivers.CWave.instance('192.168.11.3');
wavemeter = Drivers.Wavemeter.instance('0.0.0.0', 1, 1); % IP address of wavemeter?

disp('wavemeter:')
disp(wavemeter.getWavelength())

%cwave.abort_tune()

%disp(cwave.get_status_temp_ref())

%disp('status:')
%disp(cwave.get_statusbits())

disp('ref temp:')
disp(cwave.get_status_temp_ref())

disp('shg temp:')
disp(cwave.get_status_temp_shg())

disp('opo temp:')
disp(cwave.get_status_temp_opo())

%failed status=1, 'optimization has not stopped'
cwave.abort_tune()

%failed status=1, 'opo not locked, optimization still in progress'
%disp('OPO lock:')
%disp(cwave.get_status_lock_opo())

%failed status=1, 'etalon not locked, optimization still in progress'
%disp('etalon lock:')
%disp(cwave.get_status_lock_etalon())

disp('photodiode power:')
disp(cwave.get_photodiode_laser())

disp('current OPO infrared power:')
disp(cwave.get_photodiode_opo())

disp('current piezo percent:')
disp(cwave.get_ref_cavity_percent())

%cwave.target_wavelength = 615.000001;
%cwave.set_target_wavelength()

disp('new piezo percent:')
disp(cwave.get_ref_cavity_percent())

