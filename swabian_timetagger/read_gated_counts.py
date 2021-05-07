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
swab_counts = swab.read_gated_counts()
savemat('C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat', {'swab_counts': swab_counts})