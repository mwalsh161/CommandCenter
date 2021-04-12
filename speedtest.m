function speedtest()
    s = 1000;
    d = 2;

    if true
        tic
        d = NaN(1,s*s);
        for x = 1:100
            d(1:s) = rand(1,s);
            dat = reshape(d,s,s);
        end
        toc
    else
        tic
        dat = NaN(s,s);
        for x = 1:100
            S.type = '()';
            S.subs = {1, ':'};
            dat = subsasgn(dat, S, rand(1,s));
        end
        toc
    end
end