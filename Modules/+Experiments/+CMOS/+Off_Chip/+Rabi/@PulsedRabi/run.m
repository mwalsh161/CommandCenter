function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    message = [];
    obj.data = [];
  
    %% get laser
    assert(~obj.abort_request,'User aborted');
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
 
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    
    %% setup SG
    assert(~obj.abort_request,'User aborted');
    obj.RF = obj.find_active_module(modules,'CMOS_SG');
    obj.RF.MWFrequency = obj.CW_freq;
    obj.RF.SGref.on; %turn on SG but not the switch
    pause(5);
  
    %% start sequence
    time_list = obj.determine_time_list;
   [s,program] = obj.updatePulseSequence(time_list(1));
   
    %% run ODMR experiment
    
    obj.data.raw_data = NaN(obj.number_points,obj.nAverages);
    
    for cur_nAverage = 1:obj.nAverages
       
        for timeIndex = 1:obj.number_points
            
            assert(~obj.abort_request,'User aborted');
            
            obj.pulseblaster.stop;
            obj.updatePulseSequence(time_list(timeIndex));
            obj.pulseblaster.start;
            pause(obj.waitTime)
            
            obj.data.raw_data(freq,cur_nAverage) = obj.Ni.ReadAILine(obj.channelName);%Get voltage from DAQ channel

            obj.data.dataVector = nanmean(obj.data.raw_data,2);
            obj.data.dataVectorError = nanstd(obj.data.raw_data,0,2)./sqrt(cur_nAverage);
           
            plot(time_list,obj.data.dataVector,'r*--','parent',ax)
            hold(ax,'on')
            plot(time_list(timeIndex),obj.data.dataVector(timeIndex),'b*','MarkerSize',10,'parent',ax)
            hold(ax,'off')
            switch obj.Mode
                case 'voltage'
                    ylabel(ax,'Voltage (V)')
                case 'current'
                    ylabel(ax,'Current (A)')
                otherwise
                    error('Unknown Mode')
            end
            legend(ax,'Data')
            xlim(ax,time_list([1,end]));
            xlabel(ax,'Time (ns)')
            title(ax,sprintf('Performing Average %i of %i',cur_nAverage,obj.nAverages))
            
        end
    end
    
catch message
end
%% cleanup
obj.pulseblaster.stop;
obj.laser.off;
delete(obj.listeners);
%%
if ~isempty(message)
    rethrow(message)
end
end