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


# Main script
'''
Point-by-point acquisition of SNSPD output from Swabian server

Notes: 
- all times are in units of PICOseconds (as per Swabian API convention)
- channels are 1-indexed
- n is the number of acquired points. In this file, n must be 1.
'''

swab = Swabian()
swab_counts = swab.get_counts(chans=[1], binwidth=100e9, n=1)
print swab_counts
savemat('C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat', {'swab_counts': swab_counts})