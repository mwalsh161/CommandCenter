function   s  = BuildCalibrateSequence(obj,readoutime)
%BuildPulseSequence Builds pulse sequence to determine the optimal
%readout time
 
s = sequence('Readout_Calibration');
laserchannel = channel('Laser','color','r','hardware',obj.laser.PBline-1);
APDchannel = channel('APDgate','color','b','hardware',obj.apdLine-1,'counter','APD1');
cMWswitch = channel('MWswitch','color','k','hardware',obj.SG.MW_switch_PB_line-1);

s.channelOrder = [laserchannel, APDchannel,cMWswitch];
%% check that padding is bigger than offsets

assert(laserchannel.offset(1) < obj.padding ,' laser channel offset is less than padding')
assert(APDchannel.offset(1) < obj.padding ,' APD channel offset is less than padding')
assert(cMWswitch.offset(1) < obj.padding ,' MWSwitch channel offset is less than padding')

%% 

% MW gate duration

n_MW = node(s.StartNode,cMWswitch,'delta',obj.padding,'units','ns');
n_MW = node(n_MW,cMWswitch,'delta',obj.piTime,'units','ns');
%% data

% laser duration
n_laser = node(n_MW,laserchannel,'delta',obj.padding,'units','ns');
n_laser = node(n_laser,laserchannel,'delta',obj.reInitializationTime,'units','ns');

% APD duration
n_APD = node(n_MW,APDchannel,'delta',obj.padding,'units','ns');
n_APD = node(n_APD,APDchannel,'delta',readoutime,'units','ns');

%% normalization

% laser duration
n_lasernorm = node(n_laser,laserchannel,'delta',obj.padding,'units','ns');
n_lasernorm = node(n_lasernorm,laserchannel,'delta',obj.reInitializationTime,'units','ns');

% APD duration
n_APD = node(n_laser,APDchannel,'delta',obj.padding,'units','ns');
n_APD = node(n_APD,APDchannel,'delta',readoutime,'units','ns');
end
