function run(obj,statusH,managers,ax)
obj.abort_request = false;   % Reset abort flag
stage = managers.Stages;
imager = managers.Imaging;
obj.data.images = struct('image',{},...
                      'stagePos',{},'stage',{},...
                      'ROI',{},'ModuleInfo',{});
Origin = stage.position;
stage.update_gui = 'off';
roi = imager.ROI;
[X,Y] = meshgrid(linspace(0,0.9*diff(roi(1,:)),obj.xNum),linspace(0,0.9*diff(roi(2,:)),obj.yNum));
for i = 1:floor(size(Y,1)/2)
    Y(:,i*2) = flipud(Y(:,i*2));
end
X = X(:);
Y = Y(:);
for ind = 1:length(X)
    if obj.abort_request
        return
    end
    nextPos = Origin(1:2) - [X(ind) Y(ind)];
    stage.move([nextPos Origin(3)]);
    stage.waitUntilStopped;
    im = imager.snap;
    obj.data.images(end+1) = im;
end
stage.update_gui = 'on';
end
