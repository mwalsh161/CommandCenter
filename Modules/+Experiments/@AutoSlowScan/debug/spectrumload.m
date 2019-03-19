function sp=spectrumload(filename)
%
% sp=spectrumloadmat(filename)
%   Loads Roper WinSpec .spe files into a matlab structure
%   with various header information fields and data
%   in the x and y fields

if nargin > 0,
    %extract wavelength calibration
    if exist(filename)~=2 
        if exist([filename '.spe'])==2
            filename=[filename '.spe'];
        else
            return;
        end
    end

else
        [fn,fp] = uigetfile({'*.*'},'Select SPE file');
        if fp,
           filename = fullfile(fp,fn);
           sp=[];
        else,
            return
         end
end

fid = fopen(filename, 'r');

if fid==-1 
    errordlg('Can''t read file (insufficient rights?)!');
    sp=[];
    return
end

sp=readheader(fid);

%read actual data and store columnwise in .y field
fseek(fid,4100,'bof');

switch sp.Datatype
    case 0
        typ='float32'; 
    case 1
        typ='int32'; %seems to work for many of our files
    case 2
        typ='int16';
    case 3
        typ='uint16';
end

for i=1:sp.NumFrames
    sp.y(:,i)=fread(fid,sp.xdim,[typ '=>double']);
end

fclose(fid);

%create wavelength axis from calibration polynomial and store a .x column
sp.x=(sp.Calibpoly(1)+...
      sp.Calibpoly(2)*(sp.startx:sp.startx+sp.xdim-1)+...
      sp.Calibpoly(3)*(sp.startx:sp.startx+sp.xdim-1).^2)';

return
  
function header=readheader(fid)

%each entry in headerinfo corresponds to data that is read into the header
%structure of the resulting Matlab spectrum structure
%fields are: Name, Offset (Byte number in .spe file), Type (Datatype),
%Length (for Arrays of Type), and Load (whether or not this item should be
%read)
c=1;
headerinfo(c)=struct('Name','Date',     'Offset',20,  'Type','char',   'MType','char',  'Length',10,'Transpose',1,'Load',1); c=c+1;
headerinfo(c)=struct('Name','xdim',     'Offset',42,  'Type','uint16', 'MType','double','Length',1, 'Transpose',1,'Load',1); c=c+1;
headerinfo(c)=struct('Name','Datatype', 'Offset',108, 'Type','int16',  'MType','double', 'Length',1, 'Transpose',1,'Load',1); c=c+1;
headerinfo(c)=struct('Name','NumFrames','Offset',1446,'Type','int32',  'MType','double','Length',1, 'Transpose',1,'Load',1); c=c+1;
headerinfo(c)=struct('Name','startx',   'Offset',1512,'Type','uint16', 'MType','double','Length',1, 'Transpose',1,'Load',1); c=c+1;
headerinfo(c)=struct('Name','Calibpoly','Offset',3263,'Type','float64','MType','double','Length',6, 'Transpose',1,'Load',1); c=c+1;
headerinfo(c)=struct('Name','BckGrdApplied','Offset',150,'Type','char','MType','double', 'Length',1, 'Transpose',1,'Load',1); c=c+1;
headerinfo(c)=struct('Name','FltFldApplied','Offset',706,'Type','char','MType','double', 'Length',1, 'Transpose',1,'Load',1); c=c+1;

for i=1:length(headerinfo)
    if headerinfo(i).Load
        fseek(fid,headerinfo(i).Offset,'bof');
        if headerinfo(i).Transpose
            header.(headerinfo(i).Name)=fread(fid,headerinfo(i).Length,[headerinfo(i).Type '=>' headerinfo(i).MType])';
        else
            header.(headerinfo(i).Name)=fread(fid,headerinfo(i).Length,[headerinfo(i).Type '=>' headerinfo(i).MType]);
        end 
    end
end

return
