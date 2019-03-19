function temp = run_test(obj,name,set,get,expectedOutput)
%name: string describing the test
%test: fn handle to execute test.
%	0 inputs, 1 output of any type
%expectedOutput: exact output the test() should return
temp.name = name;
temp.output=[];
try
    set();
    out = get();
    temp.output=out;
    assert(isequal(out,expectedOutput),'Unexpected output');
    temp.success = true;
    temp.err = [];
    msg = sprintf('Passed %s',temp.name);
catch err
    temp.success = false;
    temp.err = err;
    msg = sprintf('Failed %s',temp.name);
end
obj.logger.log(msg)
drawnow;
assert(~obj.abort_request,'User aborted');
end