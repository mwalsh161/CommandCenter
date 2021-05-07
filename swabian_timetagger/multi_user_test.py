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

swab = Swabian()
# for i in range(10):
#     start =time.time()
#     counts = swab.get_coincidences(chans=[1,2], intTime=1e12)
#     print time.time() - start
#     print counts

swab.start_gated_counts(click_channel=4, trigger_channel=5, n_values=1000, trigger_delay=0)
time.sleep(1)
counts = swab.read_gated_counts()
print counts
