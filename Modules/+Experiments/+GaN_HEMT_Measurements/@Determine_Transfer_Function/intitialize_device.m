function handle = intitialize_device(obj,device_name,managers)
%grab handle to the source object. If device name is not a source grab handle
%to the driver.

handle=[];

%% check if a source
modules = managers.Sources.modules;
module_handles=obj.find_active_module(modules,device_name);
for index=1:length(module_handles)
    module_name=class(module_handles{index});
    strings=strsplit(module_name,'_');
    strings=strsplit(strings{1},'.');
    if strcmp(strings{end},device_name)
        handle=module_handles{index};
    end
end
%% since handle is empty check if under multimeters
if isempty(handle)
    [~,~,Available_multimeters]=obj.determine_correct_options;
    for index = 1:numel(Available_multimeters)
        multimeter = Available_multimeters{index};
        if ~contains(multimeter,device_name)
            continue  %if device name does not match multimeter then skip to next loop iteration
        end  
        startingIndex = strfind(multimeter,'_Channel');
        handle = eval([multimeter(1:startingIndex-1),'.instance(multimeter)']);
        if ~isempty(handle)
            return  %if a valid handle is found then exit function
        end
    end
end
%% since no device found error

assert(~isempty(handle),['no source or multimeter was found with name: ',device_name])
end
