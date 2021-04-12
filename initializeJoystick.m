function t = initializeJoystick()
    t = tcpclient('localhost', 4000);
    
    configureCallback(t, "terminator", @callbackFcn)
    
    function callbackFcn(src, ~)
        str = src.readline();
        
        if strcmp(str, "FIN")
            src.flush();
            clear src;
            disp('Closed connection.')
        else
            jsondecode(str)
        end
    end
end