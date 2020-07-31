function PVCAMpulsetrainTest()
    M = 4;
    N = 10;
    
    dev = Drivers.NIDAQ.dev.instance('Dev1');
    dev.ClearAllTasks();
    
    task = dev.CreateTask('PVCAMpulsetrainTest');
%     task.ConfigureDigitalEdgeAdvancedTrigger('pvcam exposing', 'falling')
    
    V = linspace(0,.1,N);
    V = [V, V(end:-1:1)];
    V = repmat(V, [1, M]);
    size(V);
    V = V';
%     task.ConfigureVoltageOut('laser', V)
    task.ConfigureVoltageOutExtTiming('laser', V, 'pvcam exposing pfi', 'falling')
    
    task.Start
    
    cam = Imaging.PVCAM.instance;
    cam.frames = length(V) + 1;
    cam.exposure = 20;
    
    % Activate.
    d = cam.snapImage;
end