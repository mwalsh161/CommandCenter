function [t, hello] = initializeJoystick()
    [t, hello] = connectSmart('localhost');
    
    function callbackFcn(t, ~)
        str = t.readline();
        
        if strcmp(str, "FIN")
            t.flush();
            clear t;
            disp('Closed connection.')
        else
            jsondecode(str)
        end
    end
    function [t, hello] = connectSmart(host)
        disp('Trying to connect')
        [t, hello] = connect(host);
        
        if strcmp(hello, 'No Server') && strcmp(host, 'localhost')
            disp('Starting server')
            system('python startjoystick.py');
            
            [t, hello] = connect(host);
        end
    end
    function [t, hello] = connect(host)
        try
            t = tcpclient(host, 4000, "ConnectTimeout", 1, "Timeout", 1);

            hello = t.readline();

            if isempty(hello) || strcmp(hello, 'No Joystick')
                t.flush();
                clear t;
                t = [];
                
                if isempty(hello)
                    hello = 'No Server';
                end
            else
                configureCallback(t, "terminator", @callbackFcn)
            end
        catch
            t = [];
            hello = 'No Server';
        end
    end
end