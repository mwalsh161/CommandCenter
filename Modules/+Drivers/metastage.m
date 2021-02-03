classdef metastage < Modules.Driver

    % GENERAL ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
    properties (GetObservable, SetObservable)
        coarse_x =      []; %Prefs.Pointer();
        fine_x =        []; %Prefs.Pointer();
        
        coarse_y =      []; %Prefs.Pointer();
        fine_y =        []; %Prefs.Pointer();
        
        coarse_z =      []; %Prefs.Pointer();
        fine_z =        []; %Prefs.Pointer();
        
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
            obj.graphics.figure = figure;
            obj.graphics.axes = axes;
        end
    end
    
    % FOCUS ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
    properties
        focusfigure
    end
    
    methods
        function success = focus(obj, N)
            if nargin < 2
                N = 11;
            end
            
            dZ = linspace(-1, 1, N);
            zbase = obj.fine_z.read();
            
            metric1 = NaN(1, length(dZ));
            metric2 = NaN(1, length(dZ));
            
            % Sweep over Z, recording 'focus metrics' at every step
            for ii = 1:length(dZ)
                obj.fine_z.writ(zbase + dZ);
                pause(.05); % Remove eventually!
                
                img = obj.image.snap();
                
                metric1(ii) = sharpness(img);           % Image sharpness
                metric2(ii) = obj.image.confidence;     % QR detection confidence (num QRs)
                
                % Give the user an idea of what's happening by plotting.
%                 scatter(obj.helperaxes, Vs(1,:), Vs(2,:), [], 1:size(V,2), 'fill');
            end
            
            success = max(metric2) > 0;
            
            if ~success             % If no QRs were found ...
                obj.fine_z.writ(zbase);
            else                    % Otherwise, goto the Z where the most QRs were legible.
                obj.fine_z.writ(zbase + mean(dZ(metric2 == max(metric2))));
                % Ignore metric 1 for now.
            end
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
            if ~obj.focus()
                % Focus onto QR codes was not successful. Try moving to an
                % area with legible QR codes.
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

                positions = 0:2:10;
                base = pref.read();
                Vs = NaN(2, length(positions));
                kk = 1;

                for pp = positions  % Successively move from the current postion.
                    pref.writ(base + pp * 1);

                    % At each position, find the image-feedback location.
                    obj.image.snap();
                    Vs(:,kk) = obj.image.V;

                    % Give the user an idea of what's happening by plotting.
                    scatter(obj.graphics.axes, Vs(1,:), Vs(2,:), [], 1:size(V,2), 'fill');

                    kk = kk + 1;
                end

                dV = trimmean(diff(Vs, [], 2), 50, 2);

                if mod(a, 2)
                    obj.calibration_coarse( :, round(a/2)) = dV;
                else
                    obj.calibration_fine(   :, round(a/2)) = dV;
                end
            end
            
            obj.calibration_coarse
            obj.calibration_fine
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
        function navigatestep(obj)
            
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
    s = mean(mean(norm(                 ...
        diff(img(:,1:(end-1)), [], 1) + ...     % y gradient
        diff(img(1:(end-1),:), [], 2)   ...     % x gradient
    )));
end








