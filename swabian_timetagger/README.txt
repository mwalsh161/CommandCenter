Date: 02/28/2021
Author: Mihika Prabhu, Michael Walsh
Contact: mihika@mit.edu


Control code to stream SNSPD timetag data over a network socket 
from the Swabian TimeTagger in Franco Wong's lab.


Requirements: 
- Python 2.7 (currently supported)

Setup configuration: 
- package installed in 'C:\\Anaconda2\\envs\\py27\\lib\\site-packages'
- current IPv4 server address (verify if socket does not connect): '18.25.25.167'

Instructions: 
"Server" -> Hardware computer (fiberbeam remote desktop in Franco's lab)
"Client" -> This computer

1. Server setup
	a) Make sure Swabian is turned on and connected in Franco's lab
	b) Start server python script by running server.py from commandline on fiberbeam 
	c) Location of server.py: 'C:\Users\user\Desktop\swabian\swabian'
2. Client setup
	a) import swabian_timetagger.py code in this directory
	b) create swabian object as i.e. 'swab = Swabian()'
3. Verify socket connection by checking fiberbeam commandline output
4. To shut down program, kill server.py script on fiberbeam.
	
	

