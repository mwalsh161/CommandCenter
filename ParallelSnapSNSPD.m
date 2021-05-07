function ParallelSnapSNSPD
    cls = Stages.Galvos.instance();
    % Read galvo position
    pos1 = cls.position
    move(cls,-0.3996,-0.2344,0) %FIXME delete after tests
    pos1 = cls.position
    % Define Galvo map
    % make sure N (below) matches Swabian data points (n)
    N = 20; % number of points per line (i.e. total points N^2)
    BINWIDTH = 1e9; % integration time of each SNSPD data point (in picoseconds)
    PAD = 1e10; % extra time added to Swabian line scan, to accommodate delays (unit = picoseconds)
    
    posx = pos1(1) - [0.05, -0.05];
    posy = pos1(2) - [0.05, -0.05];
    counts=zeros(N,N);
    % Save scan parameters
    timestamp=clock;
    ts=string(timestamp);
    datetime=strcat(ts(1),ts(2),ts(3),ts(4),ts(5))
    fileID = fopen(strcat(datetime,'_test.txt'),'w');
    fprintf(fileID,'Date: %s \nPoints per line\t initial posx\t initial posy\t posx1\t posx2\t posy1\t posy2\n%i\t %f\t %f\t %f\t %f\t %f\t %f\n' ...
            ,datestr(timestamp), N, pos1(1), pos1(2), posx(1), posx(2), posy(1), posy(2))
    
    % Create swabian data output folder structure
    system(strcat('mkdir', ' swabian_', datetime))
    for line = 1:10
        system(strcat('mkdir ', ' swabian_', datetime, '\line_',num2str(line)));
    end
    
    % Start up parallel pool (one thread for galvos, one thread for
    % swabian)
    delete(gcp('nocreate'));
    p = parpool(2);
    
    countm=1; % line index
    length(min(posy):abs(posy(1)-posy(2))/(N-1):max(posy))
    for m = min(posy):abs(posy(1)-posy(2))/(N-1):max(posy) %scan in Y
        % Run the swabian acquisition in parallel with galvo scan
        parfor j =1:2
            % Swabian
            if j==1 
                cmd = strcat('python C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_batch.py ', ...
                    num2str(N), ' ', num2str(BINWIDTH), ' ', num2str(PAD))
                system(cmd);
            % Galvos
            else
                countm
                for n = min(posx):abs(posx(1)-posx(2))/(N-1):max(posx) %scan in X
%                     % Read galvo position
%                     pos2 = cls.position;
%                     
%                     % Move galvo
%                       n
                    move(cls,n,m,0);
                end
            end
        end
        
        
        % Load swabian counts and move count file to line folder
        load('C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat', 'swab_counts'); % load count array variable "swab_counts"
        system(strcat('move C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat swabian_', datetime, '\line_', num2str(countm)));
        
        % Update counts matrix
        counts(:,countm) = swab_counts; 
        countm=countm+1;
    end
    % Move back to initial position and print data
    move(cls,pos1(1),pos1(2),0)
    posf = cls.position
    fprintf(fileID,[repmat('%f\t',1,size(counts,2)) '\n'],fliplr(counts'));
    fclose(fileID);
    % Plot data
    h=surf(min(posy):abs(posy(1)-posy(2))/(N-1):max(posy),min(posx):abs(posx(1)-posx(2))/(N-1):max(posx),counts)
    set(h,'edgecolor','none')
    view(2)
    colorbar

end