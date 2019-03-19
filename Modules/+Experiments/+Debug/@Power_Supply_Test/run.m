function run(obj,statusH,managers,axx)

%%
display('Select which power supply driver you would like to test.')
[file,path]=uigetfile('*.m','Select power supply driver','Modules/+Drivers/+PowerSupplies');
%get the class name
period_index=find(file=='.');
class_name=file(1:period_index-1);

%get the prefix
[prefix]=Base.GetClasses(path);
driver=[prefix,class_name];

%get the device id.
power_supply_name = eval(sprintf('%s.dev_id',driver));

%instantiate driver for your powersupply
obj.serial = eval(sprintf('%s.instance(power_supply_name)',driver));
%%

obj.abort_request=false;
obj.logger.visible = 'on'; %open logger to show testing progress.
obj.tests = struct('name',{},'success',{},'return_val',{},'err',{});%initialize structure to store test results
obj.report = {};%initialize cell array for end report
numofchannels=obj.serial.Number_of_channels; %get the number of programmable channels
numofchannels=str2num(numofchannels);

%grab device ID
str = obj.serial.dev_id;
obj.updateLogger(sprintf(['Testing ', str]));
assert(~obj.abort_request,'User aborted');

%Test device handshake

obj.tests(end+1) = obj.run_test('handshake','',isempty(query(obj.serial.comObject,'*IDN?')),false);

try
    for index=1:numofchannels
        channel=num2str(index);
        obj.updateLogger(sprintf(['Testing channel ', channel]));
        
        %Test if device is off after construction
        obj.tests(end+1) = obj.run_test('test if device is off after construction','',@()obj.serial.getState(channel),'Off');
        
        %Test if device is sets a current limit after construction
        obj.tests(end+1) = obj.run_test('test default current limit','',@()obj.serial.getCurrentLimit(channel),obj.current_limit_default);
        
        %Test if device is sets a voltage limit after construction
        obj.tests(end+1) = obj.run_test('test default voltage limit','',@()obj.serial.getVoltageLimit(channel),obj.voltage_limit_default);
        
        %Test current limit setting
        obj.tests(end+1) = obj.run_test('set current limit',@()obj.serial.setCurrentLimit(channel,1),@()obj.serial.getCurrentLimit(channel),1);
        
        if ~(obj.tests(end).success == 1)
            %If the powersupply cannot set the current limit correctly then you
            %should abort because this is a terminal error.Serious damage
            %could occur if you proceed.
            obj.abort()
            assert(~obj.abort_request,[class(obj),' aborted because current limit was not set correctly.']);
        end
        
        %Test turning on the the channel
        obj.tests(end+1) = obj.run_test('turn on',@()obj.serial.on,@()obj.serial.getState(channel),'On');
        
        %Test turning off the channel
        obj.tests(end+1) = obj.run_test('turn off',@()obj.serial.off,@()obj.serial.getState(channel),'Off');
        
        %Test if a voltage is set correctly
        obj.tests(end+1) = obj.run_test('set voltage','',@()obj.measureTest(channel,'voltage',obj.Voltage,obj.Voltage),true);
        
        if strcmp(obj.Resistor,'Yes')
            
            %Test if you cannot exceed your current limit
            obj.tests(end+1) = obj.run_test('current limit','',@()obj.test_current_limit(channel),true);
            
            if ~(obj.tests(end).success == 1)
                %Aborting because if the current exceeds current limit then
                %that is dangerous.
                obj.abort()
                assert(~obj.abort_request,[class(obj),' aborted because current limit was not set correctly.']);
            end
        end
        obj.serial.off
        %%
        
        if strcmpi(obj.serial.Dual_Polarity,'Yes')
            obj.updateLogger(sprintf(['Testing Dual Polarity of channel ', channel]));
           
            obj.serial.setCurrentLimit(channel,1)
            
            %Test setting a negative voltage
            obj.tests(end+1) = obj.run_test('Dual_Polarity voltage setting','',@()obj.measureTest(channel,'voltage',-obj.Voltage,-obj.Voltage),true);
            
            obj.serial.setCurrentLimit(channel,obj.current_limit_default)

            %Test if you can set both current limits correctly:symmetric
            obj.tests(end+1) = obj.run_test('Dual_Polarity current limit setting symmetric','',@()obj.bipolar_limit_setting(channel,'current',obj.Current_Limit,-obj.Current_Limit),true);
            
            %Test if you can set both current limits correctly:asymmetric
            obj.tests(end+1) = obj.run_test('Dual_Polarity current limit setting asymmetric','',@()obj.bipolar_limit_setting(channel,'current',0.04,-0.1),true);
            
            if strcmp(obj.Resistor,'Yes')
                %Test if your sourcing a negative voltage
                obj.tests(end+1) = obj.run_test('Dual_Polarity current limit','',@()obj.test_current_limit(channel),true);
                
                if ~(obj.tests(end).success == 1)
                    %Aborting because if the current exceeds current limit then
                    %that is dangerous.
                    obj.abort()
                    assert(~obj.abort_request,[class(obj),' aborted because current limit was not set correctly.']);
                end
            end
        end
        
        obj.serial.off
        
        %% test current mode functions of the power supply
        obj.updateLogger(sprintf(['Testing current mode of channel ', channel]));
        
        %Test if you can set a voltage limit
        obj.tests(end+1) = obj.run_test('set voltage limit',@() obj.serial.setVoltageLimit(channel,obj.Volt_Limit),@() obj.serial.getVoltageLimit(channel),obj.Volt_Limit);
        
        if ~(obj.tests(end).success == 1)
            %If the powersupply cannot set the voltage limit correctly then you
            %should abort because this is a terminal error.Serious damage
            %could occur if you proceed.
            obj.abort()
            assert(~obj.abort_request,[class(obj),' aborted because voltage limit was not set correctly.']);
        end
        
        if strcmp(obj.Resistor,'Yes')
            obj.serial.setVoltageLimit(channel,10)
            
            %Test if you set a current correctly
            obj.tests(end+1) = obj.run_test('measure set current','',@() obj.measureTest(channel,'current',obj.Current,obj.Current),true);
            
            obj.serial.setVoltageLimit(channel,obj.voltage_limit_default)
            
            obj.serial.off;
            
            %Test if you can set the voltage limit correctly
            obj.tests(end+1) = obj.run_test('test voltage limit','',@()obj.test_voltage_limit(channel),true);
        end
        
        if strcmpi(obj.serial.Dual_Polarity,'Yes')
            
            %Test if you can set both voltage limits correctly:symmetric
            obj.tests(end+1) = obj.run_test('Dual_Polarity voltage limit setting symmetric','',@()obj.bipolar_limit_setting(channel,'voltage',obj.Volt_Limit,-obj.Volt_Limit),true);
            
            %Test if you can set both voltage limits correctly:asymmetric
            obj.tests(end+1) = obj.run_test('Dual_Polarity voltage limit setting asymmetric','',@()obj.bipolar_limit_setting(channel,'voltage',4,-1),true);
            if strcmp(obj.Resistor,'Yes')
                obj.serial.setVoltageLimit(channel,10)
                
                %Test if you can set a negative current
                obj.tests(end+1) = obj.run_test('Dual_Polarity current setting','',@() obj.measureTest(channel,'current',-obj.Current,-obj.Current),true);
                
                obj.serial.setVoltageLimit(channel,obj.voltage_limit_default)
                
                %Test if your negative voltage limit is set correctly
                obj.tests(end+1) = obj.run_test('test negative voltage limit','',@()obj.test_voltage_limit(channel),true);
            end
            
        end
        
        obj.serial.on;
        
%         Test if device can reset
        obj.tests(end+1) = obj.run_test('device reset',@()obj.serial.reset,'','');
        
        %Test if device is off after reset
        obj.tests(end+1) = obj.run_test('test if device is off after reset','',@()obj.serial.getState(channel),'Off');
        
        %Test if device is sets a current limit after reset
        obj.tests(end+1) = obj.run_test('test default current limit after reset','',@()obj.serial.getCurrentLimit(channel),obj.current_limit_default);
        
        %Test if device is sets a voltage limit after reset
        obj.tests(end+1) = obj.run_test('test default voltage limit after reset','',@()obj.serial.getVoltageLimit(channel),obj.voltage_limit_default);
%         
        obj.serial.off
    end
    
    obj.serial.reset;
    obj.serial.delete;
    obj.updateLogger(sprintf([obj.serial.dev_id,' testing complete.']));
   
    %Loop through test results, check for failure
    for i = 1:length(obj.tests)
        if ~obj.tests(i).success
            obj.status = 'fail';
        end
    end
    
catch err
    if ~obj.abort_request
        obj.abort;
    end
    obj.status = 'fail';
    rethrow(err)
end

%If status not set to failure, all tests must have succeeded
if isempty(obj.status)
    obj.status = 'pass';
    obj.logger.log('Passed all performed tests.')
    drawnow;
else
    obj.logger.log('Failed at least one test. See report for details.')
end

end

