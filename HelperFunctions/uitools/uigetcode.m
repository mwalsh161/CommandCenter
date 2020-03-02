function [code,fn_name] = uigetcode(path,fn_name,beginning_text,ending_text,edit_fn_name)
%UIGETCODE Present window for user to enter code and return result
%   This will open an editor for user to enter code within a function block
%   and wait until saved and closed before returning what was entered.
%   Note, if the user decides on not saving the file; an empty char array
%   is returned.
% Inputs: parenthesis indidcate optional positional arguments
%   path: Full pathname of file that gets generated.
%   fn_name: Name of function to be used. If edit_fn_name is true, this is
%       the placeholder.
%   (beginning_text):* If supplied, this will appear at the beginning.
%   (ending_text):* If supplied, this will appear after the end of the fn.
%   (edit_fn_name): Default false. Allows user to edit function name. The
%       function name is returned.
%   * Be sure to include newlines and the "%" on each line if you want it
%       appear as a MATLAB comment.
% Outputs:
%   code: char array of code entered by user
%   fn_name: the function name set by the user if allowed, or the same as
%       the input name given. This is only validated as a valid name if the
%       user chooses (e.g. edit_fn_name = true input).

% Note, this has a pretty high overhead for a relatively simple task; but I
%   couldn't find documented or undocumented techniques to get the simple
%   editor that is used when you want to edit a datatip for example.

if nargin < 3
    beginning_text = '';
end
if nargin < 4
    ending_text = '';
end
if nargin < 5
    edit_fn_name = false;
end

% Define contents from bottom up
post = [newline 'end' newline ending_text newline newline,...
        '%#ok<*FNDEF> Ignores filename/function name mismatch.'];
fn = [fn_name '()' newline];
pre =  [beginning_text newline,...
        '% When finished, you can save and close this window to continue',newline,...
        '%    (don''t change the filename or path)', newline];
if edit_fn_name
    pre = [pre ,...
        '%    (add a function name)', newline,...
        '%    (edit inside the function)', newline newline,...
        'function '];
    % Keep fn separate from pre
    init = [pre, fn, newline, post];
else
    pre = [pre ,...
        '%    (only edit inside the function)', newline newline,...
        'function ' fn]; % Add fn to pre
    init = [pre, newline, post];
end
nPre = length(pre);
nPost = length(post);

doc = matlab.desktop.editor.findOpenDocument(path);
if isempty(doc)
    doc = matlab.desktop.editor.newDocument(init);
    doc.saveAs(path);
else % Reset
    doc.Text = init;
end
% Prepare cursor
lastGoodSpot = nPre;
doc.JavaEditor.setCaretPosition(lastGoodSpot);
if edit_fn_name % Highlight placeholder
    [line, start] = doc.indexToPositionInLine(lastGoodSpot);
    doc.Selection = [line start line start+length(fn_name)];
end
doc.makeActive();

while doc.Opened
    % Jail cursor to within function (note use could slip outside
    % between lines of this while loop; these are separate threads.
    try
        % NOTE: len and cursor are NOT atomic, so we will check if it
        % changed while cursor updated.
        len = doc.JavaEditor.getLength();
        cursor = doc.JavaEditor.getCaretPosition();
        if doc.JavaEditor.getLength() ~= len; continue; end % Typing/cutting/pasting
        if  cursor < nPre || cursor > len-nPost
            doc.JavaEditor.setCaretPosition(lastGoodSpot);
            doc.JavaEditor.setStatusText(...
                sprintf('Stay in the function! (%i; %i-%i)',cursor,nPre,len-nPost));
        else
            lastGoodSpot = cursor;
        end
    catch err
        if ~(strcmp(err.identifier,'MATLAB:Java:GenericException') &&...
             contains(err.message,'java.lang.NullPointerException')) &&...
             ~strcmp(err.identifier,'MATLAB:Editor:Document:EditorClosed')
            rethrow(err)
        end
    end
end
% Get contents of file
fid = fopen(path,'r');
contents = fread(fid);
fclose(fid);
contents(contents==13) = []; % Remove carriage returns
contents = char(contents');

% Get function name
endfn = nPre + find(contents(nPre+1:end)==newline | ...
                    contents(nPre+1:end)=='(',1);
fn_name = contents(nPre+1:endfn-1);
% Parse out code in function
if edit_fn_name
    % This time we don't care about the '('; just the newline
    endfn = endfn + find(contents(endfn:end)==newline,1);
    % No plus one, because find is 1-based indexing, so does it for us
    code = strip(contents(endfn:end-nPost));
else
    code = strip(contents(nPre+1:end-nPost));
end

% Just in case the user found a way out of the cursor jail generator by
% while loop above.
[write_region_ok,fn_name_ok] = still_valid(contents);
if ~write_region_ok && ~fn_name_ok
    error('You edited outside the function and function name not valid!');
elseif ~write_region_ok
    error('You edited outside the function.');
elseif ~fn_name_ok % Note always true if fn_name input was not empty
    error('"%s" is not a valid function name.',fn_name);
end

    function [write_region_ok,fn_name_ok] = still_valid(val)
        val(val==char(13)) = ''; % Remove carriage returns
        write_region_ok = startsWith(val,pre) && endsWith(val,post);
        if edit_fn_name
            remainder = val(nPre+1:end);
            endfn = nPre + find(remainder==newline | remainder == '(',1);
            name = val(nPre+1:endfn-1);
            fn_name_ok = isvarname(name);
        else
            fn_name_ok = true;
        end
    end
end