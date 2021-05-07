import visa
import pyvisa
from pyvisa import constants
import serial
import numpy as np 
import time

TIMEOUT = 0.1
BAUDRATE = 115200

class EXFO_XTA_50(object):

    def __init__(self, port=u'ASRLCOM6::INSTR', baudrate=BAUDRATE):
        self.port =  port# Edit this for Janis
        rm = pyvisa.ResourceManager('@py')
        self.inst = rm.open_resource(u'ASRLCOM6::INSTR', baud_rate=115200, \
                                     data_bits=8, parity=constants.Parity.none, \
                                     stop_bits=constants.StopBits.one, \
                                      write_termination="\n", \
                                      read_termination="\n")

        self.name = str(self.inst.query('*IDN?'))
        # print self.name
        self.delay = 0.1

    def get_lambda(self):
        '''
        Returns set wavelength.
        '''
        time.sleep(self.delay)
        lmbd = self.inst.query("LAMBDA?")
        return float(str(lmbd)[7:])

    def set_lambda(self, lmbd):
        '''
        Wavelength setter function. 

        Input: Wavelength in nm
        '''
        time.sleep(self.delay)
        cmd = 'LAMBDA = '+ str(lmbd)
        self.inst.write(cmd)
        return None

    def get_lambda_min(self):
        '''
        Queries the XTA-50 minimum wavelength. 

        Returns: Minimum wavelength in nm. 
        '''
        time.sleep(self.delay)
        lmbd_min = self.inst.query("LAMBDA_MIN?")
        return float(str(lmbd_min)[11:])


    def get_lambda_max(self):
        '''
        Queries the XTA-50 maximum wavelength (in nm).
        '''
        time.sleep(self.delay)
        lmbd_max = self.inst.query("LAMBDA_MAX?")
        return float(str(lmbd_max)[11:])
    
    def set_freq(self, freq):
        '''
        Sets the frequency value in THz.
        '''
        time.sleep(self.delay)
        cmd = 'FREQ = '+str(freq)
        self.inst.write(cmd)

    def get_freq(self):
        '''
        Queries the current frequency value in THz.
        '''
        time.sleep(self.delay)
        freq = self.inst.write('FREQ?')
        return float(str(freq)[5:])

    def set_fwhm(self, fwhm):
        '''
        Sets a new FWHM value in nm. 
        '''
        time.sleep(self.delay)
        cmd = 'FWHM = '+str(fwhm)
        self.inst.write(cmd)


    def get_fwhm(self):
        '''
        Queries the current FWHM value in nm
        '''
        time.sleep(self.delay)
        fwhm = self.inst.write('FWHM?')
        return float(str(fwhm)[5:])

    def get_fwhm_min(self):
        '''
        TODO: implement! 
        '''
        return None

    def get_fwhm_max(self):
        '''
        TODO: implement!
        '''
        return None

    def set_fwhm_freq(self, fwhm_f):
        '''
        Sets a new FWHM in GHz
        '''
        time.sleep(self.delay)
        cmd = 'FWHM_F = '+str(fwhm_f)
        self.inst.write(cmd)

    def get_fwhm_freq(self, fwhm_f):
        '''
        Queries FWHM in GHz
        TODO: test this against the FWHM function. Looks like they might be overwritten?
        '''
        time.sleep(self.delay)
        fwhm_f = self.inst.write('FWHM_F?')
        return float(str(fwhm_f)[5:])



if __name__ == '__main__':
    x = EXFO_XTA_50(port=u'ASRLCOM6::INSTR')
    x.set_lambda(1297.0)
    print 'Set wavelength (nm) = ' + str(x.get_lambda())

    
    
    