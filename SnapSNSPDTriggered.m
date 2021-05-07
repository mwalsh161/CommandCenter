function SnapSNSPDTriggered 
    tic
    paper_size = [8 6];
    printit=1;
    folder='SnapSNSPD_data\UMD2\';
    
    % Set up Galvo Scanner
    cls = Imaging.Confocal.Galvo.instance();
    dwell = 10; % in ms
    click_channel = '4';
    trigger_channel = '5';
    
    % Set Galvo center position
%     pos1 = [0.035,-0.08,0];
    %pos1 = [0.32,0.28,0];
    pos1 = [0,0,0];
    pos1 = [0.05,-0.05,0];
    pos1 = [0.4,0.4,0];
    
    % Define Galvo map
    N = 40; % number of points per line (i.e. total points N^2)
    Vmap=0.2;
    posx = pos1(1) - [Vmap, -Vmap];
    posy = pos1(2) - [Vmap, -Vmap];
    y = min(posy):abs(posy(1)-posy(2))/N:max(posy);
    x = min(posx):abs(posx(1)-posx(2))/N:max(posx);
    cls.galvos.SetupScan(x, y, dwell);
    
    % Save scan parameters
    timestamp=clock;
    ts=string(timestamp);
    datetime=strcat(ts(1),ts(2),ts(3),ts(4),ts(5));
    fileID = fopen(strcat(folder,datetime,'_test.txt'),'w');
    fprintf(fileID,'Date: %s \nPoints per line\t initial posx\t initial posy\t posx1\t posx2\t posy1\t posy2\n%i\t %f\t %f\t %f\t %f\t %f\t %f\n' ...
            ,datestr(timestamp), N, pos1(1), pos1(2), posx(1), posx(2), posy(1), posy(2))
    
    
    % Start Swabian triggered acquisition from OS commandline. Won't count
    % until it receives the trigger signal
    cmdStart = 'python C:\Users\Janis\CommandCenter\swabian_timetagger\start_gated_counts.py';
    cmd = [cmdStart, ' ', click_channel, ' ', trigger_channel, ' ', num2str((N+1)^2), ' ', num2str(dwell*10^9)];
    system(cmd);
    
    % Start Galvo scan (starts trigger signal)
    cls.galvos.StartScan;
    
    % Read out Swabian triggered acquisition
    cmdStop = 'python C:\Users\Janis\CommandCenter\swabian_timetagger\read_gated_counts.py';
    system(cmdStop);
    load('C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat', 'swab_counts'); 
    counts = reshape(swab_counts, [N+1,N+1]);
    % Adjust for zig-zag scan
    for col = 1:size(counts,2)
        if ~mod(col,2)
            counts(:,col)=flipud(counts(:,col));
        end
    end
    
    % Stop Galvo scan and reset NIDAQ tasks: 
    cls.galvos.nidaq.ClearAllTasks
    
    % Print data
    fprintf(fileID,[repmat('%f\t',1,size(counts,2)) '\n'],fliplr(counts'));
    fclose(fileID);
    % Plot data
    h=surf(min(posy):abs(posy(1)-posy(2))/N:max(posy),min(posx):abs(posx(1)-posx(2))/N:max(posx),counts)
    set(h,'edgecolor','none')
    view(2)
    colorbar
    datacursormode on
    if printit
        %print('-dpdf','PBS_paper.pdf')
        print('-dpng',strcat(folder,datetime,'_test.png'))
    end
    save('swab_counts_triggered', 'counts')
    toc
end