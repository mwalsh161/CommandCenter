classdef QR
    % QR Detect and read "QR" codes
    % Two main methods: READER and ENHANCEDREADER. reader does not use the
    % extra alignment markers and does not fit the main markers precicely.
    % enhancedReader does all of that (takes much longer).  See method
    % definition for more details.
    %   [pos,qrInfo] = reader(im,varargin)
    %   [pos,tform,err,npoints,qrInfo] = enhancedReader([SAME AS READER])
    
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
        diffraction_limit = 0.1; % um (used when fitting in enhancedReader)
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
        function [pos, err] = estimatePos(readInfos)
            % ESTIMATEPOS Returns an estimated QR position for the (0,0)
            % coordinate in the image. It will take as many readInfo
            % structs as there are QR codes detected.
     %       pos = [[qrInfo.col]',[qrInfo.row]']*Base.QR.spacing_between; % QR coord
     %       pos = % pixels?
     %       pos = % sample coord
            pos = [NaN,NaN];
            err = [NaN,NaN];
        end
        function [pos,readInfo,f_debug] = reader(im,varargin)
            % READER Returns QR info if the 3 larger markers are found
            %   The image should be corrected for flat illumination already.
            % Inputs; brackets indicate name,value optional pair:
            %   im: a SmartImage info struct (reader uses the "image" and
            %       "ROI" fields
            %   [sensitivity]: (5) n standard deviations above median when
            %       choosing the binary threshold for finding QR markers
            %   [leg_len_thresh]: (0.05) 1 - ratio of length of each leg
            %   [angle_thresh]: (0.1) Error from pi/2 between legs
            %   [debug]: (false) Creates a figure with relevant graphics at each step
            % Outputs:
            %   pos: The estimated position of the image's (0,0) coordinate in
            %       the QR frame. Based on all QRs detected.
            %   readInfo: The details about the result. Fields:
            %       qrInfo*: an array of structs
            %       tform: the tform that incorporates all QRs found ("average" of qrInfo.QR2imT)
            %       err: the error as a result of the average in (x,y)
            %       npoints: n points used to calculate tform. Always zero
            %           for this function. Reserved for enhancedReader.
            %   f_debug: either empty gobjects or the figure handle if debug is true
            %   *qrInfo includes:
            %       row, col and version: the encoded QR info. If error is
            %           not empty, row and col are empty doubles and
            %           version is NaN.
            %       error: An empty MException, or the MException if one
            %           occured during decoding
            %       QR2imT: Affine transform QR(x,y)[um] -> image(x,y)[um].*
            %       * If error is not empty, these will be from the root
            %       (0,0) QR code instead of the one encoded.
            
            assert(size(im.image,3)==1,'Image must be gray scale.')
            x = im.ROI(1,:);
            y = im.ROI(2,:);
            im = double(im.image); % Necessary for some filter operations
            p = inputParser;
            addParameter(p,'sensitivity',5,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
            addParameter(p,'leg_len_thresh',0.05,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
            addParameter(p,'angle_thresh',0.1,@(a)validateattributes(a,{'numeric'},{'scalar','nonnegative'}));
            addParameter(p,'debug',false,@(a)validateattributes(a,{'logical'},{'scalar'}));
            parse(p,varargin{:});
            p = p.Results;
            
            ax_debug = gobjects(1,4);
            f_debug = gobjects(1);
            if p.debug
                f_debug = figure('name','QR.reader','units','normalized',...
                    'position',[0 0 1 1]);
                colormap(f_debug,'gray');
                for i = 1:length(ax_debug)
                    ax_debug(i) = subplot(2,2,i,'parent',f_debug);
                    hold(ax_debug(i),'on');
                    axis(ax_debug(i),'image');
                end
                set(ax_debug,'ydir','normal');
                imagesc(ax_debug(1),x,y,im);
                title(ax_debug(1),sprintf('Original (%i x %i)',size(im,2),size(im,1)))
            end
            
            % Resize to square px
            conv = [diff(x)/(size(im,2)-1),diff(y)/(size(im,1)-1)]; % um/pixel
            conv = max(conv); % Reduce to worst resolution
            im = imresize(im,round([diff(y),diff(x)]/conv)+1);
            if p.debug
                imagesc(ax_debug(2),im);
                title(ax_debug(2),sprintf('Square px (%i x %i)',size(im,2),size(im,1)))
            end
            
            % Find all relevent QRs
            marker_cands = Base.QR.findMarkers(im,conv,p.sensitivity,ax_debug(3:4)); % Nx2 double
            markersBase = [0,0;Base.QR.spacing,0;0,Base.QR.spacing]; % Markers base location (root QR)
            QR2pxT = Base.QR.findQR(marker_cands,conv,markersBase,...
                                    p.leg_len_thresh,p.angle_thresh,...
                                    ax_debug(3:4)); % 1xN affine2d
            % Note, QR2pxT is not returned because it refers to the resized image (square pixels)

            % Go through and attempt to decode QR codes
            nQRs = length(QR2pxT);
            qrInfo = struct('row',[],'col',[],'version',[],...
                            'QR2imT',[],'error',cell(1,nQRs));
            for i = 1:nQRs
                markersPx = transformPointsForward(QR2pxT(i), markersBase);
                markersIm = (markersPx - 1).*conv + [x(1), y(1)];
                try
                    [code] = Base.QR.digitize(im,QR2pxT(i),ax_debug(2));
                    [qrInfo(i).row,...
                     qrInfo(i).col,...
                     qrInfo(i).version] = Base.QR.analyze(code);
                    qrInfo(i).error = MException.empty();
                    % Calculate QR2imT both being in real coords (no more pixel references)
                    markersAct = markersBase + [qrInfo(i).col, qrInfo(i).row].*Base.QR.spacing_between;
                    qrInfo(i).QR2imT = fitgeotrans(markersAct, markersIm,'nonreflectivesimilarity');
                    markers_c = 'g';
                catch err
                    qrInfo(i).row = [];
                    qrInfo(i).col = [];
                    qrInfo(i).version = NaN;
                    qrInfo(i).error = err;
                    % Note this is the QR at (0,0)
                    qrInfo(i).QR2imT = fitgeotrans(markersBase, markersIm,'nonreflectivesimilarity');
                    markers_c = 'r';
                end
                if p.debug
                    plot(ax_debug(2),markersPx(:,1),markersPx(:,2),[markers_c 'o'],'LineWidth',2);
                end
            end
            [pos, err] = Base.QR.estimatePos(qrInfo);
            readInfo = struct('qrInfo',qrInfo,'tform',affine2d.empty(0),'err',err,'npoints',0);
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
            if ~ischar(code)
                try
                    code = num2str(code,'%i');
                catch
                    error('Failed to convert type ''%'' to char array.',class(code))
                end
            end
            assert(numel(code)==Base.QR.length,'Code is the wrong size')
            % Make sure pad is correct, then remove
            padVal = num2str(ones(1,numel(Base.QR.pad))*Base.QR.padVal,'%i');
            legacy_error = false;
            if ~strcmp(code(Base.QR.pad),padVal)
                % There was a flaw in some of the generation code, so
                % attempt altering code to "fix" by swapping bit 5 and 6
                assert(strcmp(code([1 6]),padVal),'Padding bits are incorrect.')
                legacy_error = true;
                code([1 6]) = [];
            else
                code(Base.QR.pad) = [];
            end
            p = 1; % Pointer into code
            version = decode(Base.QR.vb,'version');
            row = decode(Base.QR.rb,'row');
            col = decode(Base.QR.cb,'column');
            checksum = decode(Base.QR.cs,'checksum');
            % Remove checksum, and test
            code(end-Base.QR.cs+1:end) = [];
            observed_checksum = mod(sum(code=='1'),2^Base.QR.cs);
            if observed_checksum ~= checksum
                if legacy_error
                    warning('Checksum failure was after a pad failure and attempt to address the legacy error.')
                end
                error('Checksum failed.')
            end
            if version > 5 && legacy_error
                warning('Had to correct for padding error that SHOULD NOT exist in versions > 5! Tell mpwalsh@mit.edu immediately.');
            end
            % Helper function to decode and error check
            function val = decode(n,name)
                val = bin2dec(code(p:p + n - 1));
                assert(~isempty(val),...
                    sprintf('No %s decoded, check Base.QR constants for consistency.',name));
                p = p + n;
            end
        end
        
        c = findMarkers(im,conv,sensitivity,ax_debug); % Nx2 double
        QR2pxT = findQR(c,conv,markersBase,leg_thresh,angle_thresh,debug_ax) % 1xN affine2d
        code = digitize(image,QR2pxT,ax_debug) % 1xBase.QR.length char
        [offset,theta,scaling] = hone(im,qrInfo,ax);
    end
    
end

