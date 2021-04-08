function PLEvsVoltage(managers)
    keithley = Keithley2400(16);
    keithley.setOutputMode('VOLT');
    
    startVolt = 0;
    stepVolt = 5;
    stopVolt;
    
    volt = startVolt:stepVolt:stopVolt;
    amp = NaN(1,length(volt));

    keithley = Keithley2400(16);
    keithley.setOutputMode('VOLT');
    
    f = figure;
    ax = axes;

    d = dialog('Position',[300 300 250 150],'Name','Running','WindowStyle','normal');

    uicontrol('Parent',d,...
               'Style','text',...
               'Position',[20 80 210 40],...
               'String','Abort?');
    uicontrol('Parent',d,...
               'Position',[85 20 70 25],...
               'String','Yes',...
               'Callback',@(hObj,~)abort(ax,hObj));
    aborted = false;
    
    e = Experiments.SlowScan.Open.instance();

    for i = 1:length(volt)
        if ax.Parent.UserData
            delete(keithley)
            delete(d)
            aborted = true;
            return
        end
        
%         managers.Experiment.run();
        % Run the experiment.
        e.run();
        
        % Pull the data from the experiment.
        x = e.GetData.data.freqs_measured;
        y = e.GetData.data.sumCounts;
        
        % Find the freqeuncy of the maximum value.
        newTarget = x(first(y == nanmax(y)));
        
        
        keithley.setOutputVoltage(volt(i))
        amp(i) = keithley.measureCurrent();

        plot(ax,volt(1:i),amp(1:i),'.-','linewidth',1);
        xlabel(ax,'V_{sd} (V)','FontSize',12)%, 'Interpreter', 'LaTex');
        ylabel(ax,'I_{sd} (A)','FontSize',12);
        set(ax,'FontSize',12);
        %xlim([min(gateVolt) max(gateVolt)]);

        pause(dwellTime);
    end
    delete(keithley)
    delete(d)
    end

    function abort(ax,hObj)
        ax.Parent.UserData = true;
        set(hObj,'enable','off')
    end
end