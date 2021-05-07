# Global libraries
import sys
sys.path.append(r'C:\Anaconda2\envs\py27\Lib\site-packages\swabian')

import swabian
import swabian.swabian_client as client
import numpy as np
import itertools
import matplotlib.pyplot as plt
import time
import scipy
import scipy.io
from scipy.io import savemat

# Local libraries
import swabian_timetagger
from swabian_timetagger import Swabian

CLICK_CHANNEL = int(sys.argv[1]) #default 1
TRIGGER_CHANNEL = int(sys.argv[2]) #default 5
N = int(sys.argv[3]) #Default 1000
# INT_TIME = sys.argv[4] #Default 1e9 (1ms)

swab = Swabian()
swab.start_gated_counts(click_channel=CLICK_CHANNEL, trigger_channel=TRIGGER_CHANNEL, n_values=N, trigger_delay=0)
print 'Started gated count measurement.'

