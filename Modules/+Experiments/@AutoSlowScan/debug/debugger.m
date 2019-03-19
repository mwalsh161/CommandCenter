a = Experiments.AutoSlowScan;

h = msgbox('Experiment Started');
% Repurpose the OKButton
button = findall(h,'tag','OKButton');
set(button,'tag','AbortButton','string','Abort',...
   'callback',@obj.abort)
drawnow;
textH = findall(h,'tag','MessageBox');

%a.obj.loadPrefs;
a.rl = rl;
a.gl = gl;
a.galvos = galvos;
a.nidaq = nidaq;
a.spectrometer = WinSpec;
a.wavemeter = wavemeter;

a.Run(textH,0,0)