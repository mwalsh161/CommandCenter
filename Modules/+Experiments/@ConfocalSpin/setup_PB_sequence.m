function ps = setup_PB_sequence(obj)
%SETUP_PB_SEQUENCE Generate sequence object

% Account for annoying line indexing in sources
ResLaserLine = obj.Res_LaserH.PB_line - 1;
MWLine = obj.MW_SourceH.PB_line - 1;
RepumpLaserLine = obj.Repump_LaserH.PB_line - 1;
APDLine = obj.APD_line;

cRepump = channel('Repump','color','g','hardware',RepumpLaserLine);
cRes = channel('Resonant','color','r','hardware',ResLaserLine);
cMW = channel('MWswitch','color','b','hardware',MWLine);
cAPD = channel('APDgate','color','k','hardware',APDLine,'counter','APD1');

ps = sequence('ConfocalSpin');
ps.channelOrder = [cRepump,cRes,cMW,cAPD];

% init pulse
n = node(ps.StartNode,cRepump);
n = node(n,cRepump,'units','us','delta',obj.Repump_time_us);
n = node(n,cAPD,'delta',-obj.Readout_time_ns);
n = node(n,cAPD,'delta',obj.Readout_time_ns);

% MW pulse
n = node(n,cMW,'delta',obj.buffer_time_ns);
n = node(n,cMW,'delta',obj.Pi_time_ns);

% Readout
n = node(n,cRes,'delta',obj.buffer_time_ns);
node(n,cAPD); % Don't return n here to reference previous n
n = node(n,cRes,'delta',obj.Readout_time_ns);
node(n,cAPD);

ps.repeat = obj.n_avg;
end

