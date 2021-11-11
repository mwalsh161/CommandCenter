function sites = select_grid_sites(sites,ax_temp)
    hold(ax_temp,'on')
    w=0; % waitforbuttonpress flag
    while w==0
        %ask for nr of points in x and y
        done = 0;
        while done == 0
            answer = str2double(inputdlg({'X points:','Y points:'},'Grid size',[1 35],{'20','20'}));
            if length(answer)==2 && all(answer>0)
                nX=answer(1);
                nY=answer(2);
                done = 1;
            else
                uiwait(msgbox('Values must be integers larger than 0','Invalid input','modal'));
            end
        end
        %ask for positions of 3 points (1&2 define angle, 1&3 define center)
        title(ax_temp,'Click on 3 positions to define a grid. Hit any key when done. Otherwise click again to repeat')
        positions = ginput(3);
        
        point1=positions(1,:);
        point2=positions(2,:);
        point3=positions(3,:);
        
        delta=(point1-point2);
        rotation=-rad2deg(atan(delta(2)/delta(1)));
        center=(point1+point3)/2;
        
        offsetX=center(1);
        offsetY=center(2);
        
        lengthX=sqrt(sum((point1-point2).^2));
        lengthY=sqrt(sum((point2-point3).^2));
        
        spacingX=lengthX/nX;
        spacingY=lengthY/nY;
        
        rowX = linspace(-spacingX*nX/2,spacingX*nX/2,nX);
        rowY = linspace(-spacingY*nY/2,spacingY*nY/2,nY);
        
        [X1,Y1] = meshgrid(rowX,rowY);
        X1 = X1(:);
        Y1 = Y1(:);
        X = X1*cosd(rotation)+Y1*sind(rotation);
        Y = -X1*sind(rotation)+Y1*cosd(rotation);
        
        X = X+offsetX;
        Y = Y+offsetY;
        
        gridH=plot(ax_temp,X,Y,'r.');
        sites.positions=[X Y];
        
        %repeat taking 3 inputs until a key is pressed
        w = waitforbuttonpress;
        delete(gridH);
    end
    hold(ax_temp,'off')
end