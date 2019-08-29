classdef SGTest < Modules.Experiment
    
    properties
        freq_CW = 2.5*10^9;
        Power_CW = -1;
        min_freq = 2.86*10^9;
        max_freq = 2.88*10^9;
        freq_step = 0.0002*10^9;
        Amp = -5;
        MW;
        data;
    end
    
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        RF   % RF generator handle
    end
    
    methods(Access=private)
        function obj = SGTest()
            obj.MW = Drivers.SignalGenerators.SMIQ06B.instance('Prologix','COM7',1,1);
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Debug.SGTest();
            end
            obj = Object;
        end
    end
    
    methods
        
        function run(obj,statusH,managers,ax)
            
            pauseTime = 1;
            
            obj.updateWindow(statusH,sprintf('Device Handshaking'));
            str = obj.MW.writeRead('*IDN?');
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf(str));
            pause(pauseTime);
            pause(pauseTime);

            obj.updateWindow(statusH,sprintf('Unit Power Setting'));
            obj.MW.setUnitPower;
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf('Check Unit of the Power (dbm)'));
            pause(pauseTime);
            pause(pauseTime);
           
            obj.updateWindow(statusH,sprintf('CW mode Frequency setting'));
            obj.MW.setFreqCW(obj.freq_CW);
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf('Check Frequency is whether %0.2f GHz',obj.freq_CW/10^9));
            pause(pauseTime);
            pause(pauseTime);

            obj.updateWindow(statusH,sprintf('CW mode Power setting'));
            obj.MW.setPowerCW(obj.Power_CW);
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf('Check Power is whether %d dbm',obj.Power_CW));
            pause(pauseTime);
            pause(pauseTime);

            obj.updateWindow(statusH,sprintf('Set List mode'));
            obj.MW.setFreqMode('LIST');
            obj.MW.setPowerMode('LIST');
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf('Check whether the mode is LIST'));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Set Frequency List'));
            obj.MW.setFreqList((25:30)*10^8);
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf('Check whether the FreqList is from 2.5 ~ 3.0 GHz'));
            pause(pauseTime);
            pause(pauseTime);

            obj.updateWindow(statusH,sprintf('Set Power List'));
            obj.MW.setFreqList(0:5);
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf('Check whether the PowerList is from 0 ~ 5 dBm'));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Getting CW Frequency'));
            m = obj.MW.getFreqCW;
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf('Return : %0.2f (%0.2f), Instance : %0.2f (%0.2f)',m,obj.freq_CW,obj.MW.FreqCW,obj.freq_CW));
            pause(pauseTime);
            pause(pauseTime);
                        
            obj.updateWindow(statusH,sprintf('Getting CW Power'));
            m = obj.MW.getPowerCW;
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf('Return : %d (%d), Instance : %d (%d)',m,obj.Power_CW,obj.MW.PowerCW,obj.Power_CW));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Getting Freq Mode'));
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf(obj.MW.getFreqMode));
            pause(pauseTime);
            pause(pauseTime);

            obj.updateWindow(statusH,sprintf('Getting Power Mode'));
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf(obj.MW.getPowerMode));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Getting Freq List'));
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf(mat2str(obj.MW.getFreqList/10^8)));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Getting Power List'));
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf(mat2str(obj.MW.getPowerList)));
            pause(pauseTime);
            pause(pauseTime);

            obj.updateWindow(statusH,sprintf('Getting MW state'));
            pause(pauseTime);
            obj.updateWindow(statusH,sprintf(obj.MW.getMWstate));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Checking MW on'));
            pause(pauseTime);
            obj.MW.MWOn;
            obj.updateWindow(statusH,sprintf('Check whether MW is on'));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Checking MW off'));
            pause(pauseTime);
            obj.MW.MWOff;
            obj.updateWindow(statusH,sprintf('Check whether MW is off'));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Checking Learning the List'));
            pause(pauseTime);
            obj.MW.ListLearn;
            obj.updateWindow(statusH,sprintf('Check whether List is learnt'));
            pause(pauseTime);
            pause(pauseTime);
            
            obj.updateWindow(statusH,sprintf('Checking Deleting the Freq List'));
            pause(pauseTime);
            obj.MW.DeleteListFreq;
            obj.updateWindow(statusH,sprintf('Check whether Freq List is Deleted'));
            pause(pauseTime);
            pause(pauseTime);

            obj.updateWindow(statusH,sprintf('Checking Deleting the Power List'));
            pause(pauseTime);
            obj.MW.DeleteListPower;
            obj.updateWindow(statusH,sprintf('Check whether Power List is Deleted'));
            pause(pauseTime);
            pause(pauseTime);

        end
        
        function updateWindow(obj,statusH,updatedString)
            set(statusH,'string',...
                updatedString);
            drawnow;
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function settings(obj,panelH,~)
        end
        
        function data = GetData(obj,~,~)
                data = 1;
        end

    end
    
end
