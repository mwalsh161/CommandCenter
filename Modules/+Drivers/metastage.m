classdef metastage < handle % Modules.Driver

    % GENERAL ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
    properties
        coarse_x =      []; %Prefs.Pointer();
        fine_x =        []; %Prefs.Pointer();
        
        coarse_y =      []; %Prefs.Pointer();
        fine_y =        []; %Prefs.Pointer();
        
        coarse_z =      []; %Prefs.Pointer();
        fine_z =        []; %Prefs.Pointer();
    end
    
    properties (GetObservable, SetObservable)
        image = Prefs.ModuleInstance('inherits', {'Modules.Imaging'}, 'set', 'set_image');
        
        X = Prefs.Double(NaN, 'allow_nan', true, 'readonly', true);
        Y = Prefs.Double(NaN, 'allow_nan', true, 'readonly', true);
        
        target_X = Prefs.Double(NaN, 'set', 'set_position', 'allow_nan', true);
        target_Y = Prefs.Double(NaN, 'set', 'set_position', 'allow_nan', true);
        
%         target = Prefs.Button('name', 'target', 'string', 'Go!');
        targeting = Prefs.Boolean(false, 'set', 'target');
    end
    properties
        graphics = [];
    end
    
    methods(Static)
        function obj = instance()
            obj = Drivers.metastage();
%             mlock;
%             persistent Objects
%             if isempty(Objects)
%                 Objects = Drivers.ArduinoServo.empty(1,0);
%             end
%             [~,resolvedIP] = resolvehost(host);
%             for i = 1:length(Objects)
%                 if isvalid(Objects(i)) && isequal({resolvedIP, pin}, Objects(i).singleton_id)
%                     obj = Objects(i);
%                     return
%                 end
%             end
%             obj = Drivers.metastage();
%             obj.singleton_id = [];
%             Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = metastage()
            obj.graphics.figure = figure('Visible', 'off');
            obj.graphics.axes = axes(obj.graphics.figure);
        end
    end
    
    % FOCUS ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
    properties
%         focusfigure
    end
    
    methods
        function success = focusSmart(obj)
            obj.image.snapImage();
            
            success = true;
            
            if obj.image.N > 4
                disp('Detected more than four QR codes. Need to add better checks to resolve this.')
            elseif obj.image.N == 4     % All good, probs. Maybe add an option for precise focus.
                
            elseif obj.image.N == 3     % Do a local focus with only a few frames. 
                success = obj.focus(7+6, 1.2);
            elseif obj.image.N == 2     % Do a local focus with a few more frames.
                success = obj.focus(9+8, 1.6);
            else                        % Do a larger local focus.
                success = obj.focus(15+14, 2.8);
            end
        end
        function success = focus(obj, N, zspan, isfine)
            if nargin < 4
                isfine = true;
            end
            if nargin < 3
                zspan = 2;
            end
            if nargin < 2
                N = 11;
            end
            
            dZ = linspace(-zspan/2, zspan/2, N);
            DZ = abs(mean(diff(dZ)));
            
            if isfine
                zcen =  (obj.fine_z.max + obj.fine_z.min)/2;
                zrange = obj.fine_z.max - obj.fine_z.min;
                zbase =  obj.fine_z.read();
                    
                if abs(zbase - zcen) > .3*zrange                % If fine is about to exceed bounds ...
                    ramp(obj.fine_z, zbase, zcen, DZ/4);        % Recenter...

                    obj.focus(21, 40e-3, false);                % Focus coarse (dangerous, but probs fine).
                end
            end
            
            if isfine
                zbase = obj.fine_z.read();
            else
                zbase = obj.coarse_z.read();
            end
            
            metric1 = NaN(1, length(dZ));
            metric2 = NaN(1, length(dZ));
            
            if isfine
                ramp(obj.fine_z, zbase, zbase + min(dZ), DZ/4); % Ramp to the starting point.
            end
            
            % Plot sharpness and #QRs.
            axes(obj.graphics.axes);
            
            yyaxis left;
            p1 = plot(zbase + dZ, metric1);
            ylabel('~Sharpness');
            
            yyaxis right;
            p2 = plot(zbase + dZ, metric2);
            ylabel('Number of QRs Detected');
            
            if isfine
                xlabel(obj.fine_z.get_label());
            else
                xlabel(obj.coarse_z.get_label());
            end
            
            % Sweep over Z, recording 'focus metrics' at every step
            for ii = 1:length(dZ)
                if isfine
                    obj.fine_z.writ(zbase + dZ(ii) - DZ/2);
                    obj.fine_z.writ(zbase + dZ(ii));
                else
                    obj.coarse_z.writ(zbase + dZ(ii));
                end
                pause(.05);
                
                img = obj.image.snapImage();
                
                metric1(ii) = sharpness(img);           % Image sharpness
                metric2(ii) = obj.image.N;              % QR detection confidence (num QRs)
                
                % Should also use X & Y reasonability as a metric.
%                 obj.image.X
%                 obj.image.Y
                
                % Give the user an idea of what's happening by plotting.
                p1.YData = metric1;
                p2.YData = metric2;
                
                switch obj.graphics.figure.Visible
                    case 'off'
                        obj.graphics.figure.Visible = 'on';
                end
            end
            
            success = max(metric2) > 0;     % Return success if we found at least one QR...
            
            if success      % If success, return the Z where the most QRs were legible.
                if max(metric2) == 1
                    zfin = zbase + mean(dZ(metric1 > (max(metric1) + min(metric1))/2));
                else
                    zfin = zbase + mean(dZ(metric2 == max(metric2)));
                end
            else            % If no QRs were found, return to the starting point.
                zfin = zbase;
            end
            
            % Ramp to the desired final z.
            if isfine
                ramp(obj.fine_z, zbase + max(dZ), zbase + min(dZ),  DZ/4); % Ramp to the starting point.
                ramp(obj.fine_z, zbase + min(dZ), zfin,             DZ/4); % Ramp to the desired value.
            else
                obj.coarse_z.writ(zfin);
            end

            pause(.2);
            
            % Take a snapshot at the target Z for the user to examine the result. (remove?)
            img = obj.image.snapImage();
        end
    end
    
    % CALIBRATION ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
    properties
        % Matrices to tranform postion-space to QR-space.
        calibration_coarse      = [[NaN, NaN]; [NaN, NaN]];
        calibration_fine        = [[NaN, NaN]; [NaN, NaN]];
    end
    
    methods
        function calibrate(obj)
            if ~obj.focus(11, 2)
                disp('Focus onto QR codes was not successful. Try moving to an area with legible QR codes.');
                return
            end
            
            for a = 1:4     % For each of the four axes that require calibration ...
                switch a    % Grab the object.
                    case 1
                        pref = obj.coarse_x;    %obj.get_meta_pref('coarse_x');
                    case 2
                        pref = obj.fine_x;      %obj.get_meta_pref('fine_x');
                    case 3
                        pref = obj.coarse_y;    %obj.get_meta_pref('coarse_y');
                    case 4
                        pref = obj.fine_y;      %obj.get_meta_pref('fine_y');
                end
                
                isfine = ~mod(a, 2);
                
                step = 1e-3;    % Change these step values to look for something hardware-specific!
                if isfine
                    step = .1;
                end

                positions = 0:10;
                base = pref.read();
                Vs = NaN(2, length(positions));
                kk = 1;
                
                delete(obj.graphics.axes);
                obj.graphics.axes = axes(obj.graphics.figure, 'DataAspectRatio', [1 1 1]);

                for pp = positions  % Successively move from the current postion.
                    pref.writ(base + pp * step);
                    pause(.2);
                    if ~isfine
                        pause(1);
                    end

                    % At each position, find the image-feedback location.
                    obj.image.snapImage();
%                     Vs(:,kk) = obj.image.V;
                    Vs(1,kk) = obj.image.X;
                    Vs(2,kk) = obj.image.Y;

                    % Give the user an idea of what's happening by plotting.
                    scatter(obj.graphics.axes, Vs(1,:), Vs(2,:), [], 1:size(Vs,2), 'fill');
                    daspect(obj.graphics.axes, [1 1 1]);

                    kk = kk + 1;
                end
                
                % Return to base.
                if isfine
                    for pp = positions(end:-1:1)
                        pref.writ(base + pp * step);
                    end
                else
                    pref.writ(base);
                    pause(.5);
                end

%                 Vs
%                 dVs = diff(Vs, [], 2) / step
%                 dV = trimmean(diff(Vs, [], 2), 50, 2) / step;
                dV = mean(diff(Vs, [], 2), 2) / step;

                if isfine
                    obj.calibration_fine(   :, round(a/2)) = dV;
                else
                    obj.calibration_coarse( :, round(a/2)) = dV;
                end
            end
            
            obj.image.snapImage();
            
            obj.calibration_coarse =    inv(obj.calibration_coarse);
            obj.calibration_fine =      inv(obj.calibration_fine);
        end
    end
    
    % MOVEMENT ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
    properties(Hidden)
    	offset = .55;
        within = .1;
    end
    
    methods    
        function travel(obj)
            
        end
        function navigate(obj)
            V =     [obj.X; obj.Y];                 % Vector of our current position
            
            o =     [obj.offset; obj.offset];
            snap =  round(V - o) + o;               % Closest QR region center
            
            TV =    [obj.target_X; obj.target_Y];   % Vector of our target position
            
            dV = TV - V;                            % Direction of transit
            
            if norm(V - TV) < obj.within
                % Use peizos eventually.
                
%             elseif norm(V - snap) > within*2
            elseif norm(V - TV) > 1     % Move in modified Manhattan
            
                heading = round(vectorAngle(dV) * 4/pi) * pi/4;

                for dheading = [0, 1, -1]   % center, left, right, fail
                    ang = heading + dheading * pi/4;

                    dV2 = [cos(ang); sin(ang)];
                    dV2 = dV2 / max(abs(dV2));

                    nextV = snap + dV2;
                end
            else
                
            end
            
            
        end
        function navigateStep(obj, dX, dY)
%             obj.focusSmart();
           
            dV = [dX; dY];
            
            dv = obj.calibration_coarse * dV;
            
            obj.coarse_x.writ(obj.coarse_x.read() + dv(1));
            obj.coarse_y.writ(obj.coarse_y.read() + dv(2));
            
            obj.focusSmart();
        end
        function navigateTarget(obj, X, Y)
            Vt = [X; Y];
            
            obj.focusSmart();
            
            V = [obj.image.X; obj.image.Y];
            
            dV = Vt - V;
            
            if norm(dV) > 3
                error('Don''t want to move too far right now.')
            end
            
%             while norm(dV) > .1
            dv = obj.calibration_coarse * dV;
            
            obj.coarse_x.writ(obj.coarse_x.read() + dv(1));
            obj.coarse_y.writ(obj.coarse_y.read() + dv(2));
            
            pause(.5);
            
%             end
            
            obj.focusSmart();
        end
    end
    
end

function ang = vectorAngle(v)
    if v(2) == 0
        if v(1) > 0
            ang = 0;
        else
            ang = pi;
        end
    else
        ang = atan(v(2)/v(1));
        
        if v(1) < 0
            ang = pi + ang;
        elseif v(2) < 0
            ang = 2*pi + ang;
        end
    end
end
function s = sharpness(img)
    % Computes a metric for sharpness by averaging the gradients of the
    % image. Blurier images will have less gradient and thus less sharpness.
    s = mean(mean(((                    ...
        diff(img(:,1:(end-1)), [], 1) .^ 2 +    ...     % y gradient
        diff(img(1:(end-1),:), [], 2) .^ 2      ...     % x gradient
    ))));
end
function ramp(pref, from, to, dx)
    for x = from:(abs(dx)*sign(to-from)):to
        pref.writ(x);
    end
    pref.writ(to);
end







