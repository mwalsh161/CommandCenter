function fprintf(obj, varargin )
%FPRINTF See serial/fprintf

% convert to char in order to accept string datatype
varargin = instrument.internal.stringConversionHelpers.str2char(varargin);

% Parse the input.
switch (nargin)
case 1
   error(message('MATLAB:serial:fprintf:invalidSyntaxCmd'));
case 2
   % Ex. fprintf(obj, cmd); 
   cmd = varargin{1};
   format = '%s\n';
   mode = 0;
case 3
   % Original assumption: fprintf(obj, format, cmd); 
   [format, cmd] = deal(varargin{1:2});
   mode = 0;
   if ~(isa(cmd, 'char') || isa(cmd, 'double'))
	   error(message('MATLAB:serial:fprintf:invalidArg'));
   end
   
   if strcmpi(cmd, 'sync') 
       % Actual: fprintf(obj, cmd, mode);
       mode = 0;
       cmd = format;
       format = '%s\n';
   elseif strcmpi(cmd, 'async') 
       % Actual: fprintf(obj, cmd, mode);
       mode = 1;
       cmd = format;
       format = '%s\n';
   end
   if any(strcmp(format, {'%c', '%s'}))
       % Check if cmd contains elements greater than one byte.
       if any(cmd(:) > 255)
           % Turn off backtrace momentarily and warn user
           warning('off', 'backtrace');
           warning(message('MATLAB:serial:fprintf:DataGreaterThanOneByte'));
           warning('on', 'backtrace');
           % Upper limit of cmd values should be 255.
           cmd(cmd > 255) = 255;
       end
   end
case 4
   % Ex. fprintf(obj, format, cmd, mode); 
   [format, cmd, mode] = deal(varargin{1:3}); 
   
   if ~ischar(mode)
	   error(message('MATLAB:serial:fprintf:invalidMODE'));
   end
   
   switch lower(mode)
   case 'sync'
       mode = 0;
   case 'async'
       mode = 1;
   otherwise
	   error(message('MATLAB:serial:fprintf:invalidMODE'));
   end
otherwise
   error(message('MATLAB:serial:fprintf:invalidSyntaxArgv'));
end

% Error checking.
if ~isa(format, 'char')
	error(message('MATLAB:serial:fprintf:invalidFORMATstring'));
end
if ~(isa(cmd, 'char') || isa(cmd, 'double'))
	error(message('MATLAB:serial:fprintf:invalidCMD'));
end

% Format the string.
[formattedCmd, errmsg] = sprintf(format, cmd);
if ~isempty(errmsg)
    error(message('MATLAB:serial:fprintf:invalidFormat', errmsg));
end

% Clean the string
formattedCmd = obj.escapeString(formattedCmd);

% Call serial/fprintf
if mode
    mode = 'async';
else
    mode = 'sync';
end
fprintf(obj.serial,'%s',formattedCmd,mode)

end

