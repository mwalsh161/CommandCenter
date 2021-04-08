%% Setup
% Channels to output on.
ao = 'SolstisResonator';    % channel for sweeping resonant laser
do = 'CoboltTrigger';       % trigger to turn on repump
ctr = 'APD1';               % line for counter
sync = 'sync';
wm_chan = 7;                % channel for wavemeter

% Variables that govern the shape of our output.
scans = 100;            % Number of PLE scans to take
vi = 0;                 % Initial voltage
vf = 2;                 % Final voltage
ub = 1000;              % Up bins
db = 100;               % Down bins
dwell = .001;           % Dwell per bin in sec (1 ms)

tb = (ub + db)*scans;   % Total bins

% Generate the lists that we will output.
alist = [linspace(vi, vf, ub+1) linspace(vf, vi, db+1)]';    % linspace(,,N+1) such that bin width is correct. Remove the two extra points next.
alist(ub+1) = [];   % Remove the duplicated point at the center.
alist(end) = [];    % Remove the duplicated point at the end.
dlist = [zeros(1, ub) ones(1, db)]';

% store everything
data.meta.scans = scans;             % Number of PLE scans to take
data.meta.vi = vi;                 % Initial voltage
data.meta.vf = vf;                % Final voltage
data.meta.ub = ub;              % Up bins
data.meta.db = db;               % Down bins
data.meta.dwell = dwell;           % Dwell per bin in sec (1 ms)

%% Set up hardware
wm = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu',wm_chan);
ni = Drivers.NIDAQ.dev.instance('Dev1');

ni.WriteAOLines(ao, mean([vi vf]));

input('Press any key once the laser is in the desired position. Also unlock the laser!')

%% Do wavelength checks

%ramp through once
for ii=1:length(alist)
    ni.WriteAOLines(ao,alist(ii))
    if ~mod(ii,10)
        fprintf('Writing voltage %i/%i\n',ii,length(alist))
    end
end

%now ramp through to get frequencies
freqs_pre = nan(1, ub+db);
figure;
ax = axes;
hold(ax,'on')
p1 = plot(ax,alist,freqs_pre);
xlabel('Voltages (V)')
ylabel('Frequencies (THz)')

for ii=1:length(alist)
    ni.WriteAOLines(ao,alist(ii))
    pause(dwell)
    freqs_pre(ii) = wm.getFrequency;
    p1.YData = freqs_pre;
    if ~mod(ii,10)
        drawnow;
    end
end

data.freqs_pre = freqs_pre;

%% Configure tasks for full sweeps

alist = [repmat(alist, [scans 1]); vi];
dlist = [repmat(dlist, [scans 1]); 0];

ni.ClearAllTasks();

% Configure pulsetrain (timebase)
freq = 1/dwell;
taskPulseTrain = ni.CreateTask('FastScanPulseTrain');
try
    taskPulseTrain.ConfigurePulseTrainOut(sync, freq, tb+1);        % One extra point for diff'ing; the counter outputs cts since start.
    taskPulseTrain.Verify();
catch err
    taskPulseTrain.Clear
    rethrow(err)
end
% Configure analog output (tuning)
taskAnalog = ni.CreateTask('FastScanAnalog');
try
    taskAnalog.ConfigureVoltageOut(ao, alist, taskPulseTrain);      % DAQmx_Val_AllowRegen is on by default, so the buffer will loop back on this list.
    taskAnalog.Verify();
catch err
    taskPulseTrain.Clear
    taskAnalog.Clear
    rethrow(err)
end

% Configure digital output (repump)
taskDigital = ni.CreateTask('FastScanDigital');
try
    taskDigital.ConfigureDigitalOut(do, dlist, taskPulseTrain);     % DAQmx_Val_AllowRegen is on by default, so the buffer will loop back on this list.
    taskDigital.Verify();
catch err
    taskPulseTrain.Clear
    taskAnalog.Clear
    taskDigital.Clear
    rethrow(err)
end

% Configure counter input (APD)
taskCounter = ni.CreateTask('FastScanCounter');
try
    taskCounter.ConfigureCounterIn(ctr, tb+1, taskPulseTrain);      % One extra point for diff'ing; the counter outputs cts since start.
    taskCounter.Verify();
catch err
    taskPulseTrain.Clear
    taskAnalog.Clear
    taskDigital.Clear
    taskCounter.Clear
    rethrow(err)
end

%% Start tasks
taskAnalog.Start();
taskDigital.Start();
taskCounter.Start();
taskPulseTrain.Start();
raw = NaN(tb+1,1);
fig = figure;
ax = axes;
im = imagesc(freqs_pre,1:scans,nan(scans,ub),'parent',ax);
xlabel('Frequency (THz)')
ylabel('Scan Number')
ii = 0;
while isvalid(taskCounter) && (~taskCounter.IsTaskDone || taskCounter.AvailableSamples)
    SampsAvail = taskCounter.AvailableSamples;
    % Change to counts per second
    counts = taskCounter.ReadCounter(SampsAvail);
    raw(ii+1:ii+SampsAvail) = counts;
    vals = reshape(diff(raw), [ub+db, scans])';
    im.CData = vals(:,1:ub);
    ii = ii + SampsAvail;    
    drawnow;
end
data.data = vals;

% Stop tasks
taskAnalog.Clear();
taskDigital.Clear();
taskCounter.Clear();
taskPulseTrain.Clear();

%% Post check frequency stability
freqs_post = nan(1, ub+db);
figure;
ax = axes;
hold(ax, 'on')
p1 = plot(ax, alist(1:(ub+db)), freqs_post);
xlabel('Voltages (V)')
ylabel('Frequencies (THz)')
for ii = 1:(ub+db)
    ni.WriteAOLines(ao, alist(ii))
    pause(dwell)
    freqs_post(ii) = wm.getFrequency;
    p1.YData = freqs_post;
    drawnow;
end
data.freqs_post = freqs_post;

ni.WriteAOLines(ao, mean([vi vf]));

uisave(data);