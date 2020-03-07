function [s,n_MW,n_MW_on] = setup_PB_sequence(obj)

Integration_time = obj.Integration_time*1e6;
laser_read_time = obj.laser_read_time; %in ns
MW_on_time = obj.MW_on_time;

if strcmp(obj.disp_mode,'verbose')
    nSamples = round(Integration_time/laser_read_time);
elseif strcmp(obj.disp_mode,'fast')
    nSamples = round(obj.nAverages*Integration_time/laser_read_time);
else
    error('Unrecognized display mode type.')
end

%pulseblaster hw lines
laser_hw = obj.Laser.PBline-1;
APD_hw = obj.APD_PB_line-1;
MW_switch_hw = obj.RF.MW_switch_PB_line-1;

% Make some chanels
cLaser = channel('laser','color','g','hardware',laser_hw);
cAPDgate = channel('APDgate','color','b','hardware',APD_hw,'counter','APD1');
cMWswitch = channel('MWswitch','color','k','hardware',MW_switch_hw');

deadTime = obj.stop_time - obj.laserDelay + 100;
%% 
if obj.reInitializationTime < obj.padding + 2*laser_read_time + obj.laserDelay
    obj.reInitializationTime = obj.padding + 2*laser_read_time + obj.laserDelay;
    
end

%%

% Make sequence
s = sequence('RABI_sequence');
s.channelOrder = [cLaser,cAPDgate,cMWswitch];

% make outer loop to compensate for limit on sequence.repeat
out_loop = 'out_loop';
out_val = 1; %temporary placeholder
n_init_out_loop = node(s.StartNode,out_loop,'type','start');

% Laser duration:data
n_Laser1 = node(s.StartNode,cLaser,'delta',deadTime,'units','ns');
n_Laser = node(n_Laser1,cLaser,'delta',obj.reInitializationTime,'units','ns');
% 
% % Laser duration:norm
% n_Laser2 = node(n_Laser,cLaser,'delta',obj.padding,'units','ns');
% n_Laser = node(n_Laser2,cLaser,'delta',laser_read_time,'units','ns');

% APD gate duration:data
n_APD1 = node(n_Laser1,cAPDgate,'delta',obj.laserDelay,'units','ns');
n_APD = node(n_APD1,cAPDgate,'delta',laser_read_time,'units','ns');

% APD gate duration:norm
n_APD = node(n_Laser,cAPDgate,'delta', -laser_read_time + obj.laserDelay,'units','ns');
n_APD = node(n_APD,cAPDgate,'delta',laser_read_time,'units','ns');

% MW gate duration
n_MW = node(n_APD1,cMWswitch,'delta',-MW_on_time,'units','ns');
n_MW_on = node(n_MW,cMWswitch,'delta',MW_on_time,'units','ns');

% End outer loop and calculate repetitions
n_end_out_loop = node(n_APD,out_val,'delta',100,'type','end');
max_reps = 2^20-1;

if nSamples > max_reps
    % loop to find nearest divisor
    while mod(nSamples,max_reps) > 0
        max_reps = max_reps - 1;
    end
    n_end_out_loop.data = nSamples/max_reps;
    s.repeat = max_reps;
else
    s.repeat = nSamples;
end
% f100 = figure(100);
% clf(f100);
% ax = axes(f100);
% s.draw(ax)
end