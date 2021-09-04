function [v, V, options_fit, stages] = QRconv(img, options_guess, QR_parameters)
    % QRconv finds 
    % img is a NxM image.
    % options_guess is a struct of the same format as options_fit to 
    % struct('ang', 'calibration', 'X_expected', 'Y_expected');
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
    
    ang0 = options_guess.ang;
    r = QR_parameters.r / options_guess.calibration;
    l = QR_parameters.l / options_guess.calibration;
    options_guess.d = QR_parameters.d;
    
    if isfield(options_guess, 'X_expected') && isfield(options_guess, 'Y_expected')
        V_expected = [options_guess.X_expected; options_guess.Y_expected];
    else
        V_expected = [NaN; NaN];
    end
    
    % Step 1: remove gradients 
    flat = flatten(img);
    
    % Step 2: perform a convolutional filter to identify QR candidates
    [conv, convH, convV] = doConv(flat, ang0, r, l);
    
    % Step 3: generate a logical image to determine the code of the QR code.
    bw = threshold(flat);
    
    stages = struct('flat', flat, 'conv', conv, 'convH', convH, 'convV', convV, 'bw', bw);
    
    % Step 4: using the candidate locations, return the location of QR codes.
    [cx, cy, CX, CY] = findQRs(bw, conv, ang0, r, l,  V_expected);
    
    v = [cx; cy];
    V = [CX; CY];
     
    if isempty(V) || all(isnan(V(:)))
        M = [[NaN NaN]; [NaN NaN]];
        b = [NaN; NaN];
        
        options_guess.Vcen = b;
        options_guess.M = M;
        options_guess.b = b;
        options_guess.M2 = M;
        options_guess.b2 = b;
        options_guess.outliers = false(1, size(V, 2));
        options_fit = options_guess;
        return
    end
    
    % Step 5: fit a coordinate system to the positions of our QR codes.
    [M, b, M2, b2, outliers] = majorityVoteCoordinateFit(v, V, options_guess);
    
    if ~any(isnan([M(:); b(:)]))
        Vcen = invaffine((size(img)/2)', M, b);
    else
        Vcen = [NaN; NaN];
    end
    
    xaxis = affine([1;0], M, [0; 0]);
    if xaxis(1) == 0
        ang1 = (pi/2) + pi * (xaxis(2) < 0);
    else
        ang1 = atan(xaxis(2)/xaxis(1));
    end
    
    call = options_guess.d / norm(xaxis);
    
    options_fit = struct('ang', ang1, 'calibration', call, 'Vcen', Vcen, 'M', M, 'b', b, 'M2', M2, 'b2', b2, 'outliers', outliers);
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
end
function [cx, cy, CX, CY] = findQRs(bw, conv, ang0, r, l, V_expected)
    S = size(conv);

    ca0 = cos(ang0);
    sa0 = sin(ang0);

    lxx = l*(sa0+ca0)/2;
    lyy = l*(sa0-ca0)/2;
    
    [XX, YY] = meshgrid(1:S(1), 1:S(2));

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
    
    m_vectors = NaN(25, NQR);

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
            
            if ~isQR(ii) && ~any(isnan(V_expected))
                dist = 2;
                
                for jj = 1:25
                    m_ = m(:);
                    m_(jj) = ~m_(jj);
                    [CX_, CY_, ~, isQR_] = interpretQR(m_(:));
                    
                    if isQR_
                        dist_ = norm([CX_; CY_] - V_expected);
                        
                        if dist_ < dist 
                            CX(ii) = CX_;
                            CY(ii) = CY_;
                            isQR(ii) = true;
                            dist = dist_;
                        end
                    end
                end
            end
            
            m_vectors(:,ii) = m(:);
            
            if CX(ii) == 0 && CY(ii) == 0   % Empty bits reads as [0,0] QR, so most [0,0] are false positives.
                isQR(ii) = false;
            end
        end
    end

    CX(~isQR) = NaN;
    CY(~isQR) = NaN;
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
function [M, b, M2, b2, outliers] = majorityVoteCoordinateFit(v, V, options_guess)
    c = cos(options_guess.ang);
    s = sin(options_guess.ang);
    M_guess = [[s, c]; [-c, s]] / options_guess.calibration * options_guess.d;
    
    % The positions and labels of candidate QR codes define candidate coordinate systems.
    % We want to find which candidate is correct.
    b_guesses = v - M_guess * V;
    
    duplicates = false(1, size(b_guesses,2));
    
    for ii = 1:size(V,2)
        dduplicates = V(1,:) == V(1, ii) & V(2,:) == V(2, ii);
        
        if sum(dduplicates) > 1
            duplicates = duplicates | dduplicates;
        end
    end
    
    if isfield(options_guess, 'X_expected') && isfield(options_guess, 'Y_expected')
        V_expected = [options_guess.X_expected; options_guess.Y_expected];
    else
        V_expected = [NaN; NaN];
    end
    b_expected = [256; 256] - M_guess * V_expected;     % Make not camera specific!
    
    % Setup variables that we will change as we loop.
    mostvotes = 1;
    b_guess = [NaN; NaN];
    outliers = true(1, size(b_guesses,2));
    dist = 3*options_guess.d;
    
    % Radius within which b guesses are considered the same guess.
    R = options_guess.d;
    
    for ii = 1:size(b_guesses,2)                                % For every candidate...
        if ~any(isnan(b_guesses(:, ii))) && ~duplicates(ii)
            votes = sum((b_guesses - b_guesses(:, ii)).^2) < R*R & ~duplicates;   % How many other candidates agree?
            
            if mostvotes <= sum(votes)                              % If this is a new record...
                b_guess = mean(b_guesses(:, votes), 2);             % Estimate b as the average.
                dist_ = norm(b_guess - b_expected);
                
                if sum(votes) > 1 || dist_ < dist
                    dist = dist_;
                    mostvotes = sum(votes);                             % Record the record.
                    outliers = ~votes;                                  % Record the candidates that were outside.
                end
            end
        end
    end
    
    if sum(~outliers) < 2 && ~any(isnan(b_expected)) && norm(b_guess - b_expected) > 3*options_guess.d
        outliers(:) = true;
    end
    
%     if mostvotes
%         
%     end
    
    % Trim the outliers.
    v_trim = v(:, ~outliers);
    V_trim = V(:, ~outliers);

    % Fit the candidates to a translation b using the guess transformation.
%     fun = @(p)( leastsquares(v_trim, V_trim, M_guess, p') );
%     p_guess = b_guess';
%     p = fminsearch(fun, p_guess, struct('TolFun', 1, 'TolX', 1e-1));
%     
    
    if isempty(v_trim)
        M = [[NaN NaN]; [NaN NaN]];
        b = [NaN; NaN];
        
        M2 = M;
        b2 = b;
        
        return;
    end
    
    M2 = M_guess;
    b2 = b_guess;

    % Fit the candidates fully to an affine transformation.
    fun = @(p)( leastsquares(v_trim, V_trim, [p(1:2)', p(3:4)'], p(5:6)') );
    p_guess = [M_guess(:); b_guess]';
    p_full = fminsearch(fun, p_guess, struct('TolFun', 1, 'TolX', 1e-1));
    
    M = [p_full(1:2)', p_full(3:4)'];
    b = p_full(5:6)';
    
    % Fit the candidates fully to a rigid motion plus a scale.
%     fun = @(p)( leastsquares(v_trim, V_trim, [p(1:2)', p(3:4)'], p(5:6)') );
%     p_guess = [M_guess(:); b_guess]';
%     p_full = fminsearch(fun, p_guess);
end

% function img = resize(img)
%     img = imresize(img, .25, 'bilinear');
% end
function img = threshold(img)
    img = imbinarize(img);
end
function img = flatten(img)
%     img = imgaussfilt(img,10) - imgaussfilt(img,1);
% class(imgaussfilt(img,10))
    img = imgaussfilt(img,10) - img;
%     img = imgaussfilt(img,10) - imgaussfilt(img,2);
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
    v = M \ (v_ - b);
end
function fom = leastsquares(v_, v, M, b)
    fom = sum(sum((v_ - affine(v, M, b)).^2));
end