#include "mex.hpp"
#include "mexAdapter.hpp"

#include <regex>

using namespace matlab::data;
using matlab::mex::ArgumentList;

inline uint16_t endianSwap(uint16_t x) {
    return  ( (x & 0x00FF) << 8 ) |
            ( (x & 0xFF00) >> 8 );
}
inline uint32_t endianSwap(uint32_t x) {
    return  ( (x & 0x000000FF) << 24 ) |
            ( (x & 0x0000FF00) << 8  ) |
            ( (x & 0x00FF0000) >> 8  ) |
            ( (x & 0xFF000000) >> 24 );
}
inline uint64_t endianSwap(uint64_t x) {
    return  ( (x & 0x00000000000000FF) << 56 ) |
            ( (x & 0x000000000000FF00) << 40 ) |
            ( (x & 0x0000000000FF0000) << 24 ) |
            ( (x & 0x00000000FF000000) << 8  ) |
            ( (x & 0x000000FF00000000) >> 8  ) |
            ( (x & 0x0000FF0000000000) >> 24 ) |
            ( (x & 0x00FF000000000000) >> 40 ) |
            ( (x & 0xFF00000000000000) >> 56 );
}

inline int16_t endianSwap(int16_t x) {
    return  ( (x & 0x00FF) << 8 ) |
            ( (x & 0xFF00) >> 8 );
}
inline int32_t endianSwap(int32_t x) {
    return  ( (x & 0x000000FF) << 24 ) |
            ( (x & 0x0000FF00) << 8  ) |
            ( (x & 0x00FF0000) >> 8  ) |
            ( (x & 0xFF000000) >> 24 );
}
inline int64_t endianSwap(int64_t x) {
    return  ( (x & 0x00000000000000FF) << 56 ) |
            ( (x & 0x000000000000FF00) << 40 ) |
            ( (x & 0x0000000000FF0000) << 24 ) |
            ( (x & 0x00000000FF000000) << 8  ) |
            ( (x & 0x000000FF00000000) >> 8  ) |
            ( (x & 0x0000FF0000000000) >> 24 ) |
            ( (x & 0x00FF000000000000) >> 40 ) |
            ( (x & 0xFF00000000000000) >> 56 );
}

inline double sem2num(uint64_t sem) {
    return                  (sem & 0x8000000000000000)?(-1):(1) *           // Sign.
            std::pow(16,  (((sem & 0x7F00000000000000) >> 56) - 64)) *      // Exponent.
                            (sem & 0x00FFFFFFFFFFFFFF);                     // Mantissa.
}

inline uint64_t num2sem(double num) {
    uint8_t exponent = 64;
    
    while (num < .0625 && exponent > 0) {
        num *= 16;
        exponent -= 1;
    }
    
    if (exponent == 0) {
        printf("Error: exponent less than 0");
    }
    
    return  (num == 0)?(0):( (num <  0)?(0x0000000000000080):(0) | (uint64_t)exponent | endianSwap((uint64_t)round( num * std::pow(2, 56) )) );
}

class MexFunction : public matlab::mex::Function {
    // ArrayFactory factory;
public:
    void operator()(ArgumentList outputs, ArgumentList inputs) {
        std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();
        ArrayFactory factory;
        
        CharArray fname_ = inputs[0];
        std::string fname = fname_.toAscii();
        
        std::string expression = "";
        
        if (inputs.size() > 1) {
            CharArray expression_ = inputs[1];
            expression = expression_.toAscii();
            matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar("Using regex('" + expression + "').") }));
        } else {
            matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar("Not using regex.") }));
        }
        
        // References:  http://www.cnf.cornell.edu/cnf_spie9.html
        //              http://www.rulabinsky.com/cavd/text/chapc.html
        //              http://boolean.klaasholwerda.nl/interface/bnf/gdsformat.html
        
        FILE* f = fopen(fname.c_str(), "r");

        if (!f) {
            throw std::runtime_error("File does not exist");
        }

        uint32_t header =       0;
        size_t size =           0;

        size_t bufsize =        200*8;  // Expected maximum buffer. If we ever need more, it will be allocated.
        void* buffer =          malloc(bufsize);

        double user2dbUnits =    0;
        double db2metricUnits =  0;
        
        bool going = true;
        
        std::vector<std::string> text;
        
        double x0 = 0;
        double y0 = 0;
        uint16_t l0 = 0;
        uint16_t t0 = 0;
        
        std::vector<double> x;
        std::vector<double> y;
        std::vector<uint16_t> l;
        std::vector<uint16_t> t;
        std::string str;
        
        bool isText = false;
        
//         matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar("Got to while") }));

        int i = 0;
        int j = 0;
        
        
        while (going) {
            i += 1;
            
            fread(&header, sizeof(uint32_t), 1, f);
            
            header = endianSwap(header);
            
            uint16_t length =      ((header & 0xFFFF0000) >> 16) - 4;   // The first 4 bytes are the length of record.
            uint8_t record =       ((header & 0x0000FF00) >> 8);       // The type of the record.
            uint8_t token =         (header & 0x000000FF);              // The last two bytes are the data type (token).
            
            uint16_t rt =           (header & 0x0000FFFF);              // The record and the token.
            
            bool isDuplicate = false;
            
            // char str3[128];
            
            // sprintf(str3, "Head = 0x%X, Record = 0x%X, Token = 0x%X, Length = 0x%X = %i\n", header, record, token, length, length);

            // matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar(str3) }));
            
            if (token == 0 && length > 0) {
                throw std::runtime_error("DEVICE::importGDS(std::string): Header says that we should not expect data, but gives non-zero length");
                // Error; expected no data.
            }

            switch (token) {
                case 0x00:      // (null)
                    size = 0;   break;
                case 0x01:      // (2-bitarr)
                    size = 2;   break;
                case 0x02:      // (2-int)
                    size = 2;   break;
                case 0x03:      // (4-int)
                    size = 4;   break;
                case 0x04:      // (4-real; unused)
                    throw std::runtime_error("DEVICE::importGDS(std::string): Unexpected token; 4-reals are not used in GDSII.");   break;
                case 0x05:      // (8-sem)
                    size = 8;   break;
                case 0x06:      // (ASCII string)
                    size = 1;   break;
            }

            if (size*length > bufsize) {
                while (size*length > bufsize) { bufsize *= 2; }
                
                free(buffer);
                buffer = malloc(bufsize);
            }
            
            // sprintf(str3, "Length = %i, size = %i, count = %i\n", length, size, length/size);

            // matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar(str3) }));

            if (length) { fread(buffer, size, length/size, f); }
            
            char str2[64];

            switch (record) {
                // case 0x00:    // HEADER       (2-int)
                //                 // This can be 0, 3, 4, 5, or 600. 600 means 6. It uses the 100s digit for possible subversion control (e.g. 601 == v6.0.1)
                //                 //                gdsVersion = *((int*)buffer);
                //     break;
                // case 0x01:    // BGNLIB       (2-int)     Begin Library.      BGNLIB and BGNSTR both contain the creation and modification dates of the structure.
                // case 0x05:    // BGNSTR       (2-int)     Begin Structure.
                //     if (length == 24) {
                // 
                //         // if (record == 0x01) {
                //         //     modification =  ((GDSDATE*)buffer)[0];
                //         //     access =        ((GDSDATE*)buffer)[1];
                //         // } else if (record == 0x05) {
                //         //     subdevice = new DEVICE("");     // Create a new device without a description. Description will be added in STRNAME.
                //         // 
                //         //     subdevice->modification =  ((GDSDATE*)buffer)[0];
                //         //     subdevice->access =        ((GDSDATE*)buffer)[1];
                //         // }
                //     } else {
                //         throw std::runtime_error("DEVICE::importGDS(std::string): Expected two 12-byte dates.");
                //     }
                // 
                //     break;
                case 0x02:    // LIBNAME      (str)       Library Name.
                    // description =       std::string( (char*)buffer, length );     break;
                    break;
                case 0x03:    // UNITS        (sem)
                    user2dbUnits =      sem2num( endianSwap( ((uint64_t*)buffer)[0] ));
                    db2metricUnits =    sem2num( endianSwap( ((uint64_t*)buffer)[1] ));
//                     user2dbUnits =      1e-3;
//                     db2metricUnits =    1e-9;
                    
//                     snprintf(str2, 64, "UNITS: %f, %f", user2dbUnits, db2metricUnits);
                    
//                     matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar(str2) }));
                    
                    break;
                case 0x04:    // ENDLIB       (null)
                    going = false;
                    break;
                case 0x06:    // STRNAME      (str)       Structure Name.
                    // std::string((char*)buffer, length);
                    break;
                case 0x07:    // ENDSTR       (null)      End Structure.
                    going = false;
                    break;
                case 0x0C:    // TEXT         (null)
                    isText = true;
                    break;
                case 0x0D:    // LAYER        (2-int)     In [0, 63].
                    l0 = endianSwap( *((uint16_t*)buffer) );
                    break;
                case 0x10:    // XY           (4-int)
                    x0 = ((double)endianSwap( *((int32_t*)buffer    ) )) * .001; // * user2dbUnits;
                    y0 = ((double)endianSwap( *((int32_t*)buffer + 1) )) * .001; // * user2dbUnits;
                        
                        
//                         snprintf(str2, 64, "X: %i, %i", ((uint16_t*)buffer)[0], endianSwap(((uint16_t*)buffer)[0]));
// 
//                         matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar(str2) }));
                    break;
                case 0x16:    // TEXTTYPE     (4-int)     In [0, 63].
                    t0 = endianSwap( *((uint16_t*)buffer) );
                    break;
                case 0x19:    // STRING       (str)       Up to 512 chars long
                    if (isText) {
                        str = std::string( (char*)buffer, length );

                        if (expression.size() == 0 || (expression.size() == 1 && str[0] == expression[0]) || std::regex_search(str, std::regex(expression))) {
                        
                            isDuplicate = false;

                            j = 0;
                            while (j < x.size() && !isDuplicate) {
                                isDuplicate = (x[j] == x0) && (y[j] == y0) && (l[j] == l0) && (t[j] == t0) && (str == text[j]);

                                j++;
                            }
                            
                            if (!isDuplicate) {
                                text.push_back(str);
                                x.push_back(x0);
                                y.push_back(y0);
                                l.push_back(l0);
                                t.push_back(t0);
                            }
                        }
                    }
                    isText = false;
                    break;
                    
                default:
                    // printf("DEVICE::importGDS(std::string): Unknown record or unknown record-token pairing: 0x%X\n", rt);
        //                throw std::runtime_error();

                    break;
            }
        }

        free(buffer);
        
        
//         matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar("Finished while") }));

        
        unsigned long N = text.size();
        
        Array S = factory.createCellArray({1, N});
        
        TypedArray<double> X = factory.createArray<double>({1, N});
        TypedArray<double> Y = factory.createArray<double>({1, N});
        TypedArray<uint16_t> L = factory.createArray<uint16_t>({1, N});
        TypedArray<uint16_t> T = factory.createArray<uint16_t>({1, N});
        
        
        for (int i = 0; i < N; i++) {
            S[i] = factory.createCharArray(text[i]);
            X[i] = (x[i]);
            Y[i] = (y[i]);
            L[i] = (l[i]);
            T[i] = (t[i]);
        }
        
        CellArray myArray = factory.createCellArray({1, 5}, S, X, Y, L, T);
        
        
//         matlabPtr->feval(u"warning", 0, std::vector<Array>({ factory.createScalar("Made outputs") }));
        
        outputs[0] = myArray;
    }
};
