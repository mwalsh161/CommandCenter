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
    pause(5);% let SG warm up
    %% grab DAQ
    
    obj.Ni = Drivers.NIDAQ.dev.instance(obj.deviceName);

    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    obj.data.norm_data = obj.data.raw_data;
    freq_list(2:2:end) = [];
    
    for cur_nAverage = 1:obj.nAverages
        for freq = 1:obj.number_points
            
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            obj.RF.MWFrequency = freq_list(freq);
            
            pause(obj.waitSGSwitch)
            
            obj.data.raw_data(freq,cur_nAverage) = abs(obj.Ni.ReadAILine(obj.channelName,[obj.MinVoltage,obj.MaxVoltage]));%Get voltage from DAQ channel
            
%             obj.RF.MWFrequency = freq_list(freq +1);
%             
%             pause(obj.waitSGSwitch)
%             
%              obj.data.norm_data(freq,cur_nAverage) = abs(obj.Ni.ReadAILine(obj.channelName,[obj.MinVoltage,obj.MaxVoltage]));%Get voltage from DAQ channel

            obj.data.norm_data(freq,cur_nAverage) = 1;
            obj.data.dataVector = nanmean(obj.data.raw_data./obj.data.norm_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data./obj.data.norm_data,0,2)./sqrt(cur_nAverage);
            
            errorbar(freq_list./1e9,obj.data.dataVector,obj.data.dataVectorError,'r*--','parent',ax)
            ylabel(ax,'Voltage (V)')
            legend(ax,'Data')
            xlim(ax,[obj.start_freq,obj.stop_freq]/1e9);
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