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
Batch acquisition of SNSPD output from Swabian server. One line scan is acquired while the galvos scan location.

Notes: 
- all times are in units of PICOseconds (as per Swabian API convention)
- channels are 1-indexed
- n is the number of acquired points, must agree with number of points per line, specified by Matlab SnapSNSPD_Parallel code
'''

N = sys.argv[1]
BIN = sys.argv[2] #1e9
PAD = sys.argv[3] #1e10

swab = Swabian()
chans = swab.start_count_trace(chans=[1], binwidth=BIN, n=N, pad=PAD, debug=False)
swab_counts = swab.read_count_trace_buffer(chans)
print counts
savemat('C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat', {'swab_counts': swab_counts})
