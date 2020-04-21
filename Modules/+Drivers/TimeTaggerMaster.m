classdef TimeTaggerMaster < TimeTagger
    
    % Add correct superclass!
    
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        binwidth = 1e9
        pts = 1000
        count
        data
    end
    
    methods
        function obj = TimeTaggerMaster()
            %UNTITLED Construct an instance of this class
            %   Detailed explanation goes here
            obj.reset()
        end
        
        function avg = get_ct(obj, ch)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            obj.count = TimeTaggerMasterCounter(obj, ch, obj.binwidth, obj.pts); 
            obj.seTimeTaggerMasterestSignal(1, true);
            % pause
            pause(0.5); % pause(seconds)
            % get data
            obj.data = obj.count.getData();
            % turn off test signal
            obj.seTimeTaggerMasterestSignal(1, false); 
            % get average ct
%             avg = sum(data)/(obj.binwidth*obj.pts);
            avg = max(obj.data);
        end

        function plot_data(obj)
            % plot data
            figure(1)
            % here is a pitfall: you have to cast count.getIndex() to a double first -
            % otherwise it is a integer devision which screws up your plot
            plot(double(obj.count.getIndex())/1e12, obj.data);
            xlabel('Time (s)');
            ylabel('Counrate (kHz)');
            legend('channel 1', 'Location', 'East');
            title('Time trace of the click rate on channel 1')
            text(0.1,400, {'The built in test signal (~ 800 to 900 kHz)', 'is applied to channel 1'})

        end
    end
end

