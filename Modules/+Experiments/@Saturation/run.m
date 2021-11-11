function run(obj,statusH,managers,ax)
statusWin = statusH.Parent.Parent;
button = findall(statusWin,'tag','AbortButton');
newButton = add_button(button,'Stop Acquire');
newButton.Callback = @obj.stop_acquire;
set(statusH,'string','Starting data acquisition...');
drawnow;

panel = ax.Parent;
delete(ax)
ax(1) = subplot(1,2,1,'parent',panel);
ax(2) = subplot(1,2,2,'parent',panel);

% Flip the acquire boolean to true, set PM wavelength, and initialize data structures
obj.acquire = true;
obj.PM100.set_wavelength(obj.wavelength);
obj.pm_data = [];
obj.apd_data = [];

% Continually collect and plot PM and APD data until the user hits "Stop acquisition", which flips
% obj.acquire to false
while obj.acquire
    obj.pm_data = [obj.pm_data, obj.PM100.get_power('MW')];
    obj.apd_data = [obj.apd_data, obj.counter.singleShot(obj.counter.dwell, obj.nsamples)];
    [~, sort_index] = sort(obj.pm_data);
    plot(ax(1),obj.pm_data(sort_index),obj.apd_data(sort_index))
    xlabel(ax(1),'Input Power (mW)')
    ylabel(ax(1), 'Output Counts')
    plot(ax(2),obj.pm_data)
    ylabel(ax(2),'Input Power (mW)')
    xlabel(ax(2), 'Collection Bins')
end
set(statusH, 'string', 'Acquisition complete!');

% Set "abort" status if the data structures are empty
if isempty(obj.pm_data) && isempty(obj.apd_data)
    set(statusH,'string','Aborted!');
end
end