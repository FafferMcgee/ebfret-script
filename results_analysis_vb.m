function [summary_short summary_long] = results_analysis_vb(out,zhat,mu_true,zPath,xPath,Aobs)

N = length(out);
zeta = zeros(1,N);
smooth = cell(1,N);
% get the difference between kguess and ktrue
kdiff = zeros(1,N);
kfrac = zeros(1,N);
% sensitvity and specificity
true_neg = zeros(1,N); true_pos = zeros(1,N);
false_neg = zeros(1,N); false_pos = zeros(1,N);

% A dkl
A0 = zeros(length(mu_true{1}));
A = zeros(length(mu_true{1}));
% log evidence
LP = zeros(1,N);
% convergance time
niter = zeros(1,N);

for n = 1:N
    A0 = A0 + Aobs{n}{1};
    A = construct_A(A,out{n}.Wa,out{n}.Wa,length(Aobs{1}{1}));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [zeta(n) smooth{n}] = zeta_calc(zPath{n},zhat{n},0.1,mu_true{n},out{n}.m);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    ktrue = length(unique(zPath{n}));
    kobs = length(unique(zhat{n}));
    kdiff(n) = (kobs-ktrue);
    kfrac(n) = kobs==ktrue;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    diff_true = diff(xPath{n});
    diff_obs = diff(smooth{n}); 
    % true pos = transion correctly identified as transition
    true_pos(n) = true_pos(n) + sum(diff_true(diff_true~=0) == diff_obs(diff_true~=0));
    % False pos = no transition identified as transition 
    false_pos(n) = false_pos(n) + sum(diff_true(diff_true==0) ~= diff_obs(diff_true==0));
    % true neg = no transition correctly identified as no transition
    true_neg(n) = true_neg(n) + sum(diff_true(diff_true==0) == diff_obs(diff_true==0));
    % false neg = transition identified no transition 
    false_neg(n) = false_neg(n) + sum(diff_true(diff_true~=0) ~= diff_obs(diff_true~=0));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    LP(n) = out{n}.F(end);
    niter(n) = length(out{n}.F);
end

A0 = normalize(A0,2)';
A = normalize(A,2)';

q0=null(A0-eye(length(A0)));q0=q0/sum(q0(:));
Adkl=sum(A0.*log(A0./A),1)*q0;

summary_short.kfrac = mean(kfrac);
summary_short.zeta = mean(zeta);
summary_short.sens = sum(true_pos) / sum(true_pos + false_neg);
summary_short.spec = sum(true_neg) / sum(true_neg + false_pos);
summary_short.LP = sum(LP);
summary_short.niter = mean(niter);
summary_short.Adkl = Adkl;
summary_short.A = A';

summary_long.kfrac = kfrac;
summary_long.zeta = zeta;
summary_long.sens = true_pos ./ (true_pos + false_neg);
summary_long.spec = true_neg ./ (true_neg + false_pos);
summary_long.LP = LP;
summary_long.niter = niter;

function A = construct_A(A,Wa,mu,Ktrue)
% this assumes states go from lowest to highest and orders matrix
% accordingly
if length(mu) ~= Ktrue
    return
end
[ig S] = sort(mu);
Atemp = zeros(Ktrue);
for i=1:Ktrue
    for j = 1:Ktrue
        Atemp(i,j) = Wa(S(i),S(j));
    end
end
A = A + Atemp;