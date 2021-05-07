import subprocess, datetime

subprocess.call('activate base&&pip install pygame', shell=True)
subprocess.Popen('activate base&&python joystick.py', shell=True)
