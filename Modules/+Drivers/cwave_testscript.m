import cwave.*

cwave = instance('192.168.11.3')

disp('status:')
disp(cwave.getStatus())

disp('ref temp:')
disp(cwave.get_status_temp_ref())

disp('shg temp:')
disp(cwave.get_status_temp_shg())

disp('opo temp:')
disp(cwave.get_status_temp_opo())

disp('OPO lock:')
disp(cwave.get_status_lock_opo())

disp('etalon lock:')
disp(cwave.get_status_lock_etalon())

disp('photodiode power:')
disp(cwave.get_photodiode_laser())

disp('current OPO infrared power:')
disp(cwave.get_photodiode_opo())

cwave.target_wavelength = 615.000001
cwave.set_wavelength()

