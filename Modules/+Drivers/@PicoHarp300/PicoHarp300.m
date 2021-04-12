classdef PicoHarp300 < Modules.Driver
    %PICOHARP
    %
    
    properties
        % for calls to HWserver
        Protocol = 'USB';
        SerialNr = 'NaN';
        DeviceNr = 'NaN';
        Model = 'NaN';
        Partnum = 'NaN';
        Version = 'NaN';
    end
    
    properties (Constant)
        % Constants from Phdefin.h
        REQLIBVER   =  '3.0';     % this is the version this program expects
        MAXDEVNUM   =      8;
        HISTCHAN    =  65536;	  % number of histogram channels
        MAXBINSTEPS =      8;
        MODE_HIST   =      0;
        MODE_T2	    =      2;
        MODE_T3	    =      3;
        
        FLAG_OVERFLOW = hex2dec('0040');
        
        ZCMIN		  =          0;		% mV
        ZCMAX		  =         20;		% mV
        DISCRMIN	  =          0;	    % mV
        DISCRMAX	  =        800;	    % mV
        SYNCOFFSMIN	  =     -99999;		% ps
        SYNCOFFSMAX	  =      99999;		% ps
        OFFSETMIN	  =          0;		% ps
        OFFSETMAX	  = 1000000000;	    % ps
        ACQTMIN		  =          1;		% ms
        ACQTMAX		  =  360000000;	    % ms  (10*60*60*1000ms = 100h)
        
        % Errorcodes from errorcodes.h
        PH_ERROR_DEVICE_OPEN_FAIL		 = -1;
    end
    
    properties (SetAccess=immutable)
        hwserver;  % Handle to hwserver
    end
    
    methods(Static)
        function obj = instance(ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PicoHarp300.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(ip,Objects(i).singleton_id)
                    error('%s driver is already instantiated!',mfilename)
                end
            end
            obj = Drivers.PicoHarp300(ip);
            obj.singleton_id = ip;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function obj = PicoHarp300(inputArg)
            try
                obj.loadlibPH;
                obj.opendevPH;
            catch err
                obj.delete;
                error('Error opening communication, PicoHarp300 handle destroyed:\n%s',err.message);
            end
        end
        
        function loadlibPH(obj)
            %load PH300 library
            if (~libisloaded('PHlib'))
                pathtolib = fileparts(mfilename('fullpath'));
                os = computer;
                if strcmp(os(end-1:end),'64')
                    loadlibrary('phlib64.dll',fullfile(pathtolib,'phlib.h'),'alias','PHlib');
                else
                    loadlibrary('phlib.dll',fullfile(pathtolib,'phlib.h'),'alias','PHlib');
                end
            end
            if (~libisloaded('PHlib'))
                error('Could not open PHlib')
            end
            %check library version
            LibVersion    = '????'; %enough length!
            LibVersionPtr = libpointer('cstring', LibVersion);
            [ret, LibVersion] = calllib('PHlib', 'PH_GetLibraryVersion', LibVersionPtr);
            if (ret<0)
                error('Error in GetLibVersion.');
            end
            if ~strcmp(LibVersion,obj.REQLIBVER)
                error('This program requires PHLib version %s\n', obj.REQLIBVER);
            end
        end
        
        function opendevPH(obj) % open communication with any PicoHarp found and initialise for histogram acquisition mode
            dev = [];
            Serials = {};
            found = 0;
            Serial     = '12345678'; %enough length!
            SerialPtr  = libpointer('cstring', Serial);
            ErrorStr   = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'; %enough length!
            ErrorPtr   = libpointer('cstring', ErrorStr);
            % look for PicoHarp devices
            for i=0:obj.MAXDEVNUM-1
                [ret, Serial] = calllib('PHlib', 'PH_OpenDevice', i, SerialPtr);
                if (ret==0)       % Grab any PicoHarp we successfully opened
                    dev = cat(1,dev,i);
                    Serials = cat(1,Serials,Serial);
                end
            end
            if (length(dev)<1)
                error('No PicoHarp device available.');
            end
            % try to initialize every PicoHarp device found, until one is initialized succesfully
            i=0;
            ret = -1;
            while i<length(dev) && ret~=0
                i = i+1;
                [ret] = calllib('PHlib', 'PH_Initialize', dev(i), obj.MODE_HIST);
            end
            if ret~=0
                error('Error initializing PicoHarp300\nDevice index: %d S/N: %s', dev(i), Serials{i})
            end
            pause(0.2); % Note: after Init or SetSyncDiv you must allow 100 ms for valid new count rate readings
            obj.SerialNr = Serials(i);
            obj.DeviceNr = dev(i);
            %this is only for information
            Model      = '1234567890123456'; %enough length!
            Partnum    = '12345678'; %enough length!
            Version    = '12345678'; %enough length!
            ModelPtr   = libpointer('cstring', Model);
            PartnumPtr = libpointer('cstring', Partnum);
            VersionPtr = libpointer('cstring', Version);
            [ret, Model, Partnum, Version] = calllib('PHlib', 'PH_GetHardwareInfo', dev(1), ModelPtr, PartnumPtr, VersionPtr);
            if (ret<0)
                error('PH_GetHardwareInfo error %1d.',ret);
            else
                obj.Model = Model;
                obj.Partnum = Partnum;
                obj.Version = Version;
            end
            % calibrate the device
            [ret] = calllib('PHlib', 'PH_Calibrate', obj.DeviceNr);
            if (ret<0)
                error('PH_Calibrate error %1d. Aborted.\n',ret);
            end
        end
    end
    
    methods    
        function delete(obj)
            if (libisloaded('PHlib'))
                for(i=0:7); % no harm to close all
                    calllib('PHlib', 'PH_CloseDevice', i);
                end;
            end;
            delete(obj.hwserver);
        end

        function PH_SetSyncDiv(obj, SyncDiv)
            assert(ismember(SyncDiv,[1 2 4 8]),'SyncDiv must be one of the following: [1 2 4 8]');
            [ret] = calllib('PHlib','PH_SetSyncDiv',obj.DeviceNr,SyncDiv);
            assert(ret==0,sprintf('PH_SetSyncDiv error %1d.',ret));
            pause(0.2); % Note: after Init or SetSyncDiv you must allow 100 ms for valid new count rate readings
        end

        function PH_SetSyncOffset(obj, SyncOffset) % A positive offset corresponds to inserting a cable in the sync input
            assert(SyncOffset>=obj.SYNCOFFSMIN && SyncOffset<=obj.SYNCOFFSMAX,sprintf('SyncOffset out of range [%g, %g]',obj.SYNCOFFSMIN,obj.SYNCOFFSMAX));
            [ret] = calllib('PHlib', 'PH_SetSyncOffset', obj.DeviceNr, SyncOffset);
            assert(ret==0,sprintf('PH_SetSyncOffset error %1d.',ret));
        end

        function PH_SetInputCFD(obj,channel,CFDLevel,CFDZeroX) %CFD = Constant Fraction Discriminator
            assert(ismember(channel,[0 1]),'Channel must be either 0 or 1.');
            assert(CFDLevel>=obj.DISCRMIN && CFDLevel<=obj.DISCRMAX,sprintf('CFDLevel out of range [%g, %g] mV',obj.DISCRMIN,obj.DISCRMAX));
            assert(CFDZeroX>=obj.ZCMIN && CFDZeroX<=obj.ZCMAX,sprintf('CFDZero out of range [%g, %g] mV',obj.ZCMIN,obj.ZCMAX));
            [ret] = calllib('PHlib','PH_SetInputCFD',obj.DeviceNr,channel,CFDLevel,CFDZeroX);
            assert(ret==0,sprintf('PH_SetInputCFD error %ld.',ret));
        end

        function PH_SetBinning(obj,Binning)
            assert(ismember(Binning,[0:obj.MAXBINSTEPS-1]),'Binnign must be an integer between 0 and %d',obj.MAXBINSTEPS-1);
            [ret] = calllib('PHlib','PH_SetBinning',obj.DeviceNr,Binning);
            assert(ret==0,sprintf('PH_SetBinning error %ld.',ret));
        end

        function PH_SetOffset(obj,Offset)
            assert(CFDLevel>=obj.OFFSETMIN && CFDLevel<=obj.OFFSETMAX,sprintf('PH_SetOffset out of range [%g, %g]',obj.OFFSETMIN,obj.OFFSETMAX));
            [ret] = calllib('PHlib','PH_SetOffset',obj.DeviceNr,Offset);
            assert(ret==0,sprintf('PH_SetOffset error %ld.',ret));
        end

        function PH_SetStopOverflow(obj,stop_overflow,stop_counts)
            assert(ismember(stop_overflow,[0 1]),'stop_overflow must be either 0 (do not stop) or 1 (stop on overflow).');
            assert(stop_counts>=0 && stop_counts<=65535,sprintf('stop_counts must be an integer not larger than 65,535'));
            ret = calllib('PHlib', 'PH_SetStopOverflow',obj.DeviceNr,stop_overflow,stop_counts);
            assert(ret==0,sprintf('PH_SetStopOverflow error %ld.',ret));
        end

        function Countrate = PH_GetCountRate(obj,channel)
            assert(ismember(channel,[0 1]),'Channel must be either 0 or 1.');
            Countrate = 0;
            CountratePtr = libpointer('int32Ptr', Countrate);
            [ret, Countrate] = calllib('PHlib', 'PH_GetCountRate',obj.DeviceNr,channel,CountratePtr);
            assert(ret==0,sprintf('PH_GetCountRate error %ld.',ret));
        end

        function Resolution = PH_GetResolution(obj)
            Resolution = 0;
            ResolutionPtr = libpointer('doublePtr', Resolution);
            [ret, Resolution] = calllib('PHlib','PH_GetResolution',obj.DeviceNr,ResolutionPtr);
            assert(ret==0,sprintf('PH_GetResolution error %ld.',ret));
        end
        
        function [BaseResolution,BinSteps] = PH_GetBaseResolution(obj)
            BaseResolution = 0;
            BaseResolutionPtr = libpointer('doublePtr', BaseResolution);
            BinSteps = int32(0);
            BinStepsPtr = libpointer('int32Ptr', BinSteps);
            [ret, BaseResolution, BinSteps] = calllib('PHlib','PH_GetBaseResolution',obj.DeviceNr,BaseResolutionPtr,BinStepsPtr);
            assert(ret==0,sprintf('PH_GetBaseResolution error %ld.',ret));
        end

        function PH_ClearHistMem(obj)
            blockNr = 0; % always use Block 0 if not Routing
            ret = calllib('PHlib', 'PH_ClearHistMem',obj.DeviceNr,blockNr);
            assert(ret==0,sprintf('PH_ClearHistMem error %ld.',ret));
        end

        function PH_StartMeas(obj,Tacq)
            assert(Tacq>=obj.ACQTMIN && Tacq<=obj.ACQTMAX,sprintf('Tacq out of range [%g, %g] ms',obj.ACQTMIN,obj.ACQTMAX));
            ret = calllib('PHlib','PH_StartMeas',obj.DeviceNr,Tacq);
            assert(ret==0,sprintf('PH_StartMeas error %ld.',ret));
        end

        function PH_StopMeas(obj)
            %Note: Can also be used before the CTC expires but for internal
            %housekeeping it MUST be called any time you finish a measurement,
            %even if data collection was stopped internally, e.g. by expiration
            %of the CTC or an overflow.
            ret = calllib('PHlib','PH_StopMeas',obj.DeviceNr);
            assert(ret==0,sprintf('PH_StopMeas error %ld.',ret));
        end

        function ctcdone = PH_CTCStatus(obj)
            ctcdone = int32(0);
            ctcdonePtr = libpointer('int32Ptr', ctcdone);
            [ret, ctcdone] = calllib('PHlib','PH_CTCStatus',obj.DeviceNr,ctcdonePtr);
            assert(ret==0,sprintf('PH_CTCStatus error %ld.',ret));
        end

        function countsbuffer = PH_GetHistogram(obj)
            countsbuffer  = uint32(zeros(1,obj.HISTCHAN));
            bufferptr = libpointer('uint32Ptr', countsbuffer);
            blockNr = 0; %(block > 0 meaningful only with routing)
            [ret,countsbuffer] = calllib('PHlib','PH_GetHistogram',obj.DeviceNr,bufferptr,blockNr);
            assert(ret==0,sprintf('PH_GetHistogram error %ld.',ret));
        end
        
        function elapsedtime = PH_GetElapsedMeasTime(obj)
            elapsedtime = 0;
            elapsedtimePtr = libpointer('doublePtr', elapsedtime);
            [ret,elapsedtime] = calllib('PHlib','PH_GetElapsedMeasTime',obj.DeviceNr,elapsedtimePtr);
            assert(ret==0,sprintf('PH_GetElapsedMeasTime error %ld.',ret));
        end

        function flags = PH_GetFlags(obj)
            flags = int32(0);
            flagsPtr = libpointer('int32Ptr', flags);
            [ret,flags] = calllib('PHlib', 'PH_GetFlags',obj.DeviceNr,flagsPtr);
            assert(ret==0,sprintf('PH_GetFlags error %ld.',ret));
        end

    end
end
