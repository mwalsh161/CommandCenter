function [ decision, lambda, estimate ] = BinaryUnkownDistTest( ref0, ref1, sample, p0 )
%BinaryUnkownDistTest if a sample data set is more like one of two possible
%reference datasets.
%   Tests if it is more likely that the sample came from the same
%   distribution as reference sample 0 or 1. This is accomplished by
%   performing a likelihood ratio test of the t-statistic for two unpaired
%   samples of unequal sample size and variance between the ref0-sample and
%   ref1-sample. Assumes a prior probabilities p(dist. 0)=p(dist. 1)=1/2
%   unless otherwise specified.
%   
% Inputs:
%   ref0: vector array of values for sample known to come from dist. 0. Must
%         have >1 observation.
%   ref1: vector array of values for sample known to come from dist. 1. Must
%         have >1 observation.
%   sample: vector array of values from sample to test. Must have >1
%           observation.
%
% Outputs:
%   decision: Boolean whether sample is closer to reference sample 0 or 1.
%   lambda: likelihood ratio.
%   estimate: re-scaled likelihood ratio to give metric between 0 and 1.

assert(numel(ref0)>1,'Reference sample 0 must have more than 1 observation')
assert(numel(ref1)>1,'Reference sample 1 must have more than 1 observation')
assert(numel(sample)>1,'Sample must have more than 1 observation')

% Check if p0 was given, otherwise give default
if ~exist('p0','var')
    p0 = 0.5;
end

% calculate likelihood ratio
lambda = likelihood( ref1, sample)/likelihood( ref0, sample);

% prior odds ratio
lambda_critical = p0/(1-p0);

% calculate decision
decision = (lambda > lambda_critical);

% calculate confidence metric
estimate = lambda/lambda_critical;
estimate = estimate/(1+estimate);

end

function t = likelihood( sample1, sample2 )
% calculate t-statistic likelihood for samples 1 and 2
% find means, variances and lengths
m1 = mean(sample1);
m2 = mean(sample2);
s1sqr = var(sample1);
s2sqr = var(sample2);
n1 = numel(sample1);
n2 = numel(sample2);

% define pooled standard deviation
sp = sqrt(((n1-1)*s1sqr+(n2-1)*s2sqr)/(n1+n2-2));

% define t-statistic
T = (m1-m2)/(sp*sqrt(1/n1+1/n2));

% define degrees of freedom
nu = n1+n2-2;

% return likelihood
t = tpdf(T, nu);
end