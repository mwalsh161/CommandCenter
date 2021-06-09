function etalon_setpoint_analysis(data)
    apd = data.m5_pfi10.dat(:, 1:2:end) - 1600*.2;
    power = data.m6_power.dat(:, 1:2:end)
    au = apd ./ power;
%     apd2 = data.m3_pfi10.dat(:);
%     power2 = data.m4_power.dat(:)
%     au2 = apd2 ./ power2;
    wavelength = data.m1_VIS_wavelength.dat(:, 1:2:end);
    mask = wavelength > 0;
    figure
    scatter(wavelength(mask), au(mask))
%     hold on
%     scatter(wavelength(mask), au2(mask));
end