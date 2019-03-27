function [s,program] = updatePulseSequence(obj,MWonTime,MWon)
%% get hw lines for different pieces of equipment(subtract 1 because PB
% is indexed from 0)
laser_hw = obj.laser.PBline-1;

if MWon
    MW_switch_hw = obj.RF.MW_switch_PB_line-1;
else
    MW_switch_hw = obj.MWDummy;% this turns the MW off by setting the line to the wrong number
end
%% setup pulseblaster

assert(~obj.abort_request,'User aborted');
obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);

% Make some channels
cLaser = channel('laser','color','g','hardware',laser_hw);
cMWswitch = channel('MWswitch','color','k','hardware',MW_switch_hw');
cDummy = channel('dummy','color','b','hardware',obj.dummyLine - 1');

%% Make sequence
 
s = sequence('Rabi_sequence');
s.channelOrder = [cLaser,cMWswitch,cDummy];


% MW gate duration
n_MW = node(s.StartNode,cMWswitch,'delta',obj.deadTime,'units','ns');
n_MW_on = node(n_MW,cMWswitch,'delta',MWonTime,'units','ns');

% Laser duration
n_LaserStart = node(n_MW_on,cLaser,'delta',0,'units','ns');
n_LaserEnd = node(n_LaserStart,cLaser,'delta',obj.LaseronTime,'units','ns');

% dummy line

n_dummy = node(s.StartNode,cDummy,'delta',0,'units','ns');
n_dummy = node(n_dummy,cDummy,'delta',obj.deadTime + obj.padding + obj.LaseronTime + MWonTime,'units','ns');

%%

[program,~] = s.compile;

%% 
obj.pulseblaster.stop; %in case of running sequence
obj.pulseblaster.open;
obj.pulseblaster.load(program); %board is loaded and ready to start

end