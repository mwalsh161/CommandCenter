function etalon_setpoint_analysis()
    II = 3;
    JJ = 1;

    for ii = II
        for jj = JJ
%             try
                fname = [num2str(ii) '_' num2str(jj)];
                d = load(['/Volumes/qpgroup/Experiments/Ian/Lincoln/2021_06_09 0.UL.Wave/Initial/' fname '.mat']);

                f = figure('Name', fname);
                f.Position(4) = f.Position(3)/3;
                f.Position(1) = f.Position(1) - f.Position(3)/2;
                f.Position(3) = f.Position(3)*2;

                a = axes;

                hold on
                etalon_setpoint_analysis_single(d.tosave.m1)
                etalon_setpoint_analysis_single(d.tosave.m2)
                etalon_setpoint_analysis_single(d.tosave.m3)
                legend('off')
                xlim([600, 650])
                xlabel('Wavelength [nm]')
                ylabel('Normalized Transmission [a.u.]')
%             end
            
%             set(a, 'yscale','log')
        end
    end

    function etalon_setpoint_analysis_single(data)
        apd = (data.m5_pfi10.dat(:) - 1600*.2)/1e7;
        power = data.m6_power.dat(:);
        au = apd ./ power;
    %     apd2 = data.m3_pfi10.dat(:);
    %     power2 = data.m4_power.dat(:)
    %     au2 = apd2 ./ power2;
        wavelength = data.m1_VIS_wavelength.dat(:);
        mask = (wavelength > 0) & ~isnan(wavelength);
        wl = round(mean(wavelength(mask)));
        color = ppPlotTools.getColor(wl/1e3);
        sz = ones(1, sum(mask));
        
        xlim([min(wavelength(mask)), max(wavelength(mask))])
        
        fo = fit(wavelength(mask), au(mask), fittype('a*(1 + sin(2*pi*b*x + c))/2 + d'), 'StartPoint', [4, 1, 0, 0], 'Lower', [0, .5, -Inf, 0], 'Upper', [20, 1.5, Inf, 5]);
        plot(fo, 'k');
        dat = coeffvalues(fo);
        std = confint(fo,0.67);
        std = diff(std,1);
        
        scatter(wavelength(mask), au(mask), sz, color, '.');
        
        n_g = wl * wl * dat(2) / 200e3;
        extinction = (dat(4)/dat(1));
        spliterror = (extinction/2) ^ .5;
        percent = 50 - 100*spliterror;
        
%         ['R:T=' num2str(percent) ':' num2str(100-percent)],
        text(wl+5, mean(au(mask)), {['\lambda=' num2str(wl)],  ['n_g=' num2str(n_g)]}, 'HorizontalAlignment', 'center', 'color', color)
        
        ylim([0, 5])
        
    %     hold on
    %     scatter(wavelength(mask), au2(mask));
    end
end