clear all
Const.rpm = pi / 30;
Engine_external_charascteristic_curve_data = 'D_2876_LF_04_EURO_3';
%% Pre-processing of variables
Way2EngineParametr = ['Engine_parametr/', ...
Engine_external_charascteristic_curve_data];
Omega_file = [Way2EngineParametr, '_w', '.txt'];
Torque_file = [Way2EngineParametr, '_t', '.txt'];
Fuel_file = [Way2EngineParametr, '_ge', '.txt'];
Moment_coeff = 0.25:0.05:1;   % % % % Part load moment
% Reading_engine_data
Engine.W_e = readArrayFromTxt(Omega_file) * Const.rpm;   % рад/с
T_e        = readArrayFromTxt(Torque_file);               % Н·м, 1×N_w
Ge_e       = readArrayFromTxt(Fuel_file);                  % г/(кВт·ч), 1×N_w
Ge_e =1;

    [Engine.G_e] ...           % ge_graf  - load characteristic matrix
    = Shlipce_part_load_characteristic( ...
    min(Ge_e), ...      % specific fuel consumption data
    0.25:0.05:1, ...
    Engine.W_e...              % speed range data
    );

    % Для единообразия выходов:
    Engine.T   = T_e * Moment_coeff';      % заглушка, чтобы дальше не падало
    w_load     = Engine.W_e;
    X_opt      = []; 
    
figure('Color','w','Position',[100 100 1400 600]);

subplot(1,2,1);
contourf(Engine.W_e*Const.rpm, Engine.T, Engine.G_e, 20, 'LineColor','none');
hold on; contour(Engine.W_e*Const.rpm, Engine.T, Engine.G_e, 10, 'k');
colorbar;
xlabel('Частота вращения, rpm'); ylabel('Момент, Н\cdotм');
title('Изолинии g_e (вид сверху)'); grid on;

subplot(1,2,2);
surf(Engine.W_e*Const.rpm, Engine.T, Engine.G_e, 'EdgeColor','none');
shading interp; colormap turbo; colorbar;
xlabel('Частота вращения, rpm'); ylabel('Момент, Н\cdotм');
zlabel('g_e, г/(кВт\cdotч)');
title('3D-поверхность g_e(\omega, T)'); grid on; view(45, 30);
  
fprintf('size(G_e)   = %s\n', mat2str(size(Engine.G_e)));
fprintf('size(T)     = %s\n', mat2str(size(Engine.T)));
fprintf('numel(Omega)= %d\n', numel(Engine.W_e));
fprintf('numel(Power)= %d\n', numel(Engine.T));
fprintf('NaN в G_e   = %d\n', sum(isnan(Engine.G_e(:))));
fprintf('Inf в G_e   = %d\n', sum(isinf(Engine.G_e(:))));
fprintf('min/max G_e = %.4g / %.4g\n', min(Engine.G_e(:)), max(Engine.G_e(:)));
fprintf('все G_e == const? %d\n', range(Engine.G_e(:)) == 0);