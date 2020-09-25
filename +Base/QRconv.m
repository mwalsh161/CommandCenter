function [cx, cy, CX, CY, flat, conv, convH, convV, bw] = QRconv(img, ang0, r, l)
    % Convolutional QR detection

    flat = flatten(img);
    [conv, convH, convV] = doConv(flat, ang0, r, l);
    bw = threshold(flat);
    [cx, cy, CX, CY] = findQRs(bw, conv, ang0, r, l);
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

%     imwrite(.5 + fil/max(max(fil))/2, 'fil.png');

    lx = ceil(l*ca);
    ly = ceil(l*sa);

    convH = conv2((img), fil);
    convV = conv2((img), rot90(fil));

    S = size(img);
    X = (1:S(1)) + r;
    Y = (1:S(2)) + r;

    convH = convH(X + invx*ly, Y + invy*lx);
    convV = convV(X + (~invy)*lx, Y + invx*ly);

%     invx*ly
%     invy*lx
%     (~invy)*lx, Y + invx*ly);

    conv = convH.*convH.*convH + convV.*convV.*convV;

    if false
        N = 2;
        M = 3;

        a = subplot(N, M, 4);
        imagesc(convH); set(a,'YDir','normal')
        title('Horizontal Convolution')
        a = subplot(N, M, 5);
        imagesc(convV); set(a,'YDir','normal')
        title('Vertical Convolution')
        a = subplot(N, M, 6);
        imagesc(conv); set(a,'YDir','normal')
%         imagesc(log10(abs(img7)));
        title('Sum of Cubes of Horizontal and Vertical Convolutions')
%         warning()
    end
end

function [cx, cy, CX, CY] = findQRs(bw, conv, ang0, r, l)
    S = size(conv);

    ca0 = cos(ang0);
    sa0 = sin(ang0);

    lxx = l*(sa0+ca0)/2;
    lyy = l*(sa0-ca0)/2;

    XX = repmat(1:S(1),    [S(2) 1]);
    YY = repmat((1:S(2))', [1 S(1)]);


    CC = bwconncomp(conv > max(max(conv))/8);

    NQR = CC.NumObjects;
    cx = NaN(1,NQR);
    cy = NaN(1,NQR);

    for ii = 1:NQR
        cx(ii) = mean(XX(CC.PixelIdxList{ii}));
        cy(ii) = mean(YY(CC.PixelIdxList{ii}));
    end

%     s = regionprops(bw, 'centroid');
%     c = cat(1, s.Centroid);
%     cx = c(:,1) + lxx;
%     cy = c(:,2) + lyy;
%     n = length(c(:,1));

%     plot(cx, cy,'g*')


    pad = abs(l*(sa0+ca0)/2) + 2*r;


    isQR = true(1, NQR);

    bitcoord = .75*(-2:2)/6.25;

    bity = repmat(-bitcoord,  [5 1]);
    bitx = repmat(-bitcoord', [1 5]);

    lx0 = l*ca0;
    ly0 = l*sa0;

    A = l * [ca0, sa0; -sa0, ca0];

    BITX = A(1,1) * bitx + A(2,1) * bity;
    BITY = A(1,2) * bitx + A(2,2) * bity;

    CX = NaN*cx;
    CY = NaN*cx;

%     for ii = 1:n
%         plot(c(ii,1) + [0 lx0 ly0+lx0 ly0 0], c(ii,2) + [0 ly0 ly0-lx0 -lx0 0], 'r');
%     end

    for ii = 1:NQR
        if cx(ii) + lxx < pad || cx(ii) + lxx > S(2) - pad || cy(ii) + lyy < pad || cy(ii) + lyy > S(1) - pad
            isQR(ii) = false;   % QR is clipping edge of screen and decoding should not be attempted.
        else
            m = NaN(5);

            for jj = 1:length(bitcoord)         % TODO: Replace for loop with one-liner.
                for kk = 1:length(bitcoord)
                    m(kk,jj) = bw(round(BITY(jj,kk) + cy(ii) + lyy), round(BITX(jj,kk) + cx(ii) + lxx));
                end
            end

            [CX(ii), CY(ii), ~, isQR(ii)] = interpretQR(m(:));

            if false && isQR(ii)
%                 plot(cx(ii) + [0 lx0 ly0+lx0 ly0 0], cy(ii) + [0 ly0 ly0-lx0 -lx0 0], 'r');
%                 plot(BITX + cx(ii), BITY + cy(ii), 'bo');
%
%                 ll = 1;
%                 for jj = 1:length(bitcoord)
%                     for kk = 1:length(bitcoord)
%                         text(cx(ii)+BITX(jj,kk), cy(ii)+BITY(jj,kk), num2str(ll), 'color', 'g');
%                         ll = ll + 1;
%                     end
%                 end

%                 text(cx(ii)-12, cy(ii), { ['[' num2str(CX(ii)) ','], [' ' num2str(CY(ii)) ']'] }, 'color', 'r');
            end
        end
    end

%     assert(sum(isQR) <= 4, 'Don''t expect more than four QR codes within a single field of view.');

%     CX
%     CY
%     isQR

    CX(~isQR) = [];
    CY(~isQR) = [];
    cx(~isQR) = [];
    cy(~isQR) = [];

    CX


end

function [CX, CY, version, checksum0] = interpretQR(m)
%     pad = Base.QR.pad; %#ok<*PROP>
%     vb = Base.QR.vb;
%     rb = Base.QR.rb;
%     cb = Base.QR.cb;
%     cs = Base.QR.cs;

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

%     version
%     CX
%     CY
%     checksum

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

% function img2 = resize(img)
%     img2 = imresize(img, .25, 'bilinear');
% end

function img3 = threshold(img)
    img3 = imbinarize(img);
end

function img2 = flatten(img)
    img2 = imgaussfilt(img,10) - imgaussfilt(img,1);
end
