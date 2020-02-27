function code = uigetcode(path,beginning_text,ending_text)
%UIGETCODE Present window for user to enter code and return result
%   This will open an editor for user to enter code within a function block
%   and wait until saved and closed before returning what was entered.
%   Note, if the user decides on not saving the file; an empty char array
%   is returned.
% Inputs: parenthesis indidcate optional positional arguments
%   path: Full pathname of file that gets generated.
%   (beginning_text):* If supplied, this will appear at the beginning.
%   (ending_text):* If supplied, this will appear after the end of the fn.
%   * Be sure to include newlines and the "%" on each line if you want it
%       appear as a MATLAB comment.
% Outputs:
%   code: char array of code entered by user

% Note other potentiall useful functions (undocumented):
%   doc.JavaEditor.setStatusText('foo');
% Note, this has a pretty high overhead for a relatively simple task; but I
%   couldn't find documented or undocumented techniques to get the simple
%   editor that is used when you want to edit a datatip for example.

if nargin < 2
    beginning_text = '';
end
if nargin < 3
    ending_text = '';
end

pre =  [beginning_text newline,...
        '% When finished, you can save and close this window to continue',newline,...
        '%    (don''t change the filename or path)', newline,...
        '%    (only edit inside the function)', newline newline,...
        'function transition()' newline];
post = [newline 'end' newline ending_text];
nPre = length(pre);
nPost = length(post);

init = [pre, newline, post];
doc = matlab.desktop.editor.findOpenDocument(path);
if isempty(doc)
    doc = matlab.desktop.editor.newDocument(init);
    doc.saveAs(path);
else % Reset
    doc.Text = init;
end
lastGoodSpot = nPre;
doc.JavaEditor.setCaretPosition(lastGoodSpot);
doc.makeActive();

while doc.Opened
    try
        cursor = doc.JavaEditor.getCaretPosition();
        % Jail cursor to within function (note use could slip outside
        % between lines of this while loop; these are separate threads.
        if  cursor < nPre || cursor > doc.JavaEditor.getLength()-nPost
            doc.JavaEditor.setCaretPosition(lastGoodSpot);
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
% Just in case the user found a way out of the cursor jail generator by
% while loop above.
assert(still_valid(contents),'You edited outside the function!');
% Parse out code in function
contents = strip(contents);
code = strip(contents(length(pre)+1:end-length(post)));

    function tf = still_valid(val)
        val(val==char(13)) = ''; % Remove carriage returns
        tf = startsWith(val,pre) && endsWith(val,post);
    end
end