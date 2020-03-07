function data = GetData(obj,~,~)
if ~isempty(obj.data)
    data.APDcounts = obj.data;
    data.RF.handle = obj.RF;
    data.RF.amp = obj.RF_power;
    data.RF.freq =obj.CW_freq;
    data.averages = obj.nAverages;
    data.PB.laser_on_time = obj.laser_read_time;
    data.sequence = obj.sequence;
    data.Integration_time = obj.Integration_time;
    data.reInitializationTime = obj.reInitializationTime;
    data.padding = obj.padding;
else
    data = [];
end
end