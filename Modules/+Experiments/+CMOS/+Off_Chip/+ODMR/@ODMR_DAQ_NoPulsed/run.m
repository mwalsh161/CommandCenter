function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
    
    
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    %turn on all control channels
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    freq_list = obj.determine_freq_list;
    obj.RF.MWFrequency = freq_list(1);
    pause(5);
    
    %% grab DAQ
    obj.Ni = Drivers.NIDAQ.dev.instance(obj.deviceName);
    
%%
clc
ni.ClearAllTasks;
t = ni.CreateTask('pulse');
t.ConfigurePulseTrainOut(clk,f,Nsamples);
AI = ni.CreateTask('Analog In');
AI.ConfigureVoltageIn(analog_in,t,Nsamples);
DI = ni.CreateTask('Digital In');
DI.ConfigureDigitalIn(digital_in,t,Nsamples);
%%
AI.Start;
DI.Start;
tic;
t.Start;
AI.WaitUntilTaskDone;
dt = toc;
fprintf('Should have taken %0.2f seconds, took %0.2f s.\n',Nsamples/f,dt);
d = DI.ReadDigitalIn(Nsamples);
a = AI.ReadVoltageIn(Nsamples);
figure;
yyaxis('left');
plot((0:Nsamples-1)/f,d);
ylabel('Digital signal (b)')
yyaxis('right');
plot((0:Nsamples-1)/f,a);
ylabel('Analog signal (V)')
xlabel('Time (s)');

t.Clear;
DI.Clear;
AI.Clear;
%%
delete(ni);
    
    
    
    
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    
    for cur_nAverage = 1:obj.nAverages
        for freq = 1:obj.number_points
            
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            obj.RF.MWFrequency = freq_list(freq);
            
            pause(obj.waitSGSwitch)
            
            obj.data.raw_data(freq,cur_nAverage) = obj.Ni.ReadAILine(obj.channelName);%Get voltage from DAQ channel
            
            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
            
            errorbar(freq_list,obj.data.dataVector,obj.data.dataVectorError,'r*--','parent',ax)
            ylabel(ax,'Voltage (V)')
            
            legend(ax,'Data')
            xlim(ax,freq_list([1,end]));
            xlabel(ax,'Microwave Frequency (GHz)')
            title(ax,sprintf('Performing Average %i of %i and frequency %i of %i',cur_nAverage,obj.nAverages,freq,obj.number_points))
            
            
        end
        
    end
    
catch message
end
%% cleanup
%%
if ~isempty(message)
    rethrow(message)
end
end