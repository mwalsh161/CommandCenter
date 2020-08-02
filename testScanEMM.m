function testScanEMM()
    E = Sources.msquared.EMM.instance;
    E.wa
    
    X = 0:5:100;
    wl = NaN*X;
    
    figure
    p = plot(X, wl);
    
    for ii = 1:length(X)
        E.etalon_percent = X(ii);
        pause(.3)
        wl(ii) = E.getFrequency;
        
        p.YData = wl;
        drawnow
    end
end