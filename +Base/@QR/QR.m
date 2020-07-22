classdef QR
    % QR Detect and read "QR" codes
    % Common methods:
    %   [pos,readInfo] = reader(im,varargin)
    %   [readInfo] = hone(im,readInfo);
    %   [row,col,version,legacy_error] = analyze(code); code can be
    %       anything that can convert to char vector. Must be 1xBase.QR.length.
    %   handles = plotQRinfo(ax,qrInfo);
    %
    % NOTE: All transformations performed here are nonreflective similar:
    %       rotation, translation and scale only.
    %   While most of the time an inverted QR code won't decode properly,
    %   there are cases where they will! The obvious example is one with
    %   transpose symetry. There are other possible ones that don't have
    %   symmetry but will pass the checksum correctly and yield an
    %   incorrect result. The user must take care in these situations.
    
    properties(Constant)
        % Bit definitions
        length = 25;    % Total length of code
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
        spacing_between = 40;  % um
    end

    %% Main methods
    methods(Static)
        [pos,readInfo,f_debug] = reader(im,varargin)
        [readInfo,f_debug] = hone(im,readInfo,varargin)
        [row,col,version,legacy_error] = analyze(code)
        
        c = findMarkers(im,conv,sensitivity,ax_debug); % Nx2 double
        [QR2pxT,cQR] = findQR(c,conv,markersBase,leg_thresh,angle_thresh,debug_ax) % 1xN affine2d
        [codeOut,p,estimate,posPxs] = digitize(im,unit2pxT,significance,markersPx)
        
        function readInfo = invertReadInfo(readInfo,ax)
            % Given which axes, invert all affine2d transform objects
            % contained in readInfo (returned by Base.QR.reader)
            % ax should be an "indexed axes" - x: 1, y: 2
            assert(isnumeric(ax),...
                sprintf('ax must be a numeric type, not "%s".',class(ax)));
            assert(any(ax==[1,2]),...
                sprintf('ax should be 1 for x or 2 for y. %i not supported.',ax))
            yinv = eye(3); yinv(ax,ax) = -1;
            readInfo.tform.T = yinv * readInfo.tform.T; % "im2QR"
            for j = 1:length(readInfo.qrInfo)
                if isa(readInfo.qrInfo(j).QR2imT,'affine2d')
                    readInfo.qrInfo(j).QR2imT.T = readInfo.qrInfo(j).QR2imT.T * yinv;
                end
            end
        end
    end
    %% Graphics tools
    methods(Static)
        function [c,r] = BasicBlock()
            % Builds position markers for qr sample at 0,0
            % Construct sample frame coordinates for all nearest neighbors
            % Easily plot with: >> viscircles(c,r);
            c = [0,0; Base.QR.spacing,0; 0,Base.QR.spacing];
            r = [0 0 0] + Base.QR.r;
            if Base.QR.NSecondary > 0
                % This is spacing between a single QR's main markers
                dist = Base.QR.spacing/(Base.QR.NSecondary+1);
                p = (1:Base.QR.NSecondary)'.*dist; % generate coords for arb. axis
                z = zeros(Base.QR.NSecondary,1);
                c = [c; [z, p]; [p, z]]; % apply to x axis then y axis
                r = [r, [z; z]' + Base.QR.module_size/4];
            end
        end
        function handles = plotQRinfo(ax,qrInfo,debug)
            % Plot the QR code based on the qrInfo. The value of the
            % bits scatter points correspond to the estimate of the bit
            % value. If no code is supplied, this scatter plot will be
            % omitted. If estimate is NaN, the scatter plot will be
            % binary instead of "gray scale". Red markers indicate an error
            % occured, green indicate success. The blue marker indicates
            % the top left of the code.
            % debug is mainly for internal use. It contains the module (bit) postiions
            % sampled to decide logical bit value as well as various references.
            assert(isvalidax(ax),'Axes must be valid.')
            if nargin < 3
                debug = struct('posPxsIm',NaN(0,2));
            end
            n = length(qrInfo);
            handles = struct('markers',[],'bitSamples',[],'bits',cell(1,n));
            % Construct base QR and bits
            modSize = Base.QR.module_size;  % um
            numMods = sqrt(Base.QR.length);
            [Y,X] = meshgrid(linspace(modSize*numMods,modSize,numMods),...
                linspace(modSize,modSize*numMods,numMods)); % Starts from top left and rasters down
            bitsBase = [X(:), Y(:)]+Base.QR.d-modSize/2;
            markersBase = [0,0;Base.QR.spacing,0;0,Base.QR.spacing];
            for i = 1:n
                posBits = bitsBase;
                posMarkers = markersBase;
                if isempty(qrInfo(i).error) % Use correct QR
                    posBits = posBits + [qrInfo(i).col, qrInfo(i).row].*Base.QR.spacing_between;
                    posMarkers = posMarkers + [qrInfo(i).col, qrInfo(i).row].*Base.QR.spacing_between;
                end
                posBits = transformPointsForward(qrInfo(i).QR2imT,posBits);
                posMarkers = transformPointsForward(qrInfo(i).QR2imT,posMarkers);
                % Draw markers
                if isempty(qrInfo(i).error)
                    colors = zeros(3,3) + [0 1 0]; % green
                else
                    colors = zeros(3,3) + [1 0 0]; % red
                end
                colors(3,:) = [0 0 1]; % blue upper left (last point in list)
                handles(i).markers = scatter(ax,posMarkers(:,1),posMarkers(:,2),...
                    36,colors,'linewidth',2);
                % Draw bit sample positions
                handles(i).bitSamples = scatter(ax,...
                    posBits(1,1)+debug.posPxsIm(:,1),posBits(1,2)+debug.posPxsIm(:,2),10,[0,0,1]); % blue
                % Draw bits based on their estimate
                code = qrInfo(i).estimate;
                if isempty(code)
                    code = false(Base.QR.length,1);
                end
                colors = zeros(Base.QR.length,3) + code;
                handles(i).bits = scatter(ax,posBits(:,1),posBits(:,2),36,colors);
                handles(i).bits.UserData.debug = debug; % Used in tooltip_fn
            end
        end
    end
end

