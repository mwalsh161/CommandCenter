function program = mergePulseSequence( varargin )
    %MERGEPULSESEQUENCE(program1, program2, ...) concatenate together multiple compiled pulse blaster pograms
    %   This is primarily intended to get around the fact that the sequence function can currently only repeat the whole sequence, not subsections. mergePulseSequence takes multiple compiled programs from sequence.compile (potentially each with their own loop) and concatenates them in the order that they are given. This does not allow for nested loops.
    %   program1, program2, ... : Outputs from sequence.compile.

    program = {};
    for i = 1:nargin
        programi = varargin{i};

        % Only part START statement from first program should remain
        if i ~= 1
            programi{1}(1:6) = '      ';
        end

        % Only 100 ms delay & STOP from last statement should remain
        if i~= nargin
            programi = {programi{1:numel(programi)-2}}';
        end

        % Merge with main program
        program = [program; programi];
    end
end