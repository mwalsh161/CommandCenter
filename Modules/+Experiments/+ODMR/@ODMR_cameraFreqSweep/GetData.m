function data = GetData(obj,~,~)
data.data = obj.data;
data.laser = obj.laser.prefs2struct;
data.camera = obj.camera.prefs2struct;
data.SG = obj.SG.prefs2struct;
data.experimentParameters = obj.prefs2struct;
end