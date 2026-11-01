function [Engine, info] = build_engine_map_func(Engine, Ge_e, T_e, Moment_coeff, Const, opts)
%BUILD_ENGINE_MAP Построение карты удельного расхода g_e(ω, T) двигателя.
%
%   [Engine, info] = BUILD_ENGINE_MAP(Engine, Ge_e, T_e, Moment_coeff, Const)
%   [Engine, info] = BUILD_ENGINE_MAP(..., opts)
%
% ВХОД:
%   Engine       - структура с полями:
%                    .W_e          - диапазон скоростей, рад/с
%                    .Pist_stroke  - ход поршня S, м
%                    .Diametr      - диаметр B, м
%                    .Volume       - рабочий объём, л
%                    .Number_cil   - число цилиндров z
%                    .Hu           - теплота сгорания, МДж/кг (по умолч. 42.5)
%   Ge_e         - удельный расход:
%                    скаляр / 1×1  -> Shlipke
%                    вектор        -> Shlipke (part-load)
%                    матрица       -> используется как есть
%   T_e          - момент полной нагрузки, Н·м (вектор)
%   Moment_coeff - коэффициент приведения момента
%   Const        - структура констант, нужен Const.rpm (рад/с -> rpm)
%
%   opts (необязательно):
%     .plot       - строить графики (по умолчанию true)
%     .verbose    - печатать диагностику (по умолчанию true)
%
% ВЫХОД:
%   Engine - дополненная структура: .G_e, .T
%   info   - структура: .w_load, .X_opt, .calib, .mode
%              mode: 'shlipke_const' | 'shlipke_vector' | 'matrix'

    if nargin < 6 || isempty(opts), opts = struct(); end
    if ~isfield(opts,'plot'),    opts.plot    = true;  end
    if ~isfield(opts,'verbose'), opts.verbose = true;  end

    info = struct('w_load', [], 'X_opt', [], 'calib', struct(), 'mode', '');
    verbose = opts.verbose;
    do_plot = opts.plot;

    nGe = numel(Ge_e);

if size(Moment_coeff,1)*size(Moment_coeff,2) == 1
   error('function build_engine_map_func works only with vector moment coefficient') 
end
    
    % =====================================================================
    % СЛУЧАЙ 1: Ge_e — скаляр (только одно значение)
    % =====================================================================
    if isscalar(Ge_e)
        if verbose
            disp('Not enjoy data for use Willins model, use Shlipke model');
        end

        Engine.G_e = Shlipce_part_load_characteristic( ...
            Ge_e, Moment_coeff, Engine.W_e);

        Engine.T = T_e(:) * Moment_coeff;   % заглушка
        info.w_load = Engine.W_e;
        info.X_opt  = [];
        info.mode   = 'shlipke_const';

        if verbose
            print_diagnostics(Engine, T_e);
        end

        if do_plot
            plot_scalar_case(Engine, Const);
        end
        return;
    end

    % =====================================================================
    % СЛУЧАЙ 2: Ge_e — вектор (1×N или N×1)
    % =====================================================================
    if isvector(Ge_e)
        if verbose
            disp('Not enjoy data for use Willins model, use Shlipke model');
        end

        T_partical_load = T_e(:) * Moment_coeff;

        [Engine.G_e, w_load, Engine.T, X_opt, calib] = ...
            partical_load_characteristic_func_10( ...
                Engine.W_e, ...
                T_partical_load, ...
                Engine.Pist_stroke, ...
                Engine.Diametr, ...
                Engine.Volume / Engine.Number_cil * 1e3, ...
                Ge_e, ...
                T_e, ...
                Engine.Hu, ...
                Engine.Number_cil);

        info.w_load = w_load;
        info.X_opt  = X_opt;
        info.calib  = calib;
        info.mode   = 'shlipke_vector';

        if verbose
            fprintf('\nИсточник k_1, k_3: %s\n', calib.k_source);
            fprintf('RMS full-load = %.2f %%, n_opt = %.0f rpm, eta_opt = %.4f\n', ...
                calib.full_rms_pct, calib.n_opt_rpm, calib.eta_opt);
        end

        if do_plot
            plot_vector_case(Engine, w_load, Const, calib);
        end
        return;
    end

    % =====================================================================
    % СЛУЧАЙ 3: Ge_e — матрица (2D-карта) — используем как есть
    % =====================================================================
    if verbose
        fprintf('b_e — матрица %s: используем как есть.\n', mat2str(size(Ge_e)));
    end
    Engine.G_e = Ge_e;
    Engine.T   = T_e;
    info.w_load = Engine.W_e;
    info.X_opt  = [];
    info.calib  = struct();
    info.mode   = 'matrix';
end


% =========================================================================
% Вспомогательные функции
% =========================================================================

function print_diagnostics(Engine, T_e)
    fprintf('size(G_e)   = %s\n', mat2str(size(Engine.G_e)));
    fprintf('size(T)     = %s\n', mat2str(size(Engine.T)));
    fprintf('numel(Omega)= %d\n', numel(Engine.W_e));
    fprintf('numel(Torque)G_e = %d\n', sum(isnan(Engine.G_e(:))));
    fprintf('Inf в G_e   = %d\n', sum(isinf(Engine.G_e(:))));
    fprintf('min/max G_e = %.4g / %.4g\n', min(Engine.G_e(:)), max(Engine.G_e(:)));
    fprintf('все G_e == const? %d\n', range(Engine.G_e(:)) == 0);
    if nargin > 1
        fprintf('numel(T_e)  = %d\n', numel(T_e));
    end
end


function plot_scalar_case(Engine, Const)
    figure('Color','w','Position',[100 100 1400 600]);

    X_axis = Engine.W_e(:)' * Const.rpm;                        % 1×N
    Y_axis = linspace(min(Engine.T(:)), max(Engine.T(:)), 16);  % 16×1
    Z      = Engine.G_e.';                                      % 16×N

    subplot(1,2,1);
    contourf(X_axis, Y_axis, Z, 20, 'LineColor','none'); hold on;
    contour(X_axis, Y_axis, Z, 10, 'k');
    colorbar;
    xlabel('Частота вращения, rpm'); ylabel('Момент, Н\cdotм');
    title('Изолинии g_e (вид сверху)'); grid on;

    subplot(1,2,2);
    surf(X_axis, Y_axis, Z, 'EdgeColor','none');
    shading interp; colormap turbo; colorbar;
    xlabel('Частота вращения, rpm'); ylabel('Момент, Н\cdotм');
    zlabel('g_e, г/(кВт\cdotч)');
    title('3D-поверхность g_e(\omega, T)'); grid on; view(45, 30);
end


function plot_vector_case(Engine, w_load, Const, calib)
    G_e = Engine.G_e;
    T   = Engine.T;
    W_e = w_load / Const.rpm;   % рад/с -> rpm

    N_w = numel(W_e);

    % Согласуем W с ориентацией T
    if size(T,2) == N_w
        W = repmat(W_e(:).', size(T,1), 1);   % столбцы = скорости
    elseif size(T,1) == N_w
        W = repmat(W_e(:),   1, size(T,2));   % строки = скорости
    else
        error('Размерность T (%s) не согласована с длиной w_load (%d).', ...
              mat2str(size(T)), N_w);
    end

    % --- 3D-поверхность по исходным точкам ---
    figure('Color','w','Position',[100 100 1000 750]);
    surf(W, T, G_e);
    colormap turbo; colorbar;
    xlabel('Скорость, rpm'); ylabel('Момент, Н\cdotм');
    zlabel('g_e, г/(кВт\cdotч)');
    title('g_e(w, T) — по исходным точкам');
    grid on; view(45, 30); rotate3d on;

    % --- Сравнение full-load с паспортом ---
    if isfield(calib, 'points_full') && ~isempty(calib.points_full.n_rpm)
        pf = calib.points_full;
        figure('Color','w','Position',[100 100 900 500]);
        plot(pf.n_rpm, pf.b_e_ref,  'ko-',  'LineWidth', 2, 'MarkerSize', 8); hold on;
        plot(pf.n_rpm, pf.b_e_calc, 'rs--', 'LineWidth', 2, 'MarkerSize', 8);
        grid on;
        xlabel('Скорость, rpm'); ylabel('b_e, г/(кВт·ч)');
        legend('Паспорт (ВСХ)', 'Модель', 'Location', 'best');
        title(sprintf('Full-load: RMS = %.2f %%, max|err| = %.2f %%', ...
              calib.full_rms_pct, pf.max_abs_err_pct));

        figure('Color','w','Position',[100 100 900 400]);
        bar(pf.n_rpm, pf.error_pct, 'FaceColor', [0.3 0.6 0.9]);
        hold on; yline(0, 'k-'); yline(2, 'r--', '+2%'); yline(-2, 'r--', '-2 %');
        grid on;
        xlabel('Скорость, rpm'); ylabel('Отклонение, %');
        title(sprintf('Full-load: отклонение модели от паспорта (RMS = %.2f %%)', ...
              calib.full_rms_pct));
    end

    % --- Контуры + 3D ---
    figure('Color','w','Position',[100 100 1400 600]);

    subplot(1,2,1);
    contourf(W, T, G_e, 20, 'LineColor','none'); hold on;
    contour(W, T, G_e, 10, 'k');
    colorbar;
    xlabel('Скорость, rpm'); ylabel('Момент, N\cdotm');
    title('Изолинии g_e (вид сверху)'); grid on;

    subplot(1,2,2);
    surf(W, T, G_e, 'EdgeColor','none');
    shading interp; colormap turbo; colorbar;
    xlabel('Скорость, rpm'); ylabel('Момент, N\cdotm');
    zlabel('g_e, г/(кВт\cdotч)');
    title('3D-поверхность'); grid on; view(45, 30);
end