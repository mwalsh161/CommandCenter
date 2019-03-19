function run(obj,statusH,managers,ax)
obj.abort_request=false;
obj.logger.visible = 'on'; %open the logger to show testing progress
obj.tests = struct('name',{},'success',{},'output',{},'err',{}); %initialize structure to store test results
obj.status = ''; %empty test status

%Load signal generator
rel_path = 'Modules/+Drivers/+SignalGenerators'; % path relative to AutomationSetup (Git root)
[CC_root,~,~] = fileparts(which('CommandCenter')); % path to AutomationSetup (Git root)
[file,path] = uigetfile('*.m','Select SG driver to Test',fullfile(CC_root,rel_path));
[~,class_name,~] = fileparts(file);
[prefix] = Base.GetClasses(path); % get the prefix
driver = [prefix, class_name];

super = superclasses(driver);
assert(ismember('Drivers.SignalGenerators.SignalGenerator',super),...
    'Superclass of %s must be Modules.Drivers.SignalGenerators.SignalGenerator',driver)
obj.SG = eval(sprintf('%s.instance(class_name)', driver)); %instantiate driver for your SG

try
    %grab device name
    obj.driver = driver;
    
    %Test device handshake
    obj.tests(end+1) = obj.run_test('handshake',...
        '',isempty(obj.SG.ComDriver.writeRead('*IDN?')),false);
    
    %Test setting of power unit to dBm
    obj.tests(end+1) = obj.run_test('set power unit',...
        @()obj.SG.setUnitPower,...
        @()lower(obj.SG.getUnitPower),'dbm');
    
    %Test setting of CW frequency
    obj.tests(end+1) = obj.run_test('set CW frequency',...
        @()obj.SG.setFreqCW(obj.freq_CW),...
        @()round(obj.SG.getFreqCW),round(obj.freq_CW));
    
    %Test setting of CW power
    obj.tests(end+1) = obj.run_test('set CW power',...
        @()obj.SG.setPowerCW(obj.power_CW),...
        @()round(obj.SG.getPowerCW),round(obj.power_CW));
    
    %Test turning on of MW
    obj.tests(end+1) = obj.run_test('set MW on',...
        @()obj.SG.on,...
        @()lower(obj.SG.getMWstate),'on');
    
    %User should verify correct frequency on an oscilliscope
    obj.tests(end+1) = obj.run_test('user verification of emission frequency',...
        '',...
        @()questdlg(sprintf('Verify emission at frequency: %g GHz.',obj.freq_CW/1e9),...
        'User verification of emission frequency.','Correct','Incorrect','Incorrect'),...
        'Correct');
    
    %Test turning off of MW
    obj.tests(end+1) = obj.run_test('set MW off',...
        @()obj.SG.off,@()lower(obj.SG.getMWstate),'off');
    
    %Build lists for LIST mode, then test proper setting
    [obj.freq_list, obj.power_list] = obj.BuildFreqLists;
    obj.tests(end+1) = obj.run_test('set List mode',...
        @()obj.SG.program_list(obj.freq_list,obj.power_list),...
        @()strcmpi(obj.SG.getFreqMode,'LIST') && strcmpi(obj.SG.getPowerMode,'LIST'),true);
    obj.tests(end+1) = obj.run_test('set frequency list',...
        '',...
        @()obj.SG.getFreqList,obj.freq_list);
    obj.tests(end+1) = obj.run_test('set power list',...
        '',...
        @()obj.SG.getPowerList,obj.power_list);
    
    %If trigger type selected, user should verify correct
    %LIST stepping on an oscilliscope
    if strcmpi(obj.trigger_type,'None')
        SKIP = true;
    else
        SKIP = false;
    end
    
    %First, step through frequency list
    [obj.freq_list, obj.power_list] = obj.BuildFreqLists;
    obj.SG.program_list(obj.freq_list,obj.power_list)
    
    for freq = obj.freq_list
        obj.tests(end+1) = obj.run_test(sprintf('frequency stepping at %g GHz',freq/1e9),...
            '',...
            @()questdlg(sprintf('Verify emission at frequency: %g GHz.',freq/1e9),...
            'User verification of frequency list stepping.','Correct','Incorrect','Incorrect'),...
            'Correct',SKIP);
        obj.StepList;
    end
    
    %Second, step through power list
    [obj.freq_list, obj.power_list] = obj.BuildPowerLists;
    obj.SG.program_list(obj.freq_list,obj.power_list)
    obj.SG.on;
    
    for power = obj.power_list
        obj.tests(end+1) = obj.run_test(sprintf('power stepping at %g dBm',power),...
            '',...
            @()questdlg(sprintf('Verify emission at power: %g dBm.',power),...
            'User verification of power list stepping.','Correct','Incorrect','Incorrect'),...
            'Correct',SKIP);
        obj.StepList;
    end
    
    obj.logger.log('Signal generator tests complete.');
    obj.SG.reset;
    %Loop through test results, check for failure
    for i = 1:length(obj.tests)
        if ~obj.tests(i).success
            obj.status = 'fail';
        end
    end
catch err
    obj.status = 'fail';
    obj.SG.reset
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