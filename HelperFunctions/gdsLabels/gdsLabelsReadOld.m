% function y = endianSwap(x)
% 
% end

% mex -setup -client engine C++

function gdsLabelsReadOld()
%     [status,commandOut] = system('pip install gdspy');
%     status
%     commandOut
% %     [status,cmdout] = system('conda info --envs')
% 
%     commandStr = 'conda activate & python gdsLabelsRead.py EG301.gds';
%     [status, commandOut] = system(commandStr);
%     status
%     commandOut
%     if status==0
%         fprintf('squared result is %d\n',str2num(commandOut));
%     end

    

    f = fopen('EG301.gds');
%     f = fopen('2020_08_14 MIT.CSEM.passives.v1.gds');
%     f = fopen('Main_Layout_v6.gds');

    isText = false;
    newText = {0, 0, 0, 0, 0, 0};
    
    while ~feof(f)
        bytes = fread(f, 4, 'uint8=>uint8');
        
        if length(bytes) < 4
            break;
        end
        
        length_ = 256*uint16(bytes(1)) + uint16(bytes(2)) - 4;
        record = bytes(3);
        token = bytes(4);
        
%         swapbytes(uint8(record))
        
%         length = swapbytes(fread(f, 1, 'uint16=>uint16')) - 4;
%         record = fread(f, 1, 'uint8=>uint8');
%         token = fread(f, 1, 'uint8=>uint8');
        
%         switch token
%             case 0 % 0x00:      // (null)
%                 size = 0;
%             case 1 % 0x01:      // (2-bitarr)
%                 size = 2;
%             case 2 % 0x02:      // (2-int)
%                 size = 2;
%             case 3 % 0x03:      // (4-int)
%                 size = 4;
%             case 4 % 0x04:      // (4-real; unused)
%                 error('Unexpected token; 4-reals are not used in GDSII.');
%             case 5 % 0x05:      // (8-sem)
%                 size = 8;
%             case 6 % 0x06:      // (ASCII string)
%                 size = 1;
%         end
%         switch token
%             case 0 % 0x00:      // (null)
%                 precision = '';
%             case 1 % 0x01:      // (2-bitarr)
%                 precision = 'uint16=>uint16';
%                 length = length/2;
%             case 2 % 0x02:      // (2-int)
%                 precision = 'uint16=>uint16';
%                 length = length/2;
%             case 3 % 0x03:      // (4-int)
%                 precision = 'uint32=>uint32';
%                 length = length/4;
%             case 4 % 0x04:      // (4-real; unused)
%                 error('Unexpected token; 4-reals are not used in GDSII.');
%             case 5 % 0x05:      // (8-sem)
%                 precision = 'uint64=>uint64';
%                 length = length/8;
%             case 6 % 0x06:      // (ASCII string)
%                 precision = 'char';
%         end
        switch token
            case 0 % 0x00:      // (null)
%                 precision = '';
            case 1 % 0x01:      // (2-bitarr)
                data = fread(f, length_/2, 'uint16=>uint16');
            case 2 % 0x02:      // (2-int)
                data = fread(f, length_/2, 'uint16=>uint16');
            case 3 % 0x03:      // (4-int)
                data = fread(f, length_/4, 'uint32=>uint32');
            case 4 % 0x04:      // (4-real; unused)
                error('Unexpected token; 4-reals are not used in GDSII.');
            case 5 % 0x05:      // (8-sem)
                data = fread(f, length_/8, 'uint64=>uint64');
            case 6 % 0x06:      // (ASCII string)
%                 data = fread(f, length_, 'char')
                data = fscanf(f, '%c', length_);
        end
        
%         if ~isempty(precision)
%             if token == 6
%             precision);
%             else
%                 data = fread(f, length, precision);
%             end
%         end
        
%         disp([num2str(record) ' ' num2str(token) ' ' num2str(length_)]);
%         disp(data)
        
        switch record
            case 00 % 0x00:    // HEADER       (2-int)
%                             // This can be 0, 3, 4, 5, or 600. 600 means 6. It uses the 100s digit for possible subversion control (e.g. 601 == v6.0.1)
%                             //                gdsVersion = *((int*)buffer);
            case 01 % 0x01:    // BGNLIB       (2-int)     Begin Library.      BGNLIB and BGNSTR both contain the creation and modification dates of the structure.
            case 05 % 0x05:    // BGNSTR       (2-int)     Begin Structure.
                if length_ == 24

%                     if (record == 0x01) {
%                         modification =  ((GDSDATE*)buffer)[0];
%                         access =        ((GDSDATE*)buffer)[1];
%                     } else if (record == 0x05) {
%                         subdevice = new DEVICE("");     // Create a new device without a description. Description will be added in STRNAME.
% 
%                         subdevice->modification =  ((GDSDATE*)buffer)[0];
%                         subdevice->access =        ((GDSDATE*)buffer)[1];
%                     }
                else
                    error('Expected two 12-byte dates.');
                end
            case 02 % 0x02:    // LIBNAME      (str)       Library Name.
%                 description =               std::string((char*)buffer, length);     break;  // constructor std::string(char& cstr, size_t n)
            case 03 % 0x03:    // UNITS        (sem)
%                 user2dbUnits =      sem2num( ((uint64_t*)buffer)[0] );
%                 db2metricUnits =    sem2num( ((uint64_t*)buffer)[1] );
%                 break;
            case 04 % 0x04:    // ENDLIB       (null)
% //                polylines.print();
% //                polylines.bb.print();
%                 bb.enlarge(polylines.bb);
%                 return true;
% //                break;
            case 06 % 0x06:    // STRNAME      (str)       Structure Name.
%                 subdevice->description =    std::string((char*)buffer, length);     break;
            case 07 % 0x07:    // ENDSTR       (null)      End Structure.
                disp('ENDSTR!!!ENDSTR!!!ENDSTR!!!')
                break;
            case 08 % 0x08:    // BOUNDARY     (null)
%                 if (!polyline.isEmpty()) { throw std::runtime_error("Did not expect nested boundaries..."); }
            case 09 % 0x09:    // PATH         (null)
            case 10 % 0x0A:    // SREF         (null)
            case 11 % 0x0B:    // AREF         (null)
            case 12 % 0x0C:    // TEXT         (null)
                isText = true;
                newText = {'', 0, 0, 0, 0};
            case 13 % 0x0D:    // LAYER        (2-int)     In [0, 63].
                if isText
                    newText{4} = swapbytes(data);
                end
%                 polyline.setLayer( endianSwap( *((uint16_t*)buffer) ) ); break;
            case 14 % 0x0E:    // DATATYPE     (4-int)
            case 15 % 0x0F:    // WIDTH        (4-int)
            case 16 % 0x10:    // XY           (4-int)
                if isText
%                     disp([num2str(record) ' ' num2str(token) ' ' num2str(length_)])
                    newText{2} = swapbytes(data(1));
                    newText{3} = swapbytes(data(2));
                end
% //                std::vector<VECTORINT> intPoints; //((VECTORINT*)buffer, length/size);
% //                intPoints.clear();
% //                intPoints.resize(length/size);
% //                intPoints.resize(length/size/2 - 1, VECTORINT());
% //                printf("SIZE0=%i\n", intPoints.size());
% //                intPoints.reserve(length/size/2 - 1);
%                 intPoints.resize(length/size/2 - 1, VECTORINT());
% //                printf("SIZE1=%i\n", intPoints.size());
%                 memcpy(&(intPoints[0]), buffer, length - 2*size);
%                 
%                 std::transform(intPoints.begin(), intPoints.begin() + length/size/2 - 1,
%                                std::back_inserter(polyline.points),
%                                [](VECTORINT v) -> VECTOR { return int2vec(v, DBUNIT); });   // Assuming dbUnit = .001
% 
%                 polyline.close();
% //                polyline.print();
% //                printf("AREA = %f\n", polyline.area());
%                 
%                 if (polyline.area() < 0) { polyline.reverse(); }
%                 
%                 polyline.recomputeBoundingBox();
%                 
%                 polylines.add(polyline);
%                 
%                 break;
            case 17 % 0x11:    // ENDEL        (null)
%                 if (polyline.isEmpty()) { throw std::runtime_error("Expected a boundary to have been written..."); }
%                 else                    { polyline.clear(); }
%                     
%                 break;
            case 18 % 0x12:    // SNAME        (str)       Inserts the strucuture of this name. Used with sref?

            case 19 % 0x13:    // COLROW       (2-int)

            case 20 % 0x14:    // ?

            case 21 % 0x15:    // NODE         (null)
            case 22 % 0x16:    // TEXTTYPE     (4-int)     In [0, 63].
                if isText
                    newText{5} = swapbytes(data);
                end
            case 23 % 0x17:    // PRESENTATION (bitarr)

            case 24 % 0x18:    // ?

            case 25 % 0x19:    // STRING       (str)       Up to 512 chars long
                if isText
                    newText{1} = data;
                end
%                 data
%                 newText
                isText = false;
            case 26 % 0x1A:    // STRANS       (bitarr)
            case 27 % 0x1B:    // MAG          (sem)
            case 28 % 0x1C:    // REFLIBS      (sem)

            case 29 % 0x1D:    // ?
            case 30 % 0x1E:    // ?
            case 31 % 0x1F:    // ?

            case 32 % 0x20:    // FONTS        (str)
            case 33 % 0x21:    // PATHTYPE     (2-int)
            case 34 % 0x22:    // GENERATIONS  (2-int)
            case 35 % 0x23:    // ATTRTABLE    (str)

            case 36 % 0x24:    // ?
            case 37 % 0x25:    // ?

            case 38 % 0x26:    // EFLAGS       (bitarr)

            case 39 % 0x27:    // ?
            case 40 % 0x28:    // ?
            case 41 % 0x29:    // ?

            case 42 % 0x2A:    // NODETYPE     (2-int)    In [0, 63].
            case 43 % 0x2B:    // PROPATTR     (2-int)
            case 44 % 0x2C:    // PROPVALUE    (str)

%                 // The following records are not supported by Stream Release 3.0:

            case 45 % 0x2D:    // BOX          (null)
            case 46 % 0x2E:    // BOXTYPE      (2-int)
            case 47 % 0x2F:    // PLEX         (4-int)
            case 48 % 0x30:    // BGNEXTN      (4-int)
            case 49 % 0x31:    // EXDEXTN      (4-int)

            case 50 % 0x32:    // ?
            case 51 % 0x33:    // ?
            case 52 % 0x34:    // ?
            case 53 % 0x35:    // ?
            case 54 % 0x36:    // ?

            case 55 % 0x37:    // MASK         (str)
            case 56 % 0x38:    // ENDMASKS     (null)
            case 57 % 0x39:    // LIBDIRSIZE   (2-int)
            case 58 % 0x3A:    // SRFNAME      (str)
            case 59 % 0x3B:    // LIBSECUR     (2-int)
                
            otherwise
                error(['Unknown record or unknown record-token pairing: ' num2str(record) ' ' num2str(token)])
        end
%             default:
%                 printf("DEVICE::importGDS(std::string): Unknown record or unknown record-token pairing: 0x%X\n", rt);
% //                throw std::runtime_error();
% 
%                 break;
%         }
                
%         error('ded')
    end
end

%     // References:  http://www.cnf.cornell.edu/cnf_spie9.html
%     //              http://www.rulabinsky.com/cavd/text/chapc.html
%     //              http://boolean.klaasholwerda.nl/interface/bnf/gdsformat.html
%     FILE* f = fopen(fname.c_str(), "r");
% 
%     if (!f) {
%         throw std::runtime_error("File does not exist");
%     }
% 
%     uint32_t header =       0;
%     size_t size =           0;
% 
%     size_t bufsize =        200*8;  // Expected maximum buffer. If we ever need more, it will be allocated.
%     void* buffer =          malloc(bufsize);
% 
%     POLYLINE polyline;
%     DEVICE* subdevice = NULL;
% 
%     uint64_t user2dbUnits =    0;
%     uint64_t db2metricUnits =  0;
% 
%     while (true) {
%         
%         std::vector<VECTORINT> intPoints;
%         
%         fread(&header, sizeof(uint32_t), 1, f);
%         
%         header = endianSwap(header);
%         
%         uint16_t length =      ((header & 0xFFFF0000) >> 16) - 4;   // The first 4 bytes are the length of record.
%         uint8_t record =       ((header & 0x0000FF00) >> 8);       // The type of the record.
%         uint8_t token =         (header & 0x000000FF);              // The last two bytes are the data type (token).
%         
%         uint16_t rt =           (header & 0x0000FFFF);              // The record and the token.
%         
% //        printf("Head = 0x%X, Record = 0x%X, Token = 0x%X, Length = 0x%X = %i\n", header, record, token, length, length);
% 
%         if (token == 0 && length > 0) {
%             throw std::runtime_error("DEVICE::importGDS(std::string): Header says that we should not expect data, but gives non-zero length");
%             // Error; expected no data.
%         }
% 
% //        if (!(length % record)) {
% //            // Error; length not divisible by type.
% //        }
% 
%         // Need to malloc the memory!
% 
%         switch (token) {
%             case 0x00:      // (null)
%                 size = 0;   break;
%             case 0x01:      // (2-bitarr)
%                 size = 2;   break;
%             case 0x02:      // (2-int)
%                 size = 2;   break;
%             case 0x03:      // (4-int)
%                 size = 4;   break;
%             case 0x04:      // (4-real; unused)
%                 throw std::runtime_error("DEVICE::importGDS(std::string): Unexpected token; 4-reals are not used in GDSII.");   break;
%             case 0x05:      // (8-sem)
%                 size = 8;   break;
%             case 0x06:      // (ASCII string)
%                 size = 1;   break;
%         }
% 
%         if (size*length > bufsize) {
%             while (size*length > bufsize) { bufsize *= 2; }
%             
%             free(buffer);
%             buffer = malloc(bufsize);
%         }
% 
%         if (length) { fread(buffer, size, length/size, f); }
% 
%         switch (record) {
%             case 0x00:    // HEADER       (2-int)
%                             // This can be 0, 3, 4, 5, or 600. 600 means 6. It uses the 100s digit for possible subversion control (e.g. 601 == v6.0.1)
%                             //                gdsVersion = *((int*)buffer);
%                 break;
%             case 0x01:    // BGNLIB       (2-int)     Begin Library.      BGNLIB and BGNSTR both contain the creation and modification dates of the structure.
%             case 0x05:    // BGNSTR       (2-int)     Begin Structure.
%                 if (length == 24) {
% 
%                     if (record == 0x01) {
%                         modification =  ((GDSDATE*)buffer)[0];
%                         access =        ((GDSDATE*)buffer)[1];
%                     } else if (record == 0x05) {
%                         subdevice = new DEVICE("");     // Create a new device without a description. Description will be added in STRNAME.
% 
%                         subdevice->modification =  ((GDSDATE*)buffer)[0];
%                         subdevice->access =        ((GDSDATE*)buffer)[1];
%                     }
%                 } else {
%                     throw std::runtime_error("DEVICE::importGDS(std::string): Expected two 12-byte dates.");
%                 }
% 
%                 break;
%             case 0x02:    // LIBNAME      (str)       Library Name.
%                 description =               std::string((char*)buffer, length);     break;  // constructor std::string(char& cstr, size_t n)
%             case 0x03:    // UNITS        (sem)
%                 user2dbUnits =      sem2num( ((uint64_t*)buffer)[0] );
%                 db2metricUnits =    sem2num( ((uint64_t*)buffer)[1] );
%                 break;
%             case 0x04:    // ENDLIB       (null)
% //                polylines.print();
% //                polylines.bb.print();
%                 bb.enlarge(polylines.bb);
%                 return true;
% //                break;
%             case 0x06:    // STRNAME      (str)       Structure Name.
%                 subdevice->description =    std::string((char*)buffer, length);     break;
%             case 0x07:    // ENDSTR       (null)      End Structure.
%                 break;
%             case 0x08:    // BOUNDARY     (null)
%                 if (!polyline.isEmpty()) { throw std::runtime_error("Did not expect nested boundaries..."); }
%             case 0x09:    // PATH         (null)
%                 break;
%             case 0x0A:    // SREF         (null)
%                 break;
%             case 0x0B:    // AREF         (null)
%                 break;
%             case 0x0C:    // TEXT         (null)
%                 break;
%             case 0x0D:    // LAYER        (2-int)     In [0, 63].
%                 polyline.setLayer( endianSwap( *((uint16_t*)buffer) ) ); break;
%             case 0x0E:    // DATATYPE     (4-int)
%                 break;
%             case 0x0F:    // WIDTH        (4-int)
%                 break;
%             case 0x10:    // XY           (4-int)
% //                std::vector<VECTORINT> intPoints; //((VECTORINT*)buffer, length/size);
% //                intPoints.clear();
% //                intPoints.resize(length/size);
% //                intPoints.resize(length/size/2 - 1, VECTORINT());
% //                printf("SIZE0=%i\n", intPoints.size());
% //                intPoints.reserve(length/size/2 - 1);
%                 intPoints.resize(length/size/2 - 1, VECTORINT());
% //                printf("SIZE1=%i\n", intPoints.size());
%                 memcpy(&(intPoints[0]), buffer, length - 2*size);
%                 
%                 std::transform(intPoints.begin(), intPoints.begin() + length/size/2 - 1,
%                                std::back_inserter(polyline.points),
%                                [](VECTORINT v) -> VECTOR { return int2vec(v, DBUNIT); });   // Assuming dbUnit = .001
% 
%                 polyline.close();
% //                polyline.print();
% //                printf("AREA = %f\n", polyline.area());
%                 
%                 if (polyline.area() < 0) { polyline.reverse(); }
%                 
%                 polyline.recomputeBoundingBox();
%                 
%                 polylines.add(polyline);
%                 
%                 break;
%             case 0x11:    // ENDEL        (null)
%                 if (polyline.isEmpty()) { throw std::runtime_error("Expected a boundary to have been written..."); }
%                 else                    { polyline.clear(); }
%                     
%                 break;
%             case 0x12:    // SNAME        (str)       Inserts the strucuture of this name. Used with sref?
% 
%             case 0x13:    // COLROW       (2-int)
% 
%             case 0x14:    // ?
% 
%             case 0x15:    // NODE         (null)
%             case 0x16:    // TEXTTYPE     (4-int)     In [0, 63].
%             case 0x17:    // PRESENTATION (bitarr)
% 
%             case 0x18:    // ?
% 
%             case 0x19:    // STRING       (str)       Up to 512 chars long
%             case 0x1A:    // STRANS       (bitarr)
%             case 0x1B:    // MAG          (sem)
%             case 0x1C:    // REFLIBS      (sem)
% 
%             case 0x1D:    // ?
%             case 0x1E:    // ?
%             case 0x1F:    // ?
% 
%             case 0x20:    // FONTS        (str)
%             case 0x21:    // PATHTYPE     (2-int)
%             case 0x22:    // GENERATIONS  (2-int)
%             case 0x23:    // ATTRTABLE    (str)
% 
%             case 0x24:    // ?
%             case 0x25:    // ?
% 
%             case 0x26:    // EFLAGS       (bitarr)
% 
%             case 0x27:    // ?
%             case 0x28:    // ?
%             case 0x29:    // ?
% 
%             case 0x2A:    // NODETYPE     (2-int)    In [0, 63].
%             case 0x2B:    // PROPATTR     (2-int)
%             case 0x2C:    // PROPVALUE    (str)
% 
%                 // The following records are not supported by Stream Release 3.0:
% 
%             case 0x2D:    // BOX          (null)
%             case 0x2E:    // BOXTYPE      (2-int)
%             case 0x2F:    // PLEX         (4-int)
%             case 0x30:    // BGNEXTN      (4-int)
%             case 0x31:    // EXDEXTN      (4-int)
% 
%             case 0x32:    // ?
%             case 0x33:    // ?
%             case 0x34:    // ?
%             case 0x35:    // ?
%             case 0x36:    // ?
% 
%             case 0x37:    // MASK         (str)
%             case 0x38:    // ENDMASKS     (null)
%             case 0x39:    // LIBDIRSIZE   (2-int)
%             case 0x3A:    // SRFNAME      (str)
%             case 0x3B:    // LIBSECUR     (2-int)
%                 
%             default:
%                 printf("DEVICE::importGDS(std::string): Unknown record or unknown record-token pairing: 0x%X\n", rt);
% //                throw std::runtime_error();
% 
%                 break;
%         }
%     }
% 
%     return true;
% }