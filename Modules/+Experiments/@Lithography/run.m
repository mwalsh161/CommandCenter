function run( obj,status,managers,ax )
obj.abort_requested = false;
obj.status_handle = status;
% Check to see if a file has been selected
if ~exist(obj.file,'file')
    error('No file selected.')
end
response = questdlg(sprintf('Using %gms dwell time.',obj.dwell),...
    sprintf('Confirm %s Run',mfilename('class')),...
    'Continue','Cancel','Cancel');
if ~strcmp('Continue',response)
    error('Run cancelled by user.')
end
seq = load(obj.file);
fieldname = fields(seq);
assert(length(fieldname)==1,'Too many fields in loaded file. Should only be one.');
seq = seq.(fieldname{1});
totalTime = obj.dwell*1e-3*size(seq,1);
elapsedTime = 0;
obj.updateTime(status,totalTime-elapsedTime);

set(status,'string',sprintf('Compiling write sequence\nand programming boards...'));
drawnow;
seq(:,1:2) = seq(:,1:2)/(5/0.118);
seq(:,3) = seq(:,3)/16;
obj.init_nidaq(seq(:,1:3));
obj.init_pulseblaster(seq(:,4));
interrupt = addlistener(obj.pb,'aborted',@(~,~)obj.abort);

% Begin writing
obj.pb.start;
obj.task.Galvos.Start;
obj.task.PulseTrain.Start;
tic;
while ~obj.task.PulseTrain.IsTaskDone
    elapsedTime = toc;
    obj.updateTime(status,totalTime-elapsedTime);
    pause(0.1)
    if obj.abort_requested
        obj.task.Galvos.Clear;
        obj.task.PulseTrain.Clear;
        obj.pb.stop;
        delete(interrupt)
        error('Experiment aborted.')
    end
end
obj.task.Galvos.Clear;
obj.task.PulseTrain.Clear;
delete(interrupt)
obj.pb.stop;
% Reset lines to 0
obj.ni.WriteAOLines({obj.x,obj.y,obj.z},[0; 0; 0]);
set(status,'string','Complete!')
end