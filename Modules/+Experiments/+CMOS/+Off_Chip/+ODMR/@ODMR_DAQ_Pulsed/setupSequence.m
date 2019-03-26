function [program,s] = setupSequence(obj) 
%% get hw lines for different pieces of equipment(subtract 1 because PB is indexed from 0)
    laser_hw = obj.laser.PBline-1;
    MW_switch_hw = obj.RF.MW_switch_PB_line-1;
    if strcmpi(obj.MWPulsed,'no')
        dummy_hw = MW_switch_hw; %if you dont want to pulse the MW set it to the dummy
        MW_switch_hw = 10;
    elseif strcmpi(obj.MWPulsed,'yes')
        MW_switch_hw = obj.RF.MW_switch_PB_line-1;
        dummy_hw = 10;
    elseif strcmpi(obj.MWPulsed,'off')
        dummy_hw = 10;
        MW_switch_hw = 11;
    else
        error('Unknown MWPulsed State')
    end
    %% setup pulseblaster
    assert(~obj.abort_request,'User aborted');
    obj.Pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
       
    % Make some channels
    cLaser = channel('laser','color','g','hardware',laser_hw);
    cMWswitch = channel('MWswitch','color','k','hardware',MW_switch_hw);
    cDummy = channel('dummy','color','b','hardware',dummy_hw');
    
    %%

    % Make sequence
    s = sequence('Pulsed_Freq_Sweep_sequence');
    s.channelOrder = [cLaser,cMWswitch,cDummy];
    
    nloop = node(s.StartNode,'Loop the number of samples for averaging','type','start','delta',0,'units','us');

     %dummy line
     
    n_dummy = node(s.StartNode,cDummy,'delta',0,'units','us');
    n_dummy = node(n_dummy,cDummy,'delta',obj.LaserOnTime + obj.MWTime + obj.DelayTime + 2*obj.dummyTime,'units','us');
    
    % MW gate duration
    n_MW = node(s.StartNode,cMWswitch,'delta',obj.dummyTime,'units','us');
    n_MW_on = node(n_MW,cMWswitch,'delta',obj.MWTime,'units','us');
    
    % Laser duration
    n_LaserStart = node(n_MW_on,cLaser,'delta',obj.DelayTime,'units','us');
    n_LaserEnd = node(n_LaserStart,cLaser,'delta',obj.LaserOnTime,'units','us');
     
    nloop = node(n_LaserEnd,1000,'type','end','delta',0,'units','us');
    s.repeat = 10000;
    
    %%
    [program,~] = s.compile;
    
    %% 
    obj.Pulseblaster.stop;
    obj.Pulseblaster.open;
    obj.Pulseblaster.load(program);