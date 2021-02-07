function ms = eg308setup
    ni =    Drivers.NIDAQ.dev.instance('dev1');
    stage = Stages.MAX302motors.instance();
    ms =    Drivers.metastage.instance();
    
    ms.coarse_x = stage.motors{1}.get_meta_pref('Position');
    ms.coarse_y = stage.motors{2}.get_meta_pref('Position');
    ms.coarse_z = stage.motors{3}.get_meta_pref('Position');
    
    ms.fine_x = ni.OutLines(6).pref;
    ms.fine_y = ni.OutLines(5).pref;
    ms.fine_z = ni.OutLines(7).pref;
    
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