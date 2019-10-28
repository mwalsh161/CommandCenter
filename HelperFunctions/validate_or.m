function validate_or( A, varargin  )
%VALIDATE_OR Takes an object and any number of cell arrays or properties
%   to validate and throws an error if all the validations return false.
%
% validate_or(A, attributes_to_validate_1, attributes_to_validate_2, ...)
%   A: object to validate
%   attributes_to_validate_i: cell array to be used as the input for
%    validateattributes.

err = '';

% Loop through all validates attributes
for i = 1:numel(varargin)
    validate_input = {A, varargin{i}{:} };

    try
        validateattributes( validate_input{:} )

        return % Return if valid
    catch err_i
        err = sprintf('%s\n%s', err, err_i.message); % Otherwise add error message to list
    end
end

% Throw error message if no attributes are valid
error(sprintf('Object matches none of the attributes:%s', err))