
function [Drain_Power_Supply,Gate_Power_Supply,Multimeter] = determine_correct_options(obj)
%this function determines the correct options for the available
%multimeters, and gate and drain power supplies. It modifies the options
%and then these are displayed to the user.

availableGatePS=[];
availableDrainPS=[];
availableMultimeters=[];

power_supply_path='Modules\+Drivers\+PowerSupplies';
multimeters_path='Modules\+Drivers\+Multimeter';

Available_power_supplies = obj.determine_all_class(power_supply_path);
Available_multimeters = obj.determine_all_class(multimeters_path);

for index = 1:length(Available_multimeters)
    Number_of_channels = eval([Available_multimeters{index},'.Number_of_channels']);
    Number_of_channels = str2num(Number_of_channels);
    
    for index2 = 1:Number_of_channels
        option_name = [Available_multimeters{index},'_Channel_',num2str(index2)];
        availableMultimeters = [availableMultimeters,{option_name}];
    end
end

for index = 1:length(Available_power_supplies)
    Dual_Polarity = eval([Available_power_supplies{index},'.Dual_Polarity']);
    
    Number_of_channels=eval([Available_power_supplies{index},'.Number_of_channels']);
    Number_of_channels=str2num(Number_of_channels);
    
    for index2=1:Number_of_channels
        option_name = [Available_power_supplies{index},'_Channel_',num2str(index2)];
        if strcmp(Dual_Polarity,'Yes')
            availableGatePS=[availableGatePS,{option_name}];
        end
        availableDrainPS=[availableDrainPS,{option_name}];
    end
end

Drain_Power_Supply = availableDrainPS;
Gate_Power_Supply = availableGatePS;
Multimeter = availableMultimeters;

end