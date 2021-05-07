import scipy
from scipy.io import savemat

if __name__=='__main__':
    a = [1,2,3,4]
    savemat('C:\Users\Janis\ControlSoftware\swabian_timetagger\python_test.mat', {'a': a})
    print 'finished saving test file'