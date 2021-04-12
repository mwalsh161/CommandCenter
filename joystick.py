import pygame, socket

pygame.init()

# Loop until the user clicks the close button.
done = False
debug = False
thresh = 3.1e-05

# Used to manage how fast the screen updates.
clock = pygame.time.Clock()

# Initialize the joysticks.
pygame.joystick.init()

# create an INET, STREAMing socket
serversocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
# Allow this socket to reuse previous connections, now on TIME_WAIT. Otherwise, an error occurs.
serversocket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
# bind the socket to a public host, and a well-known port
# serversocket.bind((socket.gethostname(), 4000))
serversocket.bind(('localhost', 4000))
# become a server socket
serversocket.listen(5)

while not done:
    print('Waiting for connection.')
    # accept connections from outside
    (clientsocket, address) = serversocket.accept()

    print(clientsocket)
    
    for event in pygame.event.get():
        pass    # Ignore all events before client connected.
    
    try:
        while not done:
            dict = {'ax':0, 'ay':0, 'ax2':0, 'ay2':0, 'az':0, 'bx':0, 'by':0, 'bx2':0, 'by2':0, 'bz':0, 'xy':0, 'xy2':0, 'back':0, 'start':0, 'home':0};

            # Get count of joysticks.
            joystick_count = pygame.joystick.get_count()
            # Throw warning if more than one?

            # Only look at the first joystick.
            joystick = pygame.joystick.Joystick(0)
            joystick.init()

            # try:
            #     dict['id'] = joystick.get_instance_id()
            # except AttributeError:
            #     # get_instance_id() is an SDL2 method
            #     dict['id'] = joystick.get_id()

            # Get the joystick name from the OS.
            name = joystick.get_name()
            dict['name'] = name

            # Guid is a stable indentifier for a joystick. Not important in our case.
            # try:
            #     dict['guid'] = joystick.get_guid()
            # except AttributeError:
            #     # get_guid() is an SDL2 method
            #     dict['guid'] = ''
                
            somethinghappened = False;

            if name[0:4] == "Xbox":
                dict['ax'] =   joystick.get_axis(0);
                dict['ay'] =  -joystick.get_axis(1);
                dict['ax2'] =  joystick.get_axis(3);
                dict['ay2'] = -joystick.get_axis(4);
                dict['az'] =  (joystick.get_axis(5) - joystick.get_axis(2))/2;
                
                for ax in ['ax', 'ay', 'ax2', 'ay2', 'az']:
                    if abs(dict[ax]) > thresh:
                        somethinghappened = True
                    else:
                        dict[ax] = 0

                for event in pygame.event.get():        # User did something.
                    if event.type == pygame.QUIT:       # If user clicked close.
                        done = True                     # Flag that we are done so we exit this loop.
                    elif event.type == pygame.JOYBUTTONDOWN:
                        if event.joy == 0:
                            somethinghappened = True
                            if   event.button == 14:    # +x
                                dict['bx'] += 1
                            elif event.button == 13:    # -x
                                dict['bx'] -= 1
                            elif event.button == 11:    # +y
                                dict['by'] += 1
                            elif event.button == 12:    # -y
                                dict['by'] -= 1
                            elif event.button == 5:     # +z
                                dict['bz'] += 1
                            elif event.button == 4:     # -z
                                dict['bz'] -= 1
                            elif event.button == 1:     # +x2
                                dict['bx2'] += 1
                            elif event.button == 2:     # -x2
                                dict['bx2'] -= 1
                            elif event.button == 3:     # +y2
                                dict['by2'] += 1
                            elif event.button == 0:     # -y2
                                dict['by2'] -= 1
                            elif event.button == 6:     # press stick 1
                                dict['xy'] = 1
                            elif event.button == 7:     # press stick 2
                                dict['xy2'] = 1
                            elif event.button == 8:     # start
                                dict['start'] = 1
                            elif event.button == 9:     # back
                                dict['back'] = 1
                            elif event.button == 10:     # home
                                dict['home'] = 1
            
            if debug:
                print('Interpretation')
                for key in dict.keys():
                    print("  Axis {} value: {:>6.3f}".format(key, dict[key]))
            

                print("Number of joysticks: {}".format(joystick_count))
            
                # Usually axis run in pairs, up/down for one, and left/right for
                # the other.
                axes = joystick.get_numaxes()
                print("Number of axes: {}".format(axes))

                for i in range(axes):
                    axis = joystick.get_axis(i)
                    print("  Axis {} value: {:>6.3f}".format(i, axis))

                buttons = joystick.get_numbuttons()
                print("Number of buttons: {}".format(buttons))

                for i in range(buttons):
                    button = joystick.get_button(i)
                    print("  Button {:>2} value: {}".format(i, button))

                hats = joystick.get_numhats()
                print("Number of hats: {}".format(hats))
                textPrint.indent()

                # Hat position. All or nothing for direction, not a float like
                # get_axis(). Position is a tuple of int values (x, y).
                for i in range(hats):
                    hat = joystick.get_hat(i)
                    print("Hat {} value: {}".format(i, str(hat)))
            
            if somethinghappened:
                clientsocket.send((str(dict).replace('\'', '"') + '\n').encode('utf-8'))
        
        
            # Limit to 20 frames per second.
            clock.tick(10)
    except:
        pass
    
    try:
        clientsocket.send('FIN\n'.encode('utf-8'))
        clientsocket.shutdown(1)
    except:
        pass

# If you forget this line, the program will 'hang' on exit if running from IDLE.
pygame.quit()
