classdef QR
    % QR Detect and read "QR" codes
    % x and y scaling of input images should be similar!
    % Two main methods: READER and ENHANCEDREADER. reader does not use the
    % extra alignment markers and does not fit the main markers precicely.
    % enhancedReader does all of that (takes about 20 times longer).
    %   [pos,qrInfo,ax] = reader(im,to_plot)
    %   [pos,tform,err,npoints,qrInfo] = enhancedReader(im,to_plot)
    %
    %   tform returned is sample to lab (moving points are the sample points)
    
    properties(Constant)
        % Bit definitions
        length = 25;    % Total lenght of code
        pad = [1 5]; % Pad locations of bits (indexed from 1)
        padVal = 1; % Pad logical value
        vb = 4;   % Version bits
        rb = 8;   % Number of bits to encode the row
        cb = 8;   % Number of bits to encode the col
        cs = 3;   % Checksum
        
        % Paramters of QR code (um)
        module_size = 0.75;  % 0.75
        r = Base.QR.module_size/1.5;
        d = Base.QR.module_size + 0.5;  % Newer versions use module_size not r
        spacing = sqrt(Base.QR.length)*Base.QR.module_size + 2*Base.QR.d;
        NSecondary = 3;  % Number of secondary markers (per arm)
        centralMarks = 0; % Number (n) of central marks (per dim)
        spacing_between = 40;  % um
        
        % Detection constants
        diffraction_limit = 0.1; % um
        leg_len_thresh = 0.05;  % Ratio of length of each leg
        angle_thresh = 0.1;    % Error from pi/2 between legs
        BW_thresh = 0.35         % [0 1]; percent between max and min pixel val
    end

    methods(Static)
        function [c,r] = BasicBlock(qrInfo)
            % Builds position markers for qr sample at 0,0
            % Construct sample frame coordinates for all nearest neighbors
            c = [0,0; Base.QR.spacing,0; 0,Base.QR.spacing];
            r = [1 1 1]*max(Base.QR.r,Base.QR.diffraction_limit);
            if Base.QR.NSecondary > 0
                % Sorry for poor naming. This is spacing between a single QR's corners
                dist = Base.QR.spacing/(Base.QR.NSecondary+1);
                for ax=1:2
                    p = [0,0];
                    for i = 1:Base.QR.NSecondary
                        p(ax) = i*dist;
                        c(end+1,:) = p;
                        r(end+1) = max(Base.QR.module_size/4,Base.QR.diffraction_limit);
                    end
                end
            end
            if Base.QR.centralMarks > 0
                % This spacing refers to distance between QR codes
                dist = Base.QR.spacing_between/(Base.QR.centralMarks+1);
                for x = 1:Base.QR.centralMarks
                    for y = 1:Base.QR.centralMarks
                        p = [x,y]*dist;
                        c(end+1,:) = p;
                        r(end+1) = max(Base.QR.module_size/4,Base.QR.diffraction_limit);
                    end
                end
            end
        end
        function [pos,readInfo,ax] = reader(im,ax)
            % READER returns all found qr info
            %   READER(im, [to_plot]) where im is a SmartImage struct.
            %       Expecting ROI to be in um. Output will be in um.
            %
            %   ax is either left out or a valid axes handle
            
            % Pasre Input
            x = im.ROI(1,:);
            y = im.ROI(2,:);
            im = im.image;
            assert(size(im,3)==1,'Image must be gray scale.')
     %       im = -double(im);
            clean_up = false;
            if nargin < 2
                clean_up = true;
                f = figure;
                ax = axes('parent',f);
            end
            conv = [diff(x)/(size(im,2)-1),diff(y)/(size(im,1)-1)]; % um/pixel
            % Find all relevent QR circles
            r = Base.QR.r/mean(conv);
          %  imF = imcomplement(double(BandFilt(im,0,5,1)));
          %  imF = imF-mean(imF(:));
          %  c = FastPeakFind(imF,std(imF(:))*2);
          %  c = [c(1:2:end) c(2:2:end)];
          %  if size(c,1) < 3
                % If there weren't enough circles for even 1, try harder
                [c,~]=imfindcircles(im,round([0.8 1.2]*r),'ObjectPolarity','dark','Sensitivity',0.97);
          %  end
            % Find all QR candidates based on circle locations
            [offset,theta,scaling]=Base.QR.findQR(c,conv);
            version = cell(1,numel(theta));
            row = cell(1,numel(theta));
            col = cell(1,numel(theta));
            if ishandle(ax)&&isvalid(ax)
                imagesc(im,'parent',ax)
                axis(ax,'image','off')
                colormap(ax,'gray')
                set(ax,'YDir','normal')
                hold(ax,'on')
                drawnow nocallbacks
            else
                ax=false;
            end
            toRemove = [];
            % Go through and attempt to resolve QR codes
            posAll = NaN(numel(theta),2);
            for i = 1:numel(theta)
                R = [cos(theta{i}) -sin(theta{i}); sin(theta{i}) cos(theta{i})];
                try
                    [code] = Base.QR.digitize(im,offset{i},R*scaling{i},ax);
                    [row{i},col{i},version{i}] = Base.QR.analyze(code);
                     % Prepare outputs in correct units and format
                     xPos = col{i}*Base.QR.spacing_between;
                     yPos = row{i}*Base.QR.spacing_between;
                    % Shift to center of image
                    posAll(i,:) = [xPos,yPos] - ((offset{i}-1).*conv+[x(1) y(1)])*R;
                catch err
                    % Remove record of this guy
                    toRemove(end+1) = i;
                end
            end
            offset(toRemove) = [];
            theta(toRemove) = [];
            scaling(toRemove) = [];
            version(toRemove) = [];
            row(toRemove) = [];
            col(toRemove) = [];
            if isempty(offset)
                % If offset is empty there must have been an err (otherwise
                % would have already thrown error).
                rethrow(err)
            end
            pos(1) = nanmean(posAll(:,1));
            errx = nanstd(posAll(:,1));
            pos(2) = nanmean(posAll(:,2));
            erry = nanstd(posAll(:,2));
            err = mean([errx erry]);
            qrInfo = struct('offset',offset,'theta',theta,'scaling',...
                scaling,'row',row,'col',col, 'version',version);
            readInfo = struct('qrInfo',qrInfo,'tform',NaN(3),'err',err,'npoints',0);
            if clean_up && ishandle(f)
                close(f)
            end
        end
        function [pos,readInfo,ax] = enhancedReader(im,varargin)
            % Same input as reader
            % Uses one QR code, and finds all possible neighboring points
            % Will fire up parallel pool to fit circles.
            % err is the average error of the control points position
            % npoints is the number of control points
            % When applying tform, remember it is necessary to add a 1 at
            %    the end of the vector (for the constant term)
            [~,readInfo,ax] = Base.QR.reader(im,varargin{:});
            qrInfo = readInfo.qrInfo;
            i = 1;  % Denote which QR code to use
            [lab,sample] = Base.QR.hone(im,qrInfo(i),ax);
            % Switch world view from ROI to full sample
            s = Base.QR.spacing_between;
            sample(:,1) = sample(:,1) + qrInfo(i).col*s;
            sample(:,2) = sample(:,2) + qrInfo(i).row*s;
            npoints = size(lab,1);
            % Get rotatioin/scaling/translation transformation
            tform = fitgeotrans(lab,sample,'nonreflectivesimilarity');
            approxSample = transformPointsForward(tform,lab);
            err = abs(approxSample(:,1:2)-sample);
            err = mean(sqrt(err(:,1).^2+err(:,2).^2));
            pos = transformPointsForward(tform,[0 0]);   % Get sample frame coordinate at center of lab frame, (0,0)
            readInfo = struct('qrInfo',qrInfo,'tform',tform.invert(),'err',err,'npoints',npoints);
        end
        
        function [row,col,version,legacy_error] = analyze(code)
            pad = Base.QR.pad; %#ok<*PROP>
            vb = Base.QR.vb;
            rb = Base.QR.rb;
            cb = Base.QR.cb;
            cs = Base.QR.cs;
            if isnumeric(code)
                code = num2str(code);
                code(isspace(code))='';
            end
            assert(numel(code)==Base.QR.length,'Code is the wrong size')
            % Make sure pad is correct, then remove
            padVal = num2str(ones(1,numel(pad))*Base.QR.padVal,'%i');
            legacy_error = false;
            if ~strcmp(code(pad),padVal)
                % There was a flaw in some of the generation code, so
                % attempt altering code to "fix" by swapping bit 5 and 6
                if ~strcmp(code([1 6]),padVal)
                    error('Padding bits are incorrect.')
                else
                    legacy_error = true;
                    code([1 6]) = [];
                end
            else
                code(pad) = [];
            end
            p = 1;
            version = bin2dec(code(p:p+vb-1));
            p = p + vb;
            row = bin2dec(code(p:p+rb-1));
            p = p + rb;
            col = bin2dec(code(p:p+cb-1));
            p = p + cb;
            checksum = bin2dec(code(p:p+cs-1));
            % Remove checksum, and test
            code(end-cs+1:end) = [];
            if ~isempty(checksum) && mod(numel(strfind(code,'1')),2^cs)~=checksum
                if legacy_error
                    warning('Checksum failure was after a pad failure and attempt to address the legacy error.')
                end
                error('Checksum failed.')
            end
            if version > 5 && legacy_error
                warning('Had to correct for padding error that SHOULD NOT exist in versions > 5! Tell mpwalsh@mit.edu immediately.');
            end
        end
        [offset,theta,scaling] = findQR(c,conv)
        [c,R] = find_fast(im,conv);
        [code,error] = digitize(image,offset,R,to_plot)
        [offset,theta,scaling] = hone(im,qrInfo,ax);
    end
    
end

