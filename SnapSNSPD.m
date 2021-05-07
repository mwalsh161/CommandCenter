function SnapSNSPD 
    paper_size = [8 6];
    printit=1;
    folder='SnapSNSPD_data\ANTSOI3_2\';
    cls = Stages.Galvos.instance();
    % Read galvo position
    %pos1 = cls.position
    %move(cls,-0.064,-0.084,0)
    move(cls,0.0525,0.1125,0)
    %move(cls,-0.209,0.133,0) %FIXME delete after tests
    pos1 = cls.position
    
    % Define Galvo map
    % make sure N (below) matches Swabian data points (n)
    N = 20; % number of points per line (i.e. total points N^2)
    
    Vmap=0.05;
    posx = pos1(1) - [Vmap, -Vmap];
    posy = pos1(2) - [Vmap, -Vmap];
    counts=zeros(N,N);
    % Save scan parameters
    timestamp=clock;
    ts=string(timestamp);
    datetime=strcat(ts(1),ts(2),ts(3),ts(4),ts(5));
    fileID = fopen(strcat(folder,datetime,'_test.txt'),'w');
    fprintf(fileID,'Date: %s \nPoints per line\t initial posx\t initial posy\t posx1\t posx2\t posy1\t posy2\n%i\t %f\t %f\t %f\t %f\t %f\t %f\n' ...
            ,datestr(timestamp), N, pos1(1), pos1(2), posx(1), posx(2), posy(1), posy(2))
    
    % Create swabian data output folder structure
%     system(strcat('mkdir', 'swabian_', datetime))
%     for line = 1:10
%         system(strcat('mkdir ', ' swabian_', datetime, '\line_',num2str(line)))
%     end
    
    countm=1; % line index
    countn=1;
    for m = min(posy):abs(posy(1)-posy(2))/N:max(posy) %scan in Y
        for n = min(posx):abs(posx(1)-posx(2))/N:max(posx) %scan in X
            % Read galvo position
            pos2 = cls.position;
            % Swabian measure or wait for integration time
            system('python C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_timetagger.py');
            % Load swabian counts as "swab_counts"
            load('C:\Users\Janis\CommandCenter\swabian_timetagger\swabian_output.mat', 'swab_counts'); 
            counts(countn,countm) = swab_counts;
            % Save data
            % Move galvo
            move(cls,n,m,0)
            countn=countn+1;
        end
        fprintf('Line %i of %i\n',countm,N)
        countn=1;
        countm=countm+1;

    end
    % Move back to initial position and print data
    move(cls,pos1(1),pos1(2),0)
    posf = cls.position
    fprintf(fileID,[repmat('%f\t',1,size(counts,2)) '\n'],fliplr(counts'));
    fclose(fileID);
    % Plot data
    h=surf(min(posy):abs(posy(1)-posy(2))/N:max(posy),min(posx):abs(posx(1)-posx(2))/N:max(posx),counts)
    set(h,'edgecolor','none')
    view(2)
    colorbar
    if printit
        %print('-dpdf','PBS_paper.pdf')
        print('-dpng',strcat(folder,datetime,'_test.png'))
    end

end