function alignment_analysis
    d = load(['/Volumes/qpgroup/Experiments/Ian/Lincoln/2021_06_09 0.UL.Wave/Initial/3_1.mat']);
    
    figure
    
    names = {"LX", "LY", "RX", "RY"};
    
    for ii = 1:4
        dat = d.tosave.(['opt' num2str(ii-1)]).m1_pfi10.dat;
        
        subplot(2,2,ii)
        plot(linspace(0,75,501),dat, 'r')
        xlabel('Piezo Voltage [V]')
        ylabel('Transmission [cts/sec]')
        title(names(ii));
    end
end