classdef Widefield_invisible < Modules.Experiment
%Widefield_invisible Invisible superclass for widefield microwave experiments

    properties(GetObservable,SetObservable,AbortSet)
        averages = Prefs.Integer(2,'min', 1, 'help_text', 'Number of averages to perform');
        Laser = Prefs.ModuleInstance('help_text','PulseBlaster enabled laser');
        Camera = Prefs.ModuleInstance('help_text','Camera used to take ODMR images');

        update = Prefs.Button('Update', 'help_text', 'Update ROI and pixels of interest', 'set', 'set_update');
        Pixel_of_Interest_x = Prefs.String('', 'help_text', 'x-coordinate of pixel of interest to plot during experiment', 'readonly',true);
        Pixel_of_Interest_y = Prefs.String('', 'help_text', 'y-coordinate of pixel of interest to plot during experiment', 'readonly',true);
        ROI = Prefs.DoubleArray( [1 1; 1 1], 'units','pixel','min',1,'allow_nan',true,'help_text','region of interest to save','readonly',true);
    end
    properties
        prefs = {'averages','update','ROI','Pixel_of_Interest_x','Pixel_of_Interest_y','Laser','Camera'};
    end
    properties(SetAccess=protected,Hidden)
        % Internal properties that should not be accessible by command line
        pixel_x = linspace(2.85,2.91,101)*1e9; % Internal, set using Pixel_of_Interest_y
        pixel_y = linspace(2.85,2.91,101)*1e9; % Internal, set using Pixel_of_Interest_y
        data = [] % Useful for saving data from run method
        meta = [] % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()

        function [ax_im, ax_data, panel] = setup_image(ax, initial_im, varargin)
            % Setup display of widefield image
            % [ax_im, ax_data, panel] = setup_image(ax, initial_im)
            % [ax_im, ax_data, panel] = setup_image(ax, initial_im, pixels_of_interest)
            % [ax_im, ax_data, panel] = setup_image(ax, initial_im, pixels_of_interest, ROI)
            % ======
            % Inputs
            % ======
            % ax: initial axis to use
            % initial_im: initial image to use
            % pixels_of_interest: 2xN list of pixels of interest
            % ROI: ROI from data will be saved
            % =======
            % Outputs
            % =======
            % ax_im: ax for widefield image
            % ax_data: ax for data
            % panel: panel for plot

            if nargin>3
                pixels_of_interest = varargin{1};
                n_pix = size(pixels_of_interest, 2);
                if numel(varargin)>1
                    ROI = varargin{2};
                end
            else
                n_pix = 0;
            end

            % Plot image
            panel = ax.Parent;
            ax_im = subplot(1,2,1,'parent',panel);
            hold(ax_im, 'on')
            imagesc(  initial_im, 'parent', ax_im)
            set(ax_im,'dataAspectRatio',[1 1 1])
            hold(ax_im,'on');

            % Show pixels of interest
            for i = 1:n_pix
                plot( pixels_of_interest(1,i), pixels_of_interest(2,i), 'o', 'parent', ax_im)
            end
            
            % Show ROI
            if nargin>3 && numel(varargin)>1
                rectangle('pos',[min(ROI,[],2)' diff(ROI,1,2)'],'EdgeColor','r','LineWidth',2, 'parent', ax_im)
            end
            hold(ax_im,'off');
            
            size_initial_im = size(initial_im);
            ax_im.XLim = [1 size_initial_im(1)];
            ax_im.YLim = [1 size_initial_im(2)];
            
            % Plot data axis
            ax_data = subplot(1,2,2,'parent',panel);
        end

    end
    methods(Access=protected)
        function obj = Widefield_invisible()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,~,~)
            % Callback for saving methods
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        function setup_run(obj,managers)
            assert(length(obj.pixel_x)==length(obj.pixel_y), 'Length of x and y coordinates of pixels of interest are not the same')

            % Edit this to include meta data for this experimental run (saved in obj.GetData)
            obj.meta.prefs = obj.prefs2struct;
            obj.meta.pixels_of_interest = [obj.pixel_x; obj.pixel_y];
            obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
        end

        % Set methods allow validating property/pref set values
        function val = set_update(obj,val,~)
            fig = figure;
            ax = subplot(1, 1, 1, 'parent', fig);
            hold(ax, 'on')
            current_im = managers.Imaging.current_image;
            imagesc(current_im.image, 'parent', ax);
            set(ax_im,'dataAspectRatio',[1 1 1])

            % Update ROI
            title('Left mouse to select ROI\nRight mouse to exit and keep current ROI')
            keep_looping = true;
            new_ROI = zeros(2,2);
            while keep_looping
                old_ROI = rectangle('pos',[min(obj.ROI,[],2)' diff(obj.ROI,1,2)'],'EdgeColor','r','LineWidth',2, 'parent', ax_im);

                [x, y, button] = ginput(1);
                if button == 3
                    break
                end

                pt = plot( x, y, '+', 'MarkerSize', 10, 'Parent', ax_im);
                new_ROI(:,1) = [x y];

                [x, y, button] = ginput(1);
                if button == 3
                    break
                end
                new_ROI(:,2) = [x y];
                delete(pt)
                delete(old_ROI)
                obj.ROI = new_ROI;
            end
            
            % Update pixels of interest
            title('Left mouse to select pixel of interest\nRight mouse to exit\nSpace to reset')
            keep_looping = true;
            obj.pixel_x = [];
            obj.pixel_y = [];
            pt = [];
            cs = lines;
            i = 0;
            while keep_looping
                i = i + 1;
                [x, y, button] = ginput(1);
                if button == 3
                    break
                elseif button == 32
                    delete(pt)
                    obj.pixel_x = [];
                    obj.pixel_y = [];
                    pt = [];
                else
                    pt(end+1) = plot( x, y, 'o', 'Color', cs(mod(i,64),:), 'Parent', ax_im);
                    obj.pixel_x(end+1) = x;
                    obj.pixel_y(end+1) = y;
                end
            end
            
            obj.Pixel_of_Interest_x = num2str(obj.pixel_x);
            obj.Pixel_of_Interest_y = num2str(obj.pixel_y);
            delete(fig)
        end
    end
end