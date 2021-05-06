function tf = test(s,e)
    while isa(s, 'matlab.ui.container.Menu')
        s = s.Parent;
    end
    delete(s)
    tf = true
end