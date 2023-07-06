function cwavetest(cwave)
    figure;
    t = [NaN]; 
    f = [NaN];
    r = [NaN];
    o = [NaN];
    
    hold on
    p = plot(t, f);
    yyaxis right
    p2 = plot(t, r);
    p3 = plot(t, r);
    
    
    tic
    
    cwave.com('set_piezo_mode', 'opo', 4);
    
%     cwave.stop_opo_extramp()
%     pause(.25)
%     cwave.set_opo_extramp_settings(60, 40, 60)
%     pause(.25)
%     cwave.start_opo_extramp()

    m = 40;
    M = 60;
    dp = .02;
    
    for percent = [50:-dp:m m:dp:M M:-dp:50]
%         cwave.set_resonator_percent(percent)
        cwave.set_opo_percent(percent)
%         cwave.TunePercent(percent)
        
        pause(.1)
        
        t = [t toc];
        f = [f cwave.getFrequency()];
        r = [r cwave.get_resonator_percent()];
        o = [o cwave.get_opo_percent()];
        
        f(f < 0) = NaN;
        
        p.XData = t;
        p.YData = f;
        p2.XData = t;
        p2.YData = r;
        p3.XData = t;
        p3.YData = o;
        
        drawnow
    end

end