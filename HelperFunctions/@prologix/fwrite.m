function fwrite(obj, varargin )
%FWRITE See serial/fwrite


% convert to char in order to accept string datatype
varargin = instrument.internal.stringConversionHelpers.str2char(varargin);

% Parse the input.
switch nargin
case 1
   error(message('MATLAB:serial:fwrite:invalidSyntaxA'));
case 2
   cmd = varargin{1};
   precision = 'uchar';
   mode = 0;	
case 3
   % Original assumption: fwrite(obj, cmd, precision); 
   [cmd, precision] = deal(varargin{1:2});
   mode = 0;

   if ~(isa(precision, 'char') || isa(precision, 'double'))
	   error(message('MATLAB:serial:fwrite:invalidArg'));
   end
   
   if strcmpi(precision, 'sync') 
       % Actual: fwrite(obj, cmd, mode);
       mode = 0;
       precision = 'uchar';
   elseif strcmpi(precision, 'async') 
       % Actual: fwrite(obj, cmd, mode);
       mode = 1;
       precision = 'uchar';
   end
case 4
   % Ex. fprintf(obj, format, cmd, mode); 
   [cmd, precision, mode] = deal(varargin{1:3}); 
   
   if ~ischar(mode)
	   error(message('MATLAB:serial:fwrite:invalidMODE'));
   end
   
   if strcmpi(mode, 'sync')
       mode = 0;
   elseif strcmpi(mode, 'async')
       mode = 1;
   else
       error(message('MATLAB:serial:fwrite:invalidMODE'));
   end
otherwise
   error(message('MATLAB:serial:fwrite:invalidSyntaxArgv'));
end   

% Error checking.
if ~isa(precision, 'char')
	error(message('MATLAB:serial:fwrite:invalidPRECISIONstring'));
end
if ~(isnumeric(cmd) || ischar(cmd))
	error(message('MATLAB:serial:fwrite:invalidA'));
end

% Escape characters
cmd = obj.escapeBinary(cmd);

% Call serial/fwrite
if mode
    mode = 'async';
else
    mode = 'sync';
end
fwrite(obj.serial,cmd,precision,mode)

end

