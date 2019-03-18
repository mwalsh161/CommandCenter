classdef SignalGenerator < handle
   
    properties
        
        FreqCW;
        PowerCW;
        
        FreqMode;
        PowerMode;
        
        FreqList;
        PowerList;
        
        MWstate;
    end
    
    methods        
        
        function  setUnitPower(obj)
            error('Not implemented');
        end
        
        function  writeOnly(obj,string)
            error('Not implemented');
        end
        
        function  [output]=writeRead(obj,string)
            error('Not implemented');
        end
        
        
        function  setFreqCW(obj,Freq)
            error('Not implemented');
        end
        
        function  setPowerCW(obj,Power)
            error('Not implemented');
        end
        
        function  setFreqMode(obj,FreqMode)
            error('Not implemented');
        end
        
        function  setPowerMode(obj,PowerMode)
            error('Not implemented');
        end
        
        function  setFreqList(obj,FreqList)
            error('Not implemented');
        end
        
        function  setPowerList(obj,PowerList)
            error('Not implemented');
        end
        
        %% if some of the get functions are not available, just display "get ~ is not available!"
        
        function  [Freq]=getFreqCW(obj)
            error('Not implemented');
        end
        
        function  [Power]=getPowerCW(obj)
            error('Not implemented');
        end
        
        function  [FreqMode]=getFreqMode(obj)
            error('Not implemented');
        end
        
        function  [PowerMode]=getPowerMode(obj)
            error('Not implemented');
        end
        
        function  [FreqList]=getFreqList(obj)
            error('Not implemented');
        end
        
        function  [PowerList]=getPowerList(obj)
            error('Not implemented');
        end
        
        function  [MWstate]=getMWstate(obj)
            error('Not implemented');
        end
        

        
        function  exeCW(obj)
            error('Not implemented');
        end
        
        function  exeLIST(obj)
            error('Not implemented');
        end
    end
   
end