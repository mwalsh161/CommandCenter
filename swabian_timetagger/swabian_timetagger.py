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
class Swabian(object):
    def __init__(self):
        self.timeout = 600
        self.port = 36577

    def set_int_time(self, int_time, debug=False):
        '''Set the integration time in picoseconds'''

        dbg = debug
        out = client.use_socket(function='set_intTime',
                                arglist=[int_time],
                                keep_alive=True,
                                timeout=self.timeout,
                                debug = dbg)

        # print 'Set integration time = ', int_time

    def get_int_time(self, debug=False):
        '''Returns the integration time in picoseconds'''

        dbg = debug
        out = client.use_socket(function='get_intTime',
                                arglist=[],
                                keep_alive=True,
                                timeout=self.timeout,
                                debug = dbg)

        return out

    def set_trigger_level(self, chan, v, debug=False):
        dbg = debug
        out = client.use_socket(function='set_triggerLevel',
                                arglist=[chan, v],
                                keep_alive=False,
                                timeout=self.timeout,
                                debug = dbg)

    def get_trigger_level(self, chan, debug=False):
        dbg = debug
        out = client.use_socket(function='get_triggerLevel',
                                arglist=[chan],
                                keep_alive=False,
                                timeout=self.timeout,
                                debug = dbg)

        return out

    def set_timeout(self, t):
        self.timeout = t

    # def get_count_trace(self, chans=[1], binwidth=1e9, n=1000, debug=False):
    #     dbg = debug
    #     out = client.use_socket(function='count_trace',
    #                             arglist=[chans, binwidth, n],
    #                             keep_alive=False,
    #                             timeout=self.timeout,
    #                             debug=dbg)
    #
    #     return out
    #
    # def get_count_rate(self, chans=[1], debug=False):
    #     dbg = debug
    #     out = client.use_socket(function='get_countrate',
    #                             arglist=[chans],
    #                             keep_alive=False,
    #                             timeout=self.timeout,
    #                             debug=dbg)
    #
    #     return out


    def get_counts(self, chans=[1], binwidth=1e9, n=1000, debug=False):
        '''
        Notes:
        - binwidth specified in picoseconds
        - intTime is integration time in picoseconds
        - output is the raw count rate over integration time

        '''
        intTime = binwidth * (n+1)
        dbg = debug
        out = client.use_socket(function='count_trace',
                                arglist=[chans, binwidth, n+1],
                                keep_alive=False,
                                timeout=self.timeout,
                                debug=False) #change back to dbg after time testing
        if dbg: 
            return out['start_time']
        else: 
            if len(chans)==1:
                # return np.array(out['counts'][0]) * intTime/1.e12
                return np.array(out['counts'][0][1:]) 
            else:
                return np.array(out['counts'][:,1:]) 

    def start_count_trace(self, chans=[1], binwidth=1e9, n=1000, pad=1e10, debug=False):
        '''
        Notes:
        - binwidth specified in picoseconds
        - intTime is integration time in picoseconds
        - output is the counter object to be passed to read_count_trace_buffer()

        '''

        intTime = binwidth * (n+1)
        dbg = debug
        counter = client.use_socket(function='start_count_trace',
                                arglist=[chans, binwidth, n+1, pad],
                                keep_alive=False,
                                timeout=self.timeout,
                                debug=dbg)
        
        return chans
    
    def read_count_trace_buffer(self, chans=[1], debug=False):
        '''
        Notes:
        - reads buffer initialized by start_count_trace
        - Input is counter object from start_count_trace()

        '''

        dbg = debug
        out = client.use_socket(function='read_count_trace_buffer',
                                arglist=[],
                                keep_alive=False,
                                timeout=self.timeout,
                                debug=dbg)  

        if len(chans)==1:
            # return np.array(out['counts'][0]) * intTime/1.e12
            return np.array(out['counts'][0][1:]) 
        else:
            return np.array(out['counts'][:,1:])



    def get_coincidences(self, chans=[1,2,3], coinGroups=[], intTime=1e12, window=100, debug=False):
        '''
        Notes:
        - window specified in picoseconds
        - intTime is integration time in picoseconds
        - output is the raw coincidence count over integration time

        '''
        dbg = debug

        if coinGroups == []:
            d = len(chans)
            for i in range(2, d+1):
                coinGroups += list(itertools.combinations(chans, i))

        out = client.use_socket(function='measure_coincidences',
                                arglist=[chans, coinGroups, intTime, window],
                                keep_alive=False,
                                timeout=self.timeout,
                                debug=False)

        return np.array(out['counts'])

    def start_gated_counts(self, click_channel=1, trigger_channel=5, n_values=1000, int_time=1e9, trigger_delay=0):
        '''
        Starts a CountBetweenMarkers object to count between rising edges of the NIDAQ pulse trigger

        Input: 
        - click_channel: SNSPD read channel
        - trigger_channel: BNC trigger channel at Swabian
        - n_values: number of acquisition points
        - int_time: dwell time at each galvo position
        - trigger_delay: NIDAQ trigger delay time over coax cable

        Returns: 
        - None
        '''
        client.use_socket(function='start_gated_counts',
                                arglist=[click_channel, trigger_channel, n_values, trigger_delay],
                                keep_alive=False,
                                timeout=self.timeout,
                                debug=False)
        return None
        
    def read_gated_counts(self):
        '''
        Reads CountBetweenMarkers object buffer with recorded gated counts

        Returns: 
        - counts from socket dict :  {'counts': [array of counts at each acquisition bin], 'binwidths': [array of bin times]}
        '''

        out = client.use_socket(function='read_gated_counts',
                                arglist=[],
                                keep_alive=False,
                                timeout=self.timeout,
                                debug=False)

        return np.array(out['counts'])

    def ping(self):
        '''
        Ping function to check socket connectivity over network 

        Returns: time.time() function evaluation when server received ping request
        '''

        out = client.use_socket(function='ping',
                                arglist=[], 
                                keep_alive=False, 
                                timeout = self.timeout, 
                                debug=False)

        return out



if __name__=='__main__':
    swab = Swabian()
    swab_counts = swab.get_counts(chans=[4], binwidth=100e9, n=1)
    print swab_counts
    savemat('C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat', {'swab_counts': swab_counts})
    

    # ### Start-stop testing
    # chans = swab.start_count_trace(chans=[1], binwidth=1e9, n=1000, pad=1e10, debug=False)
    # counts = swab.read_count_trace_buffer(chans)
    # print counts 
    ###


    #### Time testing
    # received = []
    # returned = []
    # print "test"

    # for i in range(10000):
    #     print i
    #     start = time.time()
    #     rec = swab.get_counts(chans=[1], binwidth=1e9, n=1, debug=True)
    #     stop = time.time()
    #     rec_time = rec - start
    #     return_time = stop - rec

    #     received += [rec_time]
    #     returned += [return_time]
        
    # print 'Mean receive time = '+str(np.mean(received)) + '+- '+str(np.std(received))
    # print 'Mean return time = '+str(np.mean(returned)) + '+- '+str(np.std(returned))

    # counts = swab.get_coincidences()
    # elapsed = time.time() - start
    # print 'Elapsed time = '+str(elapsed)+' seconds'
    # print 'Counts = '+str(counts) 

    #####


