function ms = eg347setup
    ni =    Drivers.NIDAQ.dev.instance('dev1');
%     stage = Stages.MAX302motors.instance();
    ms =    Drivers.metastage.instance();
    
%     ms.coarse_x = stage.motors{1}.get_meta_pref('Position');
%     ms.coarse_y = stage.motors{2}.get_meta_pref('Position');
%     ms.coarse_z = stage.motors{3}.get_meta_pref('Position');
    
    mx = Drivers.APTMotor.instance(90878996, [-2 14]);
    my = Drivers.APTMotor.instance(90878998, [-2 14]);
    mz = Drivers.APTMotor.instance(90878997, [-2 14]);
    
    ms.coarse_x = mx.get_meta_pref('Position');
    ms.coarse_y = my.get_meta_pref('Position');
    ms.coarse_z = mz.get_meta_pref('Position');
    
    ms.fine_x = ni.OutLines(4).pref;
    ms.fine_y = ni.OutLines(5).pref;
    ms.fine_z = ni.OutLines(6).pref;
    
    ard =   Drivers.ArduinoServo.instance('localhost', 3);
    img =   Imaging.MicroManagerVideomode.instance();
    qr =    Imaging.QR.instance();
    red =   Sources.WhiteLight.instance();
    green = Sources.Laser532_nidaq_PB.instance();
    
    ms.image = qr;
    
    red.on();
    green.off();
    img.exposure = 100;
    
%     ms.calibrate();
end