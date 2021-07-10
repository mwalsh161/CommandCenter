function loadMAXprefs
%     s = Stages.MAX302motors.instance;
    m1 = Drivers.APTMotor.instance(90878996, [0 10]);
    m2 = Drivers.APTMotor.instance(90878998, [0 10]);
    m3 = Drivers.APTMotor.instance(90878997, [0 10]);
    
    m1.home();
    m2.home();
    m3.home();
end