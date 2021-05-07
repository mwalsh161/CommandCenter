hw = hwserver('localhost')

tic


for x = 1:10
    hw.com('Arduino', '?');
%     hw.com('PulseBlaster', 'getLines');
end

t = toc



% goto(x_um)