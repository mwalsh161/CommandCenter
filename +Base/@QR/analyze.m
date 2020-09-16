function [row,col,version,legacy_error] = analyze(code)
% ANALYZE takes in a code/bit sequence to decode it into its components.
%   INPUT:
%       code: vector of length Base.QR.length, of anything that can convert
%           to a char array (double, logical, char, etc.).
%   OUTPUT (contents of the decoded code):
%       row: scalar integer
%       col: scalar integer
%       version: scalar integer
%       legacy_error: scalar logical. This refers to an error in some older
%           python code that generated the GDS files.

if ~ischar(code)
    try
        code = num2str(code,'%i');
    catch
        error('Failed to convert type ''%'' to char array.',class(code))
    end
end
assert(length(code)==Base.QR.length,'Code is the wrong size (must be vector)')
if size(code,1) > 1 % Make sure a row vector (important for padVal)
    code = code';
end
% Make sure pad is correct, then remove
padVal = num2str(ones(1,numel(Base.QR.pad))*Base.QR.padVal,'%i');
legacy_error = false;
if ~strcmp(code(Base.QR.pad),padVal)
    % There was a flaw in some of the generation code, so
    % attempt altering code to "fix" by swapping bit 5 and 6
    assert(strcmp(code([1 6]),padVal),'Padding bits are incorrect.')
    legacy_error = true;
    code([1 6]) = [];
else
    code(Base.QR.pad) = [];
end
p = 1; % Pointer into code
version = decode(Base.QR.vb,'version');
row = decode(Base.QR.rb,'row');
col = decode(Base.QR.cb,'column');
checksum = decode(Base.QR.cs,'checksum');
% Remove checksum, and test
code(end-Base.QR.cs+1:end) = [];
observed_checksum = mod(sum(code=='1'),2^Base.QR.cs);
if observed_checksum ~= checksum
    if legacy_error
        warning('Checksum failure was after a pad failure and attempt to address the legacy error.')
    end
    error('Checksum failed.')
end
if version > 5 && legacy_error
    warning('Had to correct for padding error that SHOULD NOT exist in versions > 5! Tell mpwalsh@mit.edu immediately.');
end
% Helper function to decode and error check
    function val = decode(n,name)
        val = bin2dec(code(p:p + n - 1));
        assert(~isempty(val),...
            sprintf('No %s decoded, check Base.QR constants for consistency.',name));
        p = p + n;
    end
end