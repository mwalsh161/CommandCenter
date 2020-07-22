function testPB
    s = sequence('Test');
    
    colors = 'rgbk';
    
    N = 4;
    
    for ii = 1:N
        c(ii) = channel(num2str(ii), 'color', colors(ii), 'hardware', ii-1);
    end
    
    s.channelOrder = c;
    
    g = s.StartNode;
    
    tau_us = 2*1e6;
    
    for ii = 1:N
        g = node(g, c(ii), 'units', 'us', 'delta', tau_us*(ii==1));
    end
    
    for ii = 1:N
        g = node(g, c(ii), 'units', 'us', 'delta', tau_us*(ii==1));
    end
    
    s.repeat = Inf;
    
    s.draw();
    
    s
    
    [program,s] = s.compile()
    
    pb = Drivers.PulseBlaster.Remote.instance('localhost');
    
    pb.open;
    pb.load(program);
    pb.start;
end