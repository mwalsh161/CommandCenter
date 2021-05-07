# Global libraries
import numpy as np 
import time 
import sys
import datetime
import matplotlib.pyplot as plt

# Local libraries
import exfo_xta_50
from exfo_xta_50 import EXFO_XTA_50 as exfo_filter 
import swabian_timetagger
from swabian_timetagger.swabian_timetagger import Swabian

DELAY = 0.2
BINWIDTH = 1e12

# Initialize the filter object 
filt = exfo_filter(port=u'ASRLCOM6::INSTR')
filt.set_fwhm(0.1)

# Initialize Swabian object
swab = Swabian()

# Try to import sweep settings from commandline script call. Should be of the form: 
# >> python filter_sweep.py wl_start wl_stop wl_points
try: 
    wl_start = sys.argv[1]
except: 
    wl_start = 1260.0
    print "Wavelength start point not specified. Setting to (nm): " + str(wl_start)

try: 
    wl_stop = sys.argv[2]
except: 
    wl_stop = 1355.0
    print "Wavelength stop point not specified. Setting to (nm): " + str(wl_stop)

try: 
    wl_points = sys.argv[3]
except: 
    wl_points = 1500
    print "Number of sweep points not specified. Setting to "+str(wl_points)


# Set up the sweep: 
wls = np.linspace(wl_start, wl_stop, wl_points)
counts = np.zeros((wl_points,1))
for i,wl in enumerate(wls):
    print i
    filt.set_lambda(wl)
    time.sleep(DELAY)
    swab_counts = swab.get_counts(chans=[4], binwidth=BINWIDTH, n=1)
    counts[i] = float(swab_counts)
    print swab_counts

now = datetime.datetime.now()
date_time = str(now.strftime('%m%d%y_%H%M%S'))
plt.plot(wls, counts)
plt.show()

np.save('C:\Users\Janis\CommandCenter\swabian_timetagger\wl_sweep_' + date_time, {'wl_start': wl_start, 'wl_stop': wl_stop, 'counts': counts, 'int_time_ps': BINWIDTH})

# savemat('C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat', {'swab_counts': swab_counts})  







