function [v, V, options_fit, stages] = QRconv(img, options_guess, QR_parameters)
    % QRconv finds 
    % v and V are arrays of column vectors (2xN) of the same size. v are
    % positions of candidate QR codes in the coordinate system of the image
    % img, while V are the corresponding positons in QR space. If a
    % candidate does not pass the checksum, [NaN; NaN] is returned for V.
    % Returns transform from QR-space V to position-space v according to 
    %   v = M * V + b
    % options_guess
    
    % Convolutional QR detection
    if nargin < 3
        QR_parameters = struct('r', .3, 'l', 6.25, 'd', 40);
    end
    
    ang0 = options_guess.ang
    r = QR_parameters.r * options_guess.calibration;
    l = QR_parameters.r * options_guess.calibration;
    
    % Step 1: remove gradients 
    flat = flatten(img);
    
    % Step 2: perform a convolutional filter to identify QR candidates
    [conv, convH, convV] = doConv(flat, ang0, r, l);
    
    % Step 3: generate a logical image to determine the code of the QR code.
    bw = threshold(flat);
    
    % Step 4: using the candidate locations, return the location of QR codes.
    [cx, cy, CX, CY] = findQRs(bw, conv, ang0, r, l);
    
    v = [cx; cy];
    V = [CX; CY];
    
    % Step 5: fit a coordinate system to the positions of our QR codes.
    [M, b] = majorityVoteCoordinateFit(v, V, options_guess);
    
    xaxis = invaffine([1;0], M, b);
    if xaxis(1) == 0
        ang1 = (pi/2) + pi * (xaxis(2) < 0);
    else
        ang1 = atan(xaxis(2)/xaxis(1));
    end
    
    stages = struct('flat', flat, 'conv', conv, 'convH', convH, 'convV', convV, 'bw', bw);
    options_fit = struct('ang', ang1, 'calibration', calibration)
end

function [conv, convH, convV] = doConv(img, ang0, r, l)
    r = ceil(r);

    ang = mod(ang0, pi);

    invx = sin(ang0) > 0;
    invy = cos(ang0) > 0;

    ca = cos(ang);
    sa = sin(ang);

    lx = ceil(l*ca);
    ly = ceil(l*sa);

    X = -r:lx+r;
    Y = -r:ly+r;

    XX = repmat(X, [length(Y) 1]);
    YY = repmat(Y', [1 length(X)]);

    B = .5;
    sp = 2;
    sn = 1;

    % 
    fil =  B*circleFunc(XX, YY, 0,       0,      r) ...
        - sn*circleFunc(XX, YY, 1*lx/8,  1*ly/8, r/3) ...
        + sp*circleFunc(XX, YY, lx/4,    ly/4,   r/3) ...
        - sn*circleFunc(XX, YY, 3*lx/8,  3*ly/8, r/3) ...
        + sp*circleFunc(XX, YY, lx/2,    ly/2,   r/3) ...
        - sn*circleFunc(XX, YY, 5*lx/8,  5*ly/8, r/3) ...
        + sp*circleFunc(XX, YY, 3*lx/4,  3*ly/4, r/3) ...
        - sn*circleFunc(XX, YY, 7*lx/8,  7*ly/8, r/3) ...
        + B*circleFunc(XX, YY, lx,      ly,     r);

%     fil = imgaussfilt(fil, 1);

    % Normalize
    S1 = size(fil);
    fil = fil - sum(sum(fil))/S1(1)/S1(2);
    fil = fil / sqrt(sum(sum(fil.^2)));

    % Uncomment this line to get a better idea of what the filter looks like.
%     imwrite(.5 + fil/max(max(fil))/2, 'fil.png');

    lx = ceil(l*ca);
    ly = ceil(l*sa);

    convH = conv2(img, fil);
    convV = conv2(img, rot90(fil));

    S = size(img);
    X = (1:S(1)) + r;
    Y = (1:S(2)) + r;

    convH = convH(X + invx*ly, Y + invy*lx);
    convV = convV(X + (~invy)*lx, Y + invx*ly);

    conv = convH.*convH.*convH + convV.*convV.*convV;
%     if false
%         N = 2;
%         M = 3;
% 
%         a = subplot(N, M, 4);
%         imagesc(convH); set(a,'YDir','normal')
%         title('Horizontal Convolution')
%         a = subplot(N, M, 5);
%         imagesc(convV); set(a,'YDir','normal')
%         title('Vertical Convolution')
%         a = subplot(N, M, 6);
%         imagesc(conv); set(a,'YDir','normal')
% %         imagesc(log10(abs(img7)));
%         title('Sum of Cubes of Horizontal and Vertical Convolutions')
% %         warning()
%     end
end
function [cx, cy, CX, CY] = findQRs(bw, conv, ang0, r, l)
    S = size(conv);

    ca0 = cos(ang0);
    sa0 = sin(ang0);

    lxx = l*(sa0+ca0)/2;
    lyy = l*(sa0-ca0)/2;
    
    [XX, YY] = meshgrid(1:S(1), 1:S(2));

%     XX = repmat(1:S(1),    [S(2) 1]);
%     YY = repmat((1:S(2))', [1 S(1)]);

    CC = bwconncomp(conv > max(max(conv))/8);

    NQR = CC.NumObjects;
    cx = NaN(1,NQR);
    cy = NaN(1,NQR);

    for ii = 1:NQR
        cx(ii) = mean(XX(CC.PixelIdxList{ii}));
        cy(ii) = mean(YY(CC.PixelIdxList{ii}));
    end

    pad = abs(l*(sa0+ca0)/2) + 2*r;

    isQR = true(1, NQR);
    
    bitcoord = .75*(-2:2)/6.25;
    % Replace with meshgrid?
    bity = repmat(-bitcoord,  [5 1]);
    bitx = repmat(-bitcoord', [1 5]);

    A = l * [ca0, sa0; -sa0, ca0];

    BITX = A(1,1) * bitx + A(2,1) * bity;
    BITY = A(1,2) * bitx + A(2,2) * bity;

    CX = NaN*cx;
    CY = NaN*cx;

    for ii = 1:NQR
        if cx(ii) + lxx < pad || cx(ii) + lxx > S(2) - pad || cy(ii) + lyy < pad || cy(ii) + lyy > S(1) - pad
            isQR(ii) = false;   % QR is clipping the edge of screen and decoding should not be attempted.
        else
            m = NaN(5);

            for jj = 1:length(bitcoord)         % TODO: Replace for loop with one-liner.
                for kk = 1:length(bitcoord)
                    m(kk,jj) = bw(round(BITY(jj,kk) + cy(ii) + lyy), round(BITX(jj,kk) + cx(ii) + lxx));
                end
            end

            [CX(ii), CY(ii), ~, isQR(ii)] = interpretQR(m(:));

            if false && isQR(ii)
            end
        end
    end

    CX(~isQR) = NaN;
    CY(~isQR) = NaN;
    cx(~isQR) = NaN;
    cy(~isQR) = NaN;
end
function [CX, CY, version, checksum0] = interpretQR(m)
    % From the code contained in m, attempt to read information.

    length = 25;    % Total length of code
    pad = [1 6]; % Pad locations of bits (indexed from 1)
    vb = 4;   % Version bits
    rb = 8;   % Number of bits to encode the row
    cb = 8;   % Number of bits to encode the col
    cs = 3;   % Checksum

    assert(numel(m) == length, 'm is the wrong size')

    if size(m, 1) > 1
        m = m';
    end

    b = 2 .^ (0:7);
    m(pad) = [];
    p = 1;

    version =   sum(m(p:p+vb-1) .* b(vb:-1:1)); p = p + vb;
    CY =        sum(m(p:p+rb-1) .* b(rb:-1:1)); p = p + rb;
    CX =        sum(m(p:p+cb-1) .* b(cb:-1:1)); p = p + cb;
    checksum = 	sum(m(p:p+cs-1) .* b(cs:-1:1));

    % Remove checksum, and test
    m(end-cs+1:end) = [];

    checksum0 = false;
    if ~isempty(checksum)
        checksum0 = mod(sum(m), 2^cs) == checksum;
    end
end
function cir = circleFunc(XX, YY, x0, y0, r)
    cir = (XX - x0).^2 + (YY - y0).^2 < r^2;
end
function [M, b, b2] = majorityVoteCoordinateFit(v, V, options_guess)
    c = cos(options_guess.ang);
    s = sin(options_guess.ang);
    M_guess = [[c, s]; [-s, c]];
    % Need to multiply this by calibration
    
    % The positions and labels of candidate QR codes define candidate coordinate systems.
    % We want to find which candidate is correct.
    b_guesses = v - M_guess * V;
    
    % Setup variables that we will change as we loop.
    mostvotes = 1;
    b_guess = [];
    outliers = [];
    
    % Radius within which b guesses are considered the same guess.
    R = 10;
    
    for ii = 1:size(b_guesses,2)                                % For every candidate...
        votes = sum((b_guesses - b_guesses(:, ii)).^2) < R;     % How many other candidates agree?
        if mostvotes < sum(votes)                               % If this is a new record...
            mostvotes = sum(votes);                             % Record the record.
            b_guess = mean(b_guesses(:, votes), 2);             % And estimate b as the average.
            outliers = ~votes;                                  % Record the candidates that were outside.
        end
    end
    
    % Trim the outliers.
    v_trim = v(:, ~outliers);
    V_trim = V(:, ~outliers);

    % Fit the candidates to a translation b using the guess transformation.
    fun = @(p)( leastsquares(v_trim, V_trim, M_guess, p(5:6)') );
    p_guess = b_guess';
    p = fminsearch(fun, p_guess);
    
    b2 = p';

    % Fit the candidates fully to an affine transformation.
    fun = @(p)( leastsquares(v_trim, V_trim, [p(1:2); p(3:4)], p(5:6)') );
    p_guess = [M_guess(:) b_guess];
    p_full = fminsearch(fun, p_guess);
    
    M = [p_full(1:2); p_full(3:4)];
    b = p_full(5:6)';
end

% function img = resize(img)
%     img = imresize(img, .25, 'bilinear');
% end
function img = threshold(img)
    img = imbinarize(img);
end
function img = flatten(img)
    img = imgaussfilt(img,10) - imgaussfilt(img,1);
end



function v_ = affine(v, M, b)
    % v and v_ are either column vectors (2x1) or arrays of column vectors (2xN) of the same size
    % M is a matrix (2x2)
    % b is a column vector (2x1)
    v_ = M * v + b;
end

function v = invaffine(v_, M, b)
    % v and v_ are either column vectors (2x1) or arrays of column vectors (2xN) of the same size
    % M is a matrix (2x2)
    % b is a column vector (2x1)
    v = inv(M) * (v_ - b);
end

function fom = leastsquares(v_, v, M, b)
    fom = sum(sum((v_ - affine(v, M, b)).^2));
end