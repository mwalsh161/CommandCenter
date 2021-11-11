function channel  =  sshfrommatlab(userName,hostName,port,password)
%SSHFROMMATLAB connects Matlab to a remote computer via a secure shell
%
% CONN  =  SSHFROMMATLAB(USERNAME,HOSTNAME,PASSWORD)
%
% Inputs:
%   USERNAME is the user name required for the remote machine
%   HOSTNAME is the name of the remote machine
%   PASSWORD is the password for the account USERNAME@HOSTNAME
%
% Outputs:
%   CONN is a Java ch.ethz.ssh2.Connection object
%
% See also SSHFROMMATLABCLOSE, SSHFROMMATLABINSTALL, SSHFROMMATLABISSUE
%
% (c) 2008 British Oceanographic Data Centre
%    Adam Leadbetter (alead@bodc.ac.uk)
%     2010 Boston University - ECE
%    David Scott Freedman (dfreedma@bu.edu)
%    Version 1.3
%

%
%  Invocation checks
%
  if(nargin  ~=  4)
    error('Error: SSHFROMMATLAB requires 3 input arguments...');
  end
  if(~ischar(userName)  || ~ischar(hostName)  ||  ~ischar(password))
    error...
      (['Error: SSHFROMMATLAB requires all input ',...
      'arguments to be strings...']);
  end
%
%  Build the connection using the JSch package
%
import ch.ethz.ssh2.*;
try
    channel  =  Connection(hostName,port);
    channel.connect();
catch err
    error(['Error: SSHFROMMATLAB could not connect to the'...
        ' remote machine %s ...'],...
        hostName);
end
%
%  Check the authentication for login...
%
  isAuthenticated = channel.authenticateWithPassword(userName,password);
  if(~isAuthenticated)
    error...
      (['Error: SSHFROMMATLAB could not authenticate the',...
        ' SSH connection...']);
  end