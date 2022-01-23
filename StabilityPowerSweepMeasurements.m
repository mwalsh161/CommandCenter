% Loading relevant hardware
hwp = Drivers.APTMotor.instance(27002771, [0, 360]);
apd1 = Drivers.Counter.instance('APD1', 'CounterSync');
ard = Drivers.ArduinoServo.instance('localhost', 2);
pm = Drivers.PM100.instance();

hwp.home;
while hwp.Moving
    pause(0.1)
end
%%
% Calibrate the laser power
Blue_sweep = linspace(0, 180, 180); % filter wheel angle
Green_sweep = linspace(1, 30, 60); % mW (OD 2)
Res_hwp_sweep = linspace(0, 360, 360); % half wave plate angle

blue_power = NaN(1, length(Blue_sweep));
green_power = NaN(1, length(Green_sweep));
res_power = NaN(1, length(Res_hwp_sweep));
%% Blue
ard.angle = 0;
pm.set_wavelength(450);
b = 1;
for Blue = Blue_sweep
    ard.angle = Blue;
    blue_power(b) = pm.get_power('MW')*1000; % uW
    pause(0.1);
    b = b + 1;
end
figure()
plot(Blue_sweep, blue_power)
xlabel('Filter Wheel Angle / deg')
ylabel('Blue Laser Power / uW')
%% Green
pm.set_wavelength(515);
laser = Sources.Cobolt_PB.instance();
%laser.set_armed(true);
%laser.on;
g = 1;
for Green = Green_sweep 
    laser.set_power(Green);
    pause(0.1)
    green_power(g) = pm.get_power('MW')*1000;
    g = g + 1;
end
figure()
plot(Green_sweep, green_power)
xlabel('Power at Laser Source / mW')
ylabel('Green Laser Power / uW')
%% Resonant
pm.set_wavelength(619);
r = 1;
res_laser = Sources.Msquared.instance();
%%
for Res = Res_hwp_sweep
    hwp.move(Res);
    while hwp.Moving
        pause(0.1)
    end
    res_power(r) = pm.get_power('MW')*1000;
    r = r + 1;
end
figure()
plot(Res_hwp_sweep, res_power)
xlabel('Half Waveplate Angle / deg')
ylabel('Resonant Laser Power / uW')
%% Power Sweep
% Setting sweep variables
Blue_sweep = linspace(10, 50, 5); % filter wheel angle
Green_sweep = linspace(5, 15, 5); % mW
Res_hwp_sweep = linspace(86, 136, 5); % half wave plate angle
%%
% Setting Counter
apd1.dwell = 0.01;
apd1.update_rate = 0.001;
apd1.WindowMax = 10;
%% Blue Laser Power Sweep
r = 1;
for Res_hwp = Res_hwp_sweep
    hwp.move(Res_hwp);
    while hwp.Moving
        pause(0.1)
    end
    b = 1;
    for Blue = Blue_sweep
        ard.angle = Blue;
        pause(50)
        Counts_blue(b, r).yData = double(apd1.singleShot(apd1.dwell, 5000000));
        figure()
        histogram(Counts_blue(b, r).yData*apd1.dwell*1e-3, 'Binwidth', 1)
        b = b + 1;
    end
    r = r + 1;
end
%% Green laser power sweep
laser = Sources.Cobolt_PB.instance();
r = 1;
for Res_hwp = Res_hwp_sweep
    hwp.move(Res_hwp);
    while hwp.Moving
        pause(0.1)
    end
    g = 1;
    for Green = Green_sweep
        laser.set_power(Green);
        pause(50)
        Counts_green(g, r).yData = double(apd1.singleShot(apd1.dwell, 500000));
        figure()
        hist(Counts_green(g, r).yData*apd1.dwell*1e-3)
        g = g + 1;
    end
    r = r + 1;
end
%% Green Fluorescence
g = 1;
for Green = Green_sweep
    laser.set_power(Green);
    pause(50)
    Counts_green_only(g).yData = double(apd1.singleShot(apd1.dwell, 500000));
    figure()
    histogram(Counts_green_only(g).yData*apd1.dwell*1e-3, 'BinWidth', 1)
    g = g + 1;
end
    
%% Resonant excitation only
r = 1;
for Res_hwp = Res_hwp_sweep
    hwp.move(Res_hwp);
    while hwp.Moving
        pause(0.1)
    end
        pause(50)
        Counts_res(r).yData = double(apd1.singleShot(apd1.dwell, 500000));
        figure()
        histogram(Counts_res(r).yData*apd1.dwell*1e-3, 'BinWidth', 1)
        set(gca, 'Yscale', 'log')
        r = r + 1;
end
%% Blue fluorescence
b = 1;
for Blue = Blue_sweep
    ard.angle = Blue;
    pause(50)
    Counts_blue_only(b).yData = double(apd1.singleShot(apd1.dwell, 100000));
    figure()
    histogram(Counts_blue_only(b).yData*apd1.dwell*1e-3, 'BinWidth', 1)
    b = b + 1;
end

%%
apd1.delete;
ard.delete;
hwp.delete;
pm.delete;