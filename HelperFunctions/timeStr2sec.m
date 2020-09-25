function sec = timeStr2sec(str)
    switch str
        case {'ns', 'nanoseconds'}
            sec = 1e-9;
        case {'us', 'microseconds'}
            sec = 1e-6;
        case {'ms', 'milliseconds'}
            sec = 1e-3;
        case {'s', 'sec', 'seconds'}
            sec = 1;
        case {'min', 'minutes'}
            sec = 60;
        case {'hr', 'hrs' 'hours'}
            sec = 3600;
        otherwise
            error(['sec = timeStr2sec(str): String str = "' str '" not recognized as a unit of time.']);
    end
end