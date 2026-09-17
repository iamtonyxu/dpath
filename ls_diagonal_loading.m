% ls_diagonal_loading.m
% 最小二乘模型求解的"坏矩阵"问题，以及业界通用的对角加载（ridge / Tikhonov /
% Levenberg-Marquardt 阻尼）解法。
%
% 演示要点：
%   1. 法方程 (A'*A) 的条件数是 A 的平方；即便 A'*A 通过正定判别（chol 成功、
%      最小特征值 > 0），解仍可能发散 —— 正定 不等于 良态。
%   2. 在 A'*A 的对角线加微扰 lambda*I（对角加载）后，条件数被压到
%      (s_max^2 + lambda) / (s_min^2 + lambda)，解被稳定。
%   3. lambda 的取舍：太小仍发散，太大过度收缩（有偏），中间存在最优，可用
%      L 曲线 / GCV / 交叉验证选取。

clear; close all; clc;

% 抑制 MATLAB 对病态矩阵的重复警告：这个警告本身就是本脚本要说明的"症状"，
% 条件数已在下方显式打印，避免 lambda 扫频时刷屏。
warning('off','MATLAB:nearlySingularMatrix');

%% 1. 构造一个病态的最小二乘问题 ---------------------------------------
N = 200;                 % 观测点数
P = 15;                  % 参数（回归元）个数

rng(1);
t  = sort(rand(N,1));                 % 采样点
A  = zeros(N,P);
for k = 1:P
    A(:,k) = t.^(k-1);                % 单项式基 1, t, t^2, ...（Vandermonde，经典病态）
end

theta_true = 0.1 * sin((1:P)' / 2);   % 真实参数（量级小，便于凸显发散）
b_true     = A * theta_true;
b          = b_true + 1e-3 * randn(N,1);   % 观测 = 无噪声模型 + 小噪声

%% 2. 条件数分析 --------------------------------------------------------
G = A' * A;                           % 法方程矩阵（Gram）
fprintf('cond(A)      = %10.3e\n', cond(A));
fprintf('cond(A''*A)  = %10.3e    <-- 平方放大\n', cond(G));
fprintf('min eig(G)   = %10.3e\n', min(eig(G)));

%% 3. "正定判别"的陷阱 ------------------------------------------------
% 矩阵确实是正定的（chol 成功、特征值全正），但无正则解仍然发散。
[R, p] = chol(G);
fprintf('\nchol(G) 退出标志 p = %d   (p==0 表示 G 通过正定判别)\n', p);

theta_ne  = G \ (A'*b);               % 法方程最小二乘  (== A\b，但数值更脆)
theta_qr  = A \ b;                    % QR/SVD 反斜杠（更稳，避免平方）
theta_opt = theta_true;               % 参考：真实参数

fprintf('\n                   ||theta||      ||theta - true||\n');
fprintf('真实参数          %12.4g     %12.4g\n', norm(theta_true), 0);
fprintf('法方程 LS         %12.4g     %12.4g\n', norm(theta_ne), norm(theta_ne - theta_true));
fprintf('QR  LS (A\\b)     %12.4g     %12.4g\n', norm(theta_qr), norm(theta_qr - theta_true));

%% 4. 对角加载（加微扰）------------------------------------------------
lambda_list = logspace(-16, 2, 60);
nlam = numel(lambda_list);

norm_theta  = zeros(nlam,1);          % 解范数（收缩程度）
err_theta   = zeros(nlam,1);          % 参数恢复误差
pred_mse    = zeros(nlam,1);          % 测试集预测 MSE
cond_reg    = zeros(nlam,1);          % 正则化后条件数

% 独立测试集（无噪声），用于衡量泛化而非拟合
rng(2);
tt = sort(rand(N,1));
At = zeros(N,P);
for k = 1:P
    At(:,k) = tt.^(k-1);
end
bt = At * theta_true;

for i = 1:nlam
    lam = lambda_list(i);
    th  = (G + lam*eye(P)) \ (A'*b);
    norm_theta(i) = norm(th);
    err_theta(i)  = norm(th - theta_true);
    pred_mse(i)   = mean((At*th - bt).^2);
    cond_reg(i)   = cond(G + lam*eye(P));
end

% 最优 lambda（按参数误差；实际工程中换成 L 曲线 / GCV / 交叉验证）
[~, iopt] = min(err_theta);
lam_opt = lambda_list(iopt);

fprintf('\n最优 lambda（按参数误差） = %.3g\n', lam_opt);
fprintf('对角加载@最优:    ||theta|| = %.4g   ||theta-true|| = %.4g\n', ...
    norm_theta(iopt), err_theta(iopt));
fprintf('无正则(QR) 误差放大倍数 = %.3g\n', norm(theta_qr - theta_true) / err_theta(iopt));

%% 5. 可视化 ------------------------------------------------------------
figure('Name','LSM 对角加载','NumberTitle','off');

subplot(2,2,1);
loglog(lambda_list, norm_theta, 'b-', 'LineWidth',1.2); hold on;
yline(norm(theta_true), 'r--', '||true||');
xline(lam_opt, 'k--', sprintf('\\lambda^*=%.1e', lam_opt));
xlabel('\lambda'); ylabel('||\theta(\lambda)||');
title('解范数随 \lambda 单调收缩'); grid on;

subplot(2,2,2);
semilogx(lambda_list, err_theta, 'b-', 'LineWidth',1.2); hold on;
xline(lam_opt, 'k--');
xlabel('\lambda'); ylabel('||\theta - \theta_{true}||');
title('参数恢复误差（U 形，存在最优）'); grid on;

subplot(2,2,3);
loglog(lambda_list, cond_reg, 'b-', 'LineWidth',1.2); hold on;
yline(cond(G), 'r--', '无正则 \kappa(G)');
xlabel('\lambda'); ylabel('\kappa(G+\lambda I)');
title('条件数随 \lambda 单调下降'); grid on;

subplot(2,2,4);
semilogx(lambda_list, pred_mse, 'b-', 'LineWidth',1.2); hold on;
xline(lam_opt, 'k--');
xlabel('\lambda'); ylabel('测试集预测 MSE');
title('泛化误差（bias-variance 折中）'); grid on;

fprintf('\n演示完成。\n');
