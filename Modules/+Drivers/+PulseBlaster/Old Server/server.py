import os, sys, socket, logging, traceback, urllib, json, fnmatch
from subprocess import check_output
from subprocess import CalledProcessError
import win32serviceutil, win32event, win32service, servicemanager
import firewall_check
from logging.handlers import RotatingFileHandler

HELP = '''send as urlencoded (plus) json strings with fields:
"cmd" for the command [reset, start, stop, load, open, close]
"clk" for a load command
"code" for a load command

response will be urlencoded (plus)

terminated on "\\n"'''

PATH = 'C:\\SpinCore\\PulseBlaster Server'
# Setup logging
logFile = os.path.join(PATH,'PBserver.log')
log_formatter = logging.Formatter('[%(asctime)s] %(levelname)-7.7s: %(message)s')

# Log to rotating file
if not os.path.isdir(PATH):
    os.mkdir(PATH)
rot_handler = RotatingFileHandler(logFile,maxBytes=100*1024,backupCount=5)

rot_handler.setFormatter(log_formatter)

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.addHandler(rot_handler)

def find_files(directory, pattern):
    # Recursively go through directory to find pattern
    for root, dirs, files in os.walk(directory):
        for basename in files:
            if fnmatch.fnmatch(basename, pattern):
                filename = os.path.join(root, basename)
                yield filename

DEFAULT_IP = '0.0.0.0'
DEFAULT_PORT = 36576
TEMP_FILE = os.path.join(PATH,'temp.pb')
COMMAND = [fname for fname in find_files(os.path.join('C:',os.sep,'SpinCore'),'spbicl.exe')][0]
CONNECTED_CLIENT = None # Allow one user at a time
CONNECTED_CLIENT_TEMP_FILE = os.path.join(PATH,'client.txt')

class pbIOError(IOError):
    # Just to help clarify PB errors
    pass

def start():
    out = check_output([COMMAND,'start'],shell=True)
    return out[:-1]

def stop():
    out = check_output([COMMAND,'stop'],shell=True)
    return out[:-1]

def load(msg):
    if 'code' not in msg.keys():
        raise pbIOError('code not found in json object')
    if 'clk' not in msg.keys():
        raise pbIOError('clk not found in json object')
    code = msg['code']
    logging.info('Received %i characters of code.'%len(code))
    logging.info('Received clk: '+str(msg['clk']))
    try:
        float(msg['clk'])
    except ValueError:
        raise pbIOError('clk must be numeric.')
    clk = str(msg['clk'])
    with open(TEMP_FILE,'w') as fid:  # This will overwrite an existing file
        fid.write(code)
    
    out = check_output([COMMAND,'load',TEMP_FILE,clk],shell=True)
    return out[:-1]

def set_client(client):
    global CONNECTED_CLIENT
    if client:
        with open(CONNECTED_CLIENT_TEMP_FILE,'w') as fid:
            fid.write(client+os.linesep)
    elif os.path.isfile(CONNECTED_CLIENT_TEMP_FILE):
        os.remove(CONNECTED_CLIENT_TEMP_FILE)
    CONNECTED_CLIENT = client

def parse(connection,msg,client_ip):
    global CONNECTED_CLIENT   # Necessary because we modify it
    msg = json.loads(msg)
    command = msg['cmd'].lower()
    if command == 'reset':
        set_client(None)
        return 'Session reset, try opening a session again.'
    if CONNECTED_CLIENT is None:
        if command == 'open':
            set_client(client_ip)
            return 'Session opened to ip %s'%CONNECTED_CLIENT
        else:
            raise pbIOError('Client has not started a session.')
    if CONNECTED_CLIENT != client_ip:
        raise pbIOError('Another client is in session, try later or force reset.')
        
    # User is connected, proceed...
    if command == 'start':
        return start()
    elif command == 'stop':
        return stop()
    elif command == 'load':
        return load(msg)
    elif command == 'close':
        set_client(None)
        return 'Session closed.'
    elif command == 'open':
        # Client being redundant, but whatev - shouldn't cause error
        return 'Session opened to ip %s'%CONNECTED_CLIENT
    raise pbIOError('Incorrect command.\n\n'+HELP)

def recv(connection,delim='\n',recv_buffer=4096):
    buffer = ''
    while True:
        data = connection.recv(recv_buffer)
        assert data, 'Client disconnected while receiving.'
        buffer += data
        if data[-1] == '\n':
            return buffer[0:-len(delim)]  # Remove delim

class PBserverSVC(win32serviceutil.ServiceFramework):
    _svc_name_ = "PBserver"
    _svc_display_name_ = "PulseBlaster Server"
    
    def __init__(self,args):
        win32serviceutil.ServiceFramework.__init__(self,args)
        self.stop_event = win32event.CreateEvent(None,0,0,None)
        socket.setdefaulttimeout(60)
        self.stop_requested = False

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.stop_event)
        logging.info('Stopping service ...')
        self.stop_requested = True

    def SvcDoRun(self):
        servicemanager.LogMsg(
            servicemanager.EVENTLOG_INFORMATION_TYPE,
            servicemanager.PYS_SERVICE_STARTED,
            (self._svc_name_,'')
        )
        self.main()

    def main(self):
        global CONNECTED_CLIENT
        # Reconnect a lost client connection
        if os.path.isfile(CONNECTED_CLIENT_TEMP_FILE):
            with open(CONNECTED_CLIENT_TEMP_FILE,'r') as fid:
                CONNECTED_CLIENT = fid.read().strip()
            logging.info('Re-opening client session: %s'%CONNECTED_CLIENT)
        
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        server_address=(DEFAULT_IP,DEFAULT_PORT)
        sock.bind(server_address)
        logging.info('starting up on %s port %s'%server_address)
        sock.listen(0)
        try:
            while True:
                if CONNECTED_CLIENT is None:
                    logging.info('waiting for connection...')
                else:
                    logging.info('waiting for connection from %s...'%CONNECTED_CLIENT)
                while True:
                    # Keep looking for client
                    try:
                        connection, client_address = sock.accept()
                        break
                    except:
                        if self.stop_requested:
                            break
                if self.stop_requested:
                    break
                try:
                    logging.info('connection from: %s:%i'%client_address)
                    cmd = urllib.unquote_plus(recv(connection))
                    logging.debug('command: %s'%cmd)
                    try:
                        output = parse(connection,cmd,client_address[0])
                    except pbIOError as err:
                        output = 'Error: %s'%err.message
                        logging.error(traceback.format_exc())
                    except CalledProcessError as err:
                        output = 'Error: %s'%err.output
                        logging.error(traceback.format_exc())
                    logging.debug('    '+output)
                    output = output.replace('\r\n','\n')
                    connection.sendall(urllib.quote_plus(output.strip())+'\n')
                except:
                    logging.error(traceback.format_exc())
                finally:
                    connection.close()
        except:
            logging.error(traceback.format_exc())
        finally:
            sock.close()
            logging.info('server shutting down')

if __name__ == '__main__':
    logging.info('Attempting to start service.')
    # Check firewall status
    try:
        python_serv_name = 'pythonservice.exe'
        [inbound,outbound,restricted]=firewall_check.test_rule(python_serv_name)
        logging.info('Python Service %s\nInbound: %r\nOutbound: %r\nPossibly restricted: %r'%(python_serv_name,inbound,outbound,restricted))
    except:
        logging.info('Failed to check firewall for %s'%python_serv_name)
        logging.error(traceback.format_exc())

    try:
        win32serviceutil.HandleCommandLine(PBserverSVC)
    except:
        logging.error(traceback.format_exc())
