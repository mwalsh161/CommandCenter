function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    % Edit here down (save data to obj.data)
    % Tips:
    % - If using a loop, it is good practice to call:
    %     drawnow; assert(~obj.abort_request,'User aborted.');
    %     as frequently as possible
    % - try/catch/end statements useful for cleaning up
    % - You can get a figure-like object (to create subplots) by:
    %     panel = ax.Parent; delete(ax);
    %     ax(1) = subplot(1,2,1,'parent',panel);
    % - drawnow can be used to update status box message and any plots

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);

    try
       
%sigGen = Drivers.SignalGenerators.Hewlett_Packard.instance('ni-gpib','ni',0,4);

sigGen = obj.SignalGenerator;

freqList = linspace(obj.freqStart,obj.freqEnd,obj.numFreqPoints);
obj.data = [];
obj.data.freqList = freqList;
maxFreq = 5e4;
%configure analog inputs
DAQ = Drivers.NIDAQ.dev.instance('Dev1');
DAQ.ClearAllTasks;
obj.data.IVals = nan(size(freqList));
obj.data.QVals = nan(size(freqList));
obj.data.IDevs = nan(size(freqList));
obj.data.QDevs = nan(size(freqList));

MWpower = -5;
sigGen.off();
%sigGen.setFreqMode('CW');

% sigGen.setPowerList(MWpower*ones(size(freqList)));
% sigGen.setFreqList(freqList);
% sigGen.setListTrig('SING');
% sigGen.ListLearn();
% pause(3);

% sigGen.setFreqMode('LIST');


sigGen.power = MWpower;
sigGen.on();

% for i = 1:length(freqList)
%     sigGen.frequency = freqList(i);
%     pause(0.3); 
%     
% end


for i = 1:length(freqList)
    sigGen.frequency = freqList(i);
    pause(0.1);
    % sigGen.sendSoftwareTrigger;
    
    clockTask = DAQ.CreateTask('Clock');
    clockTask.ConfigurePulseTrainOut(obj.clockLine,maxFreq,obj.nsamples);
    
    voltageMeasurementTask = DAQ.CreateTask('Voltage Measurement');
    voltageMeasurementTask.ConfigureVoltageIn({obj.voltageLine_I,obj.voltageLine_Q},clockTask,obj.nsamples,[-10,10]);
    % voltageMeasurementTask.ConfigureVoltageIn({obj.voltageLine_I,obj.voltageLine_Q},clockTask,obj.nsamples,[-1,1]);
    
    
    voltageMeasurementTask.Start;
    clockTask.Start;
    
    
    while ~clockTask.IsTaskDone
        pause(0.1)
    end
    
    obj.data.voltageValues(:,:,i) = voltageMeasurementTask.ReadVoltageIn(obj.nsamples);
    %obj.data.alldata(:,:,i)
    
    % figure(1)
    % clf
    %plot(obj.data.voltageValues(:,2,i));
    %plot(obj.data.voltageValues(:,1,i));
    obj.data.IVals(i) = mean(obj.data.voltageValues(:,2,i));
    obj.data.QVals(i) = mean(obj.data.voltageValues(:,1,i));
    obj.data.IDevs(i) = std(obj.data.voltageValues(:,2,i),0,1)/sqrt(obj.nsamples);
    obj.data.QDevs(i) = std(obj.data.voltageValues(:,1,i),0,1)/sqrt(obj.nsamples);
    
%     obj.data.alldata(:,:,i) = obj.data.voltageValues;
    
    cla(ax,'reset')
    errorbar(freqList,obj.data.IVals,obj.data.IDevs,'Parent', ax);
    hold(ax,'on');
    %errorbar(freqList,obj.data.QVals,obj.data.QDevs,'Parent', ax);
    drawnow; assert(~obj.abort_request,'User aborted.')
    % voltageMeasurementTask.Abort;
    % clockTask.Abort;
    clockTask.Clear;
    voltageMeasurementTask.Clear;
end

sigGen.off();

    catch err
    end
    % CLEAN UP CODE %
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
