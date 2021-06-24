function equal = nanisequal(a,b)
%NANISEQUAL Compare equality like isequal, but take into account NaN and
%Inf also being equal

if isempty(a) && isempty(b)
    equal = true;
    return 
end
if isempty(a) || isempty(b)
    equal = false;
    return 
end

if isnumeric(a) && isnumeric(b)
    nanmask = isnan(a);
    nans_equal = isequal(nanmask, isnan(b));
    vals_equal = isequal(a(~nanmask),b(~nanmask));
    equal = nans_equal && vals_equal;
else
    equal = isequal(a,b);
end
end

