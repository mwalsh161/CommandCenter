function starts_with = matrix_starts_with(a,b)
%MATRIX_STARTS_WITH See if matrix a starts with matrix b
%   Given that a and b are the same shape, but perhaps different sizes,
%   test that matrix a has matrix b as a sub-matrix
%   For example, in the 2d case:
%   > a = [1 2 3 4;    > b = [1 2;
%   >      5 6 7 8];   >      5 6];
%   a(1:2,1:2) == b, so this would return true

assert(ismatrix(a)&&ismatrix(b),'Inputs must be matrices.');
sza = size(a);
szb = size(b);
assert(length(sza)==length(szb),'Matrix shapes must agree.')

starts_with = false; % Assume false
if isa(a,'cfit') && isa(b,'cfit') % cfit is special since indexing evaluates fit at that value
    starts_with = isequal(a,b);
    return 
elseif isa(a,'cfit')
   % Special case where cfit.subsref will fail
   return % If a is a cfit and b is not, obviously not equal
end
if any(szb>sza)
    % Trivial case of b being larger than a (e.g. b=[1,2,3,4] cant be a
    % subset of a=[1,2])
    return
end
% Build indexing structure
S = struct('type','()','subs',{cell(0)});
for i = 1:length(szb)
    S.subs(end+1) = {1:szb(i)};
end
try
    sub_a = subsref(a,S);
catch err
    error('Failed to evaluate subsref for type %s: \n%s.',class(a),err.message);
end
starts_with = isequaln(sub_a,b);
end

