function [s,program] = updatePulseSequence(obj,MWonTime)
%% get hw lines for different pieces of equipment(subtract 1 because PB
% is indexed from 0)
laser_hw = obj.laser.PBline-1;
MW_switch_hw = obj.RF.MW_switch_PB_line-1;
photodiode_hw = obj.Photodiode.PBline-1;


%% setup pulseblaster

assert(~obj.abort_request,'User aborted');
obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);

% Make some channels
cLaser = channel('laser','color','g','hardware',laser_hw);
cMWswitch = channel('MWswitch','color','k','hardware',MW_switch_hw');
cDummy = channel('dummy','color','b','hardware',obj.dummyLine - 1');
cPhotodiode = channel('PD','color','r','hardware',photodiode_hw');

%% Make sequence
 
s = sequence('Rabi_sequence');
s.channelOrder = [cLaser,cMWswitch,cPhotodiode,cDummy];


% MW gate duration
n_MW = node(s.StartNode,cMWswitch,'delta',obj.deadTime,'units','ns');
n_MW_on = node(n_MW,cMWswitch,'delta',MWonTime,'units','ns');

% Laser duration
n_LaserStart = node(n_MW_on,cLaser,'delta',0,'units','ns');
n_LaserEnd = node(n_LaserStart,cLaser,'delta',obj.LaseronTime,'units','ns');

% PD duration
n_PD = node(n_MW_on,cPhotodiode,'delta',obj.deadTime,'units','ns');
n_PD = node(n_PD,cPhotodiode,'delta',obj.LaseronTime +  obj.padding,'units','ns');

% dummy line

n_dummy = node(s.StartNode,cDummy,'delta',0,'units','ns');
n_dummy = node(n_LaserEnd,cDummy,'delta',obj.deadTime + obj.padding + obj.LaseronTime + MWonTime,'units','ns');

%%

[program,~] = s.compile;

%% hack to make sequence run forever

[commands , ~]= size(program);
text = program{commands-1};
index = strfind(text,'.');
text(index-1) = '0'; %set final command length to be 10 ns instead of 14
program(commands(1)-1) = {text}; %by setting the final command to be less than the min Pulse duration sequence repeats endlessly

%% 
obj.pulseblaster.stop; %in case of running sequence
obj.pulseblaster.open;
obj.pulseblaster.load(program); %board is loaded and ready to start

end