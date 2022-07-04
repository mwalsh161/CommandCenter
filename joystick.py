import pygame, socket
import numpy as np
import sys

pygame.init()

# Loop until the user clicks the close button.
done = False
debug = False
# thresh = 3.1e-05
thresh = .1

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
serversocket.bind(('localhost', 4001))
# become a server socket
serversocket.listen(5)

while not done:
    print('Waiting for connection.')
    print(serversocket)
    # accept connections from outside
    (clientsocket, address) = serversocket.accept()

    print(clientsocket)

    done2 = False

    joystick_count = pygame.joystick.get_count()

    if joystick_count == 0:
        print('No joystick found!')
        clientsocket.send(('No Joystick\n').encode('utf-8'))
        clientsocket.shutdown(1)
    else:
        joystick = pygame.joystick.Joystick(0)
        joystick.init()
        name = joystick.get_name()
        clientsocket.send((name + '\n').encode('utf-8'))

        print(clientsocket)

        for event in pygame.event.get():
            pass    # Ignore all events before client connected.

        # try:
        while not done2:
            dict = {'ax':0, 'ay':0, 'ax2':0, 'ay2':0, 'az':0, 'bx':0, 'by':0, 'bx2':0, 'by2':0, 'bz':0, 'xy':0, 'xy2':0, 'left':0, 'right':0};

            # Get count of joysticks.
            joystick_count = pygame.joystick.get_count()
            # Throw warning if more than one?

            # Only look at the first joystick.
            joystick = pygame.joystick.Joystick(0)
            joystick.init()

            if "Xbox" in name:
                def axisFunction(x):
                    if np.abs(x) - thresh < 0:
                        return 0
                    else:
                        return np.sign(x) * (np.abs(x)-thresh)*(np.abs(x)-thresh) / (1-thresh) / (1-thresh)

                if sys.platform == 'win32':
                    dict['ax'] =   axisFunction(joystick.get_axis(0));
                    dict['ay'] =  -axisFunction(joystick.get_axis(1));
                    dict['ax2'] =  axisFunction(joystick.get_axis(2));
                    dict['ay2'] = -axisFunction(joystick.get_axis(3));
                    dict['az'] =  (axisFunction(joystick.get_axis(5)) - axisFunction(joystick.get_axis(4)))/2;

                    (dict['bx'],dict['by']) = joystick.get_hat(0)

                    for event in pygame.event.get():        # User did something.
                        if event.type == pygame.QUIT:       # If user clicked close.
                            done2 = True                    # Flag that we are done so we exit this loop.
                        elif event.type == pygame.JOYBUTTONDOWN:
                            if event.joy == 0:
                                if event.button == 5:     # +z
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
                                elif event.button == 8:     # press stick 1
                                    dict['xy'] = 1
                                elif event.button == 9:     # press stick 2
                                    dict['xy2'] = 1
                                elif event.button == 6:     # start
                                    dict['left'] = 1
                                elif event.button == 7:     # back
                                    dict['right'] = 1
                elif sys.platform == 'darwin':
                    dict['ax'] =   axisFunction(joystick.get_axis(0));
                    dict['ay'] =  -axisFunction(joystick.get_axis(1));
                    dict['ax2'] =  axisFunction(joystick.get_axis(3));
                    dict['ay2'] = -axisFunction(joystick.get_axis(4));
                    dict['az'] =  (axisFunction(joystick.get_axis(5)) - axisFunction(joystick.get_axis(2)))/2;

                    for event in pygame.event.get():        # User did something.
                        if event.type == pygame.QUIT:       # If user clicked close.
                            done2 = True                    # Flag that we are done so we exit this loop.
                        elif event.type == pygame.JOYBUTTONDOWN:
                            if event.joy == 0:
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
                                    dict['right'] = 1
                                elif event.button == 9:     # back
                                    dict['left'] = 1
                else:
                    raise Exception('Mapping not created for platform ' + str(sys.platform))

            elif "T.A320 Copilot" in name:
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:       # If user clicked close.
                        done2 = True                    # Flag that we are done so we exit this loop.
                    elif event.type == pygame.JOYHATMOTION:
                        hat = joystick.get_hat(0)
                        if hat[0] != 0:
                            dict['bx'] = hat[0]
                        if hat[1] != 0:
                            dict['by'] = hat[1]
                dict['ax'] = joystick.get_axis(0)
                dict['ay'] = -joystick.get_axis(1)
                dict['az'] = joystick.get_axis(2)

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

            # if somethinghappened:
            dict_small = {key:val for key, val in dict.items() if val != 0}
            if len(dict_small) > 0:
                clientsocket.send((str(dict_small).replace('\'', '"') + '\n').encode('utf-8'))

            # Limit to 10 frames per second.
            clock.tick(10)
        # except:
        #     pass

    try:
        clientsocket.send('FIN\n'.encode('utf-8'))
        clientsocket.shutdown(1)
    except:
        pass

# If you forget this line, the program will 'hang' on exit if running from IDLE.
pygame.quit()
