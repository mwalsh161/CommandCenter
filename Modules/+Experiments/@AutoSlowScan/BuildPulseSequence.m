function [ varargout ] = BuildPulseSequence(greentime,redtime,averages)
%BuildPulseSequence Builds pulse sequence at single frequency point for 
%slow scan
%   greentime = duration of green pulse in us
%   redtime = duration of red pulse in us
%   averages = number of repetitions (limited to 2^20 = 1048576)

s = sequence('SlowScan');
greenchannel = channel('Green','color','g','hardware',3);
redchannel = channel('Red','color','r','hardware',11);
APDchannel = channel('APDgate','color','b','hardware',0,'counter','APD1');
s.channelOrder = [greenchannel, redchannel, APDchannel];
g = node(s.StartNode,greenchannel,'delta',0);
g = node(g,greenchannel,'units','us','delta',greentime);
r = node(g,redchannel,'delta',0);
node(r,APDchannel,'delta',0);
r = node(r,redchannel,'units','us','delta',redtime);
node(r,APDchannel,'delta',0);
s.repeat = averages;
varargout = {s, g, r};
end

