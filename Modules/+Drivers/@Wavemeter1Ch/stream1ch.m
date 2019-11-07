function stream1ch(obj,dt)
% WAVEMETERSTREAM Streams all active channels from wavemeter
%   Includes wavelength and DAC voltage as function of time
%   Channel number in legend will be red if locking is set to on, black
%     otherwise.

if nargin < 2
    dt = 0.2;
end

f = UseFigure(mfilename,'name','Wavemeter Monitor','NumberTitle','off','MenuBar','none');
if ~isempty(f.UserData) && isfield(f.UserData,'timer') && isvalid(f.UserData.timer) % Means currently running version
    stop(f.UserData.timer);
    clf(f,'reset');
end

% Get all available channels (should be readonly)
%states = find(Drivers.Wavemeter.getChannelStates(ip));
%for i = 1:length(states)
%wm = Drivers.Wavemeter1Ch.instance(ip);  
    
ax(1) = subplot(3,1,1,'parent',f); hold(ax(1),'on');
xlabel(ax(1),'Time (s)')
ylabel(ax(1),'Wavelength (nm)')
ax(2) = subplot(3,1,2,'parent',f); hold(ax(2),'on');
xlabel(ax(2),'Time (s)')
ylabel(ax(2),'Voltage (V)')
ax(3) = subplot(3,1,3,'parent',f); hold(ax(3),'on');
xlabel(ax(3),'Time (s)')
ylabel(ax(3),'Power (uW)')
if isempty(obj)
    title(ax(1),'No Active Channels');
    return
end


    % Wavelength plots
plot(ax(1),NaN,NaN,'tag','wm','UserData',struct('wm',obj)); 
    % DAC Voltage plots
plot(ax(2),NaN,NaN,'tag','wm');
    % Power Plots  
plot(ax(3),NaN,NaN,'tag','wm');

hold(ax(1),'off');
hold(ax(2),'off');
hold(ax(3),'off');
leg = cellfun(@num2str,{1},'UniformOutput',false);
leg = legend(ax(1),leg,'orientation','horizontal','location','northoutside');

t = timer('name',mfilename,'executionmode','fixedspacing','period',dt,'StopFcn',@cleanup,...
    'timerfcn',@update,'userdata',struct('ax',ax,'wm',obj,'t0',tic,'leg',leg),'busymode','drop');
set(f,'UserData',struct('timer',t));
start(f.UserData.timer);
end

function update(hObj,~)
UserData = hObj.UserData;
ax = UserData.ax;
pWav = findall(ax(1),'tag','wm');
pVol = findall(ax(2),'tag','wm');
pPow = findall(ax(3),'tag','wm');
if all(isvalid(ax)) && length(pWav)==length(pVol)
    for i = 1:length(pWav)
        t = toc(UserData.t0);
        wm = pWav(i).UserData.wm;
        vlt = NaN;
        try %#ok<TRYNC>
            vlt = wm.getDeviationVoltage;
        end
        pVol(i).YData(end+1) = vlt;
        pVol(i).XData(end+1) = t;
        if wm.getPIDstatus && wm.getDeviationChannel
            UserData.leg.String{i} = sprintf('\\color{red}%i',i);
        else
            UserData.leg.String{i} = sprintf('%i',i);
        end
        wl = NaN;
        try %#ok<TRYNC>
            wl = wm.getWavelength;
        end
        pWav(i).YData(end+1) = wl;
        pWav(i).XData(end+1) = t;
        
        pow = NaN;
        try %#ok<TRYNC>
            pow = wm.getPower();
        end
        pPow(i).YData(end+1) = pow;
        pPow(i).XData(end+1) = t;
    end
    drawnow limitrate;
else % Clean up
    stop(hObj)
end
end

function cleanup(hObj,~)
UserData = hObj.UserData;
delete(UserData.wm)
delete(hObj)
end
