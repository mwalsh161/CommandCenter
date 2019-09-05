classdef SuperK < Modules.Source
    %superK used to control all aspects of the superK laser.
    %
    %   The on/off state of laser is controlled by the PulseBlaster (loaded
    %   in set.ip).  Note this state can switch to unknown if another
    %   module takes over the PulseBlaster program.
    %
    %   Power to the laser can be controlled through the serial object
    %   - obj.serial.on()/off() - however, time consuming calls!
    
    properties
        ip = 'Deprecated Use';         % IP of computer with and server
        prefs = {'ip'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running                      % Boolean specifying if StaticLines program running
    end
    properties(SetAccess=private,Hidden)
        listeners
        status                       % Text object reflecting running
        path_button
        serial
    end
    methods(Access=protected)
        function obj = SuperK()
            obj.loadPrefs;
            obj.serial = Drivers.SuperK.instance(obj.ip);
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SuperK();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            delete(obj.listeners)
            delete(obj.serial)
        end
        function set.ip(obj,val)
            err = [];
            try
                delete(obj.serial)
                obj.serial = Drivers.SuperK.instance(val);
                obj.ip = val;   
            catch err
                delete(obj.listeners)
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            obj.serial.on();
            obj.source_on = true;
        end
        function off(obj)
            obj.serial.off();
            obj.source_on = false;
        end
        
        % Settings and Callbacks
        function  settings(obj,panelH,~,~)
            spacing = 1.5;
            num_lines = 6;
            line = 1;
            uicontrol(panelH,'style','text','string','Power (%):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.serial.getPower),'tag','setPower',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 2;
            uicontrol(panelH,'style','text','string','Pulse Picker (int):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.serial.getPulsePicker),'tag','setPulsePicker',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 3;
            uicontrol(panelH,'style','text','string',strcat('Rep Rate (MHz): ',num2str(obj.serial.getRepRate())),'horizontalalignment','right',...
                'units','characters','position',[0,spacing*(num_lines-line) 25 1.25]);
            line = 4;
            uicontrol(panelH,'style','text','string','Center Wavelength (nm):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.serial.getWavelength()),'tag','setWavelength',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 5;
            uicontrol(panelH,'style','text','string','Bandwidth (nm):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.serial.getBandwidth()),'tag','setBandwidth',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 6;
            uicontrol(panelH,'style','text','string','Attenuation (%)):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.serial.getND()),'tag','setND',...
                'units','characters','callback',@obj.setNum,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
        end
        
        function setNum(obj,hObj,~)
            temp = get(hObj,'string');
            temp = str2double(temp);
            assert(~isnan(temp),'Must be a number!');
            obj.serial.(get(hObj,'tag'))(temp);
        end
        
        function ipCallback(obj,src,varargin)
            err = [];
            try
                obj.ip = get(src,'string');
            catch err
            end
            set(src,'string',obj.ip)
            if ~isempty(err)
                rethrow(err)
            end
        end
        
    end
end