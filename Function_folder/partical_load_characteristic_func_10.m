function [G_e, w_load, T_load, X_opt, calib] = partical_load_characteristic_func_10( ...
        w_load, T_load, D, B, V, b_e_fl, T_ref, H_u, z, ...
        b_e_part, T_part, w_part)
% PARTICAL_LOAD_CHARACTERISTIC_FUNC_10
%   Карта удельного расхода топлива g_e(w, T) по методике
%   Lauren et al. (2022), DOI: 10.3390/machines10010026.
%
%   ОТЛИЧИЕ ОТ _6: ДВЕ ПАРАБОЛЫ eta_i(n) — СЛЕВА И СПРАВА ОТ МИНИМУМА b_e.
%     1. Находим n_opt — точку минимума b_e_ref(n) (по данным).
%     2. Разделяем диапазон: n <= n_opt (левая), n > n_opt (правая).
%     3. Калибруем ДВЕ параболы отдельно, со сшивкой в n_opt:
%          eta_L(n) = a_L1*w^2 + a_L2*w + a_L3,  n <= n_opt
%          eta_R(n) = a_R1*w^2 + a_R2*w + a_R3,  n >  n_opt
%        с условием eta_L(n_opt) = eta_R(n_opt) (непрерывность).
%     4. k_1, k_3 — перебор 5x5 (как в _6).
%
%   Вход/выход — как в _6.
%
%   ВАЖНО: перед вызовом сделайте
%       clear functions; rehash

    % =====================================================================
    %  БЛОК 0. ВХОДНЫЕ ПРОВЕРКИ
    % =====================================================================
    G_e = []; X_opt = []; calib = struct();

    if nargin < 9  || isempty(z),        z = 1; end
    if nargin < 10, b_e_part = []; end
    if nargin < 11, T_part   = []; end
    if nargin < 12, w_part   = []; end

    w_load = w_load(:).';
    T_ref  = T_ref(:).';
    b_e_fl = b_e_fl(:).';

    if numel(T_ref) ~= numel(w_load) || numel(b_e_fl) ~= numel(w_load)
        error('partical_load_characteristic_func_10: T_ref и b_e_fl должны быть той же длины, что w_load.');
    end
    if any(b_e_fl <= 0)
        error('partical_load_characteristic_func_10: b_e_fl должен быть > 0.');
    end

    has_part = ~isempty(b_e_part) && ~isempty(T_part) && ~isempty(w_part);
    if has_part
        b_e_part = b_e_part(:).';
        T_part   = T_part(:).';
        w_part   = w_part(:).';
        if numel(b_e_part) ~= numel(T_part) || numel(T_part) ~= numel(w_part)
            error('partical_load_characteristic_func_10: b_e_part, T_part, w_part должны быть одной длины.');
        end
        if any(b_e_part <= 0)
            error('partical_load_characteristic_func_10: b_e_part должен быть > 0.');
        end
    end

    % =====================================================================
    %  ФИКСИРОВАННЫЕ ПАРАМЕТРЫ ETH-МОДЕЛИ
    % =====================================================================
    k_2_fix = 0.5;
    k_4_fix = 0.075;

    % =====================================================================
    %  РАСШИРЕННАЯ СЕТКА k_1, k_3
    % =====================================================================
    k_1_grid = [120e3, 132e3, 144e3, 152e3, 160e3];
    k_3_grid = [1.1e-3, 1.2e-3, 1.3e-3, 1.45e-3, 1.6e-3];
    k_1_ref  = 144e3;
    k_3_ref  = 1.1e-3;

    % =====================================================================
    %  ШАГ 1: НАХОДИМ n_opt — минимум b_e_ref
    % =====================================================================
    [b_e_min, idx_min] = min(b_e_fl);
    n_opt_rpm = w_load(idx_min) * 30/pi;
    omega_opt = w_load(idx_min);

    % --- Локальная парабола через 3 точки вокруг минимума (уточнение) ---
    if idx_min > 1 && idx_min < numel(b_e_fl)
        % 3 точки: idx_min-1, idx_min, idx_min+1
        x = w_load(idx_min-1:idx_min+1);
        y = b_e_fl(idx_min-1:idx_min+1);
        p = polyfit(x, y, 2);
        omega_opt_refined = -p(2) / (2*p(1));
        if omega_opt_refined > x(1) && omega_opt_refined < x(3)
            omega_opt = omega_opt_refined;
            n_opt_rpm = omega_opt * 30/pi;
            fprintf('  Уточнение вершины параболой: n_opt = %.1f rpm\n', n_opt_rpm);
        end
    end

    fprintf('\n===== ШАГ 1: ПОИСК МИНИМУМА b_e =====\n');
    fprintf('b_e_min = %.2f г/(кВт·ч) при n = %.1f rpm\n', b_e_min, n_opt_rpm);

    % --- Разделяем на левую и правую части ---
    mask_L = w_load <= omega_opt;
    mask_R = w_load >  omega_opt;
    N_L = sum(mask_L);
    N_R = sum(mask_R);

    fprintf('Левая часть (n <= %.0f rpm): %d точек\n', n_opt_rpm, N_L);
    fprintf('Правая часть (n >  %.0f rpm): %d точек\n', n_opt_rpm, N_R);

    if N_L < 3 || N_R < 3
        error('partical_load_characteristic_func_10: недостаточно точек слева/справа (N_L=%d, N_R=%d).', ...
              N_L, N_R);
    end

    % =====================================================================
    %  ШАГ 2: КАЛИБРОВКА ДВУХ ПАРАБОЛ (сшивка в n_opt)
    % =====================================================================
    % X = [a_L1, a_L2, a_L3, a_R1, a_R2]  — 5 свободных
    %   a_R3 = a_L1*w_opt^2 + a_L2*w_opt + a_L3 - a_R1*w_opt^2 - a_R2*w_opt
    %   (сшивка: eta_L(w_opt) = eta_R(w_opt))
    %
    % Начальные значения: из статьи, обе параболы одинаковы
    X0 = [-6.333e-7, 4.0333e-4, 0.3960, -6.333e-7, 4.0333e-4];
    lb = [-2e-6,    1e-4,      0.35,   -2e-6,    1e-4];
    ub = [-1e-7,    6e-4,      0.50,   -1e-7,    6e-4];

    obj_poly = @(X) sum( obj_full_two_parab(X, omega_opt, ...
                        w_load, T_ref, b_e_fl, D, B, V, H_u, ...
                        k_2_fix, k_4_fix, z, k_1_ref, k_3_ref).^2 ) / numel(w_load);

    opts_poly = optimoptions('fmincon', ...
        'Display', 'off', ...
        'Algorithm', 'interior-point', ...
        'MaxIterations', 2000, ...
        'MaxFunctionEvaluations', 10000, ...
        'StepTolerance', 1e-12, ...
        'OptimalityTolerance', 1e-12);

    n_starts_A = 10;
    rng(42);

    best_fval_A = inf;
    best_X      = X0;
    all_fval_A  = zeros(n_starts_A, 1);

    fprintf('\n===== ШАГ 2: MULTI-START (%d стартов) две параболы =====\n', n_starts_A);

    for kk = 1:n_starts_A
        if kk == 1
            X_start = X0;
        else
            X_start = lb + (ub - lb) .* rand(1, 5);
        end

        [X_try, fval_try, ef] = fmincon(obj_poly, X_start, [],[],[],[], ...
                                        lb, ub, [], opts_poly);

        all_fval_A(kk) = fval_try;

        if ef > 0 && fval_try < best_fval_A
            best_fval_A = fval_try;
            best_X      = X_try;
        end

        fprintf('  Start %2d/%2d: resnorm = %.6e (RMS %.3f %%), ef=%d\n', ...
                kk, n_starts_A, fval_try, sqrt(fval_try)*100, ef);
    end

    % --- Распаковка (a_R3 вычисляем из сшивки) ---
    a_L1 = best_X(1); a_L2 = best_X(2); a_L3 = best_X(3);
    a_R1 = best_X(4); a_R2 = best_X(5);
    a_R3 = a_L1*omega_opt^2 + a_L2*omega_opt + a_L3 - a_R1*omega_opt^2 - a_R2*omega_opt;

    eta_opt_val = a_L1*omega_opt^2 + a_L2*omega_opt + a_L3;

    fprintf('\nЛучший старт Шага 2:\n');
    fprintf('Левая:  a_L1=%.4e, a_L2=%.4e, a_L3=%.4f\n', a_L1, a_L2, a_L3);
    fprintf('Правая: a_R1=%.4e, a_R2=%.4e, a_R3=%.4f\n', a_R1, a_R2, a_R3);
    fprintf('eta_i(n_opt=%.0f rpm) = %.4f (сшивка)\n', n_opt_rpm, eta_opt_val);
    fprintf('resnorm (full-load) = %.6e, RMS = %.3f %%\n', ...
            best_fval_A, sqrt(best_fval_A)*100);

    % --- Диагностика eta_i ---
    n_rpm_grid = linspace(min(w_load), max(w_load), 200) * 30/pi;
    omega_grid = n_rpm_grid * pi/30;
    eta_grid = zeros(size(omega_grid));
    for jj = 1:numel(omega_grid)
        if omega_grid(jj) <= omega_opt
            eta_grid(jj) = a_L1*omega_grid(jj)^2 + a_L2*omega_grid(jj) + a_L3;
        else
            eta_grid(jj) = a_R1*omega_grid(jj)^2 + a_R2*omega_grid(jj) + a_R3;
        end
    end
    fprintf('eta_i ∈ [%.4f, %.4f] на n ∈ [%.0f, %.0f] rpm\n', ...
            min(eta_grid), max(eta_grid), min(n_rpm_grid), max(n_rpm_grid));

    % =====================================================================
    %  ШАГ 3: перебор k_1, k_3 (как в _6)
    % =====================================================================
    fprintf('\n===== ШАГ 3: выбор k_1, k_3 (сетка 5x5 = 25) =====\n');

    if has_part
        fprintf('Есть part-load данные (%d точек) — выбор по ним.\n', numel(b_e_part));
        best_score = inf;
        best_k = [k_1_ref, k_3_ref];
        best_label = 'AGCO';
        n1 = numel(k_1_grid);
        n3 = numel(k_3_grid);
        score_table = zeros(n1, n3);

        for i1 = 1:n1
            for i3 = 1:n3
                Ge_part = calc_Ge_two(X, omega_opt, w_part, T_part, D, B, V, H_u, ...
                                      k_2_fix, k_4_fix, z, k_1_grid(i1), k_3_grid(i3));
                r_part = (Ge_part(:) - b_e_part(:)) ./ b_e_part(:);
                r_part(~isfinite(r_part)) = 1e2;
                score = mean(r_part.^2);
                score_table(i1,i3) = score;
                if score < best_score
                    best_score = score;
                    best_k = [k_1_grid(i1), k_3_grid(i3)];
                    best_label = sprintf('k1=%g,k3=%.2e', ...
                                         k_1_grid(i1)/1000, k_3_grid(i3));
                end
            end
        end

        fprintf('Сетка k_1 (строки) x k_3 (столбцы), RMS part-load ошибка, %%:\n');
        fprintf('              ');
        for i3 = 1:n3
            fprintf('k_3=%.2e  ', k_3_grid(i3));
        end
        fprintf('\n');
        for i1 = 1:n1
            fprintf('k1=%3.0f кПа: ', k_1_grid(i1)/1000);
            for i3 = 1:n3
                fprintf('%9.2f  ', sqrt(score_table(i1,i3))*100);
            end
            fprintf('\n');
        end

        fprintf('Выбрано: k_1 = %.0f Па, k_3 = %.4e, part-load RMS = %.2f %%\n', ...
                best_k(1), best_k(2), sqrt(best_score)*100);
    else
        fprintf('Part-load данных нет — фиксируем AGCO (Table 5).\n');
        best_k = [k_1_ref, k_3_ref];
        best_label = 'AGCO';
        best_score = NaN;
    end

    % =====================================================================
    %  ИТОГ
    % =====================================================================
    X_opt = [a_L1, a_L2, a_L3, a_R1, a_R2, a_R3, best_k(1), best_k(2)];

    fprintf('\n===== ИТОГ =====\n');
    fprintf('X_opt = [a_L1, a_L2, a_L3, a_R1, a_R2, a_R3, k_1, k_3]:\n');
    disp(X_opt);
    fprintf('n_opt = %.1f rpm (минимум b_e)\n', n_opt_rpm);
    fprintf('Fixed: k_2 = %.2f, k_4 = %.3f m, z = %d, H_u = %.1f МДж/кг\n', ...
            k_2_fix, k_4_fix, z, H_u);

    w_mid = mean(w_load);
    p_m_mid = best_k(1) * (k_2_fix + best_k(2)*D^2*w_mid^2) * sqrt(k_4_fix/B);
    fprintf('p_m на средней скорости (%.1f кПа)\n', p_m_mid/1000);

    full_rms_pct = sqrt(best_fval_A) * 100;
    if has_part
        part_rms_pct = sqrt(best_score) * 100;
    else
        part_rms_pct = NaN;
    end
    fprintf('ФИНАЛ: full-load RMS = %.2f %%, part-load RMS = %.2f %%\n', ...
            full_rms_pct, part_rms_pct);

    % =====================================================================
    %  ТАБЛИЦА ОТКЛОНЕНИЙ (full-load)
    % =====================================================================
    Ge_full_calc = calc_Ge_two(X_opt, omega_opt, w_load, T_ref, D, B, V, H_u, ...
                               k_2_fix, k_4_fix, z, best_k(1), best_k(2));
    pts_full = pack_points(w_load, T_ref, b_e_fl, Ge_full_calc, 'full');

    fprintf('\n===== ОТКЛОНЕНИЯ ПО ТОЧКАМ (full-load) =====\n');
    fprintf('%8s %10s %12s %12s %10s %6s\n', ...
            'n, rpm', 'T, Н·м', 'b_e_ref', 'b_e_calc', 'error, %', 'side');
    for ii = 1:numel(pts_full.n_rpm)
        side = 'L';
        if pts_full.n_rpm(ii) * pi/30 > omega_opt, side = 'R'; end
        fprintf('%8.1f %10.1f %12.2f %12.2f %10.2f %6s\n', ...
                pts_full.n_rpm(ii), pts_full.T(ii), ...
                pts_full.b_e_ref(ii), pts_full.b_e_calc(ii), ...
                pts_full.error_pct(ii), side);
    end

    % =====================================================================
    %  ТАБЛИЦА ОТКЛОНЕНИЙ (part-load)
    % =====================================================================
    if has_part
        Ge_part_calc = calc_Ge_two(X_opt, omega_opt, w_part, T_part, D, B, V, H_u, ...
                                   k_2_fix, k_4_fix, z, best_k(1), best_k(2));
        pts_part = pack_points(w_part, T_part, b_e_part, Ge_part_calc, 'part');

        fprintf('\n===== ОТКЛОНЕНИЯ ПО ТОЧКАМ (part-load) =====\n');
        fprintf('%8s %10s %12s %12s %10s\n', ...
                'n, rpm', 'T, Н·м', 'b_e_ref', 'b_e_calc', 'error, %');
        for ii = 1:numel(pts_part.n_rpm)
            fprintf('%8.1f %10.1f %12.2f %12.2f %10.2f\n', ...
                    pts_part.n_rpm(ii), pts_part.T(ii), ...
                    pts_part.b_e_ref(ii), pts_part.b_e_calc(ii), ...
                    pts_part.error_pct(ii));
        end
    else
        pts_part = struct('n_rpm', [], 'T', [], 'b_e_ref', [], ...
                          'b_e_calc', [], 'error_pct', [], ...
                          'RMS_pct', NaN, 'max_abs_err_pct', NaN);
    end

    % =====================================================================
    %  СТРУКТУРА calib
    % =====================================================================
    calib = struct( ...
        'a_L1',          a_L1, ...
        'a_L2',          a_L2, ...
        'a_L3',          a_L3, ...
        'a_R1',          a_R1, ...
        'a_R2',          a_R2, ...
        'a_R3',          a_R3, ...
        'n_opt_rpm',     n_opt_rpm, ...
        'eta_opt',       eta_opt_val, ...
        'k_1',           best_k(1), ...
        'k_3',           best_k(2), ...
        'resnorm_full',  best_fval_A, ...
        'resnorm_part',  best_score, ...
        'k_source',      best_label, ...
        'full_rms_pct',  full_rms_pct, ...
        'part_rms_pct',  part_rms_pct, ...
        'n_starts_A',    n_starts_A, ...
        'all_fval_A',    all_fval_A, ...
        'points_full',   pts_full, ...
        'points_part',   pts_part);

    % =====================================================================
    %  ПОСТРОЕНИЕ КАРТЫ
    % =====================================================================
    N_w = numel(w_load);
    sz  = size(T_load);

    if sz(2) == N_w
        W_grid = repmat(w_load, sz(1), 1);
        T_grid = T_load;
    elseif sz(1) == N_w
        W_grid = repmat(w_load.', 1, sz(2));
        T_grid = T_load;
    else
        error('T_load size [%s] несовместим с length(w_load) = %d.', ...
              mat2str(sz), N_w);
    end

    G_e = calc_Ge_two(X_opt, omega_opt, W_grid, T_grid, D, B, V, H_u, ...
                      k_2_fix, k_4_fix, z, best_k(1), best_k(2));

    if ~isequal(size(G_e), size(T_load))
        error('G_e size [%s] ~= T_load size [%s].', ...
              mat2str(size(G_e)), mat2str(size(T_load)));
    end
end

% ======================================================================
function r = obj_full_two_parab(X, omega_opt, w, T, b_e_fl, D, B, V, H_u, k2, k4, z, k1, k3)
% OBJ_FULL_TWO_PARAB  Full-load невязки для двух парабол.
%   X = [a_L1, a_L2, a_L3, a_R1, a_R2]  (a_R3 вычисляется из сшивки)
    a_L1 = X(1); a_L2 = X(2); a_L3 = X(3);
    a_R1 = X(4); a_R2 = X(5);
    a_R3 = a_L1*omega_opt^2 + a_L2*omega_opt + a_L3 - a_R1*omega_opt^2 - a_R2*omega_opt;

    X_full = [a_L1, a_L2, a_L3, a_R1, a_R2, a_R3, k1, k3];
    Ge = calc_Ge_two(X_full, omega_opt, w, T, D, B, V, H_u, k2, k4, z, k1, k3);
    r = (Ge(:).' - b_e_fl(:).') ./ b_e_fl(:).';
    bad = ~isfinite(r);
    if any(bad)
        r(bad) = 1e2 * (1 + 0.1*randn(1, sum(bad)));
    end
end

% ======================================================================
function Ge_calc = calc_Ge_two(X_full, omega_opt, w, T, D, B, V, H_u, k_2, k_4, z, k1, k3)
% CALC_GE_TWO  Удельный расход с двумя параболами eta_i.
%   X_full = [a_L1, a_L2, a_L3, a_R1, a_R2, a_R3, k_1, k_3]
    tact = 4;  s_r = tact/2;

    a_L1 = X_full(1); a_L2 = X_full(2); a_L3 = X_full(3);
    a_R1 = X_full(4); a_R2 = X_full(5); a_R3 = X_full(6);

    omega = w;

    % --- eta_i: две параболы со сшивкой в omega_opt ---
    eta = zeros(size(omega));
    mask_L = omega <= omega_opt;
    mask_R = omega >  omega_opt;
    eta(mask_L) = a_L1*omega(mask_L).^2 + a_L2*omega(mask_L) + a_L3;
    eta(mask_R) = a_R1*omega(mask_R).^2 + a_R2*omega(mask_R) + a_R3;

    P_e = T .* omega;

    p_m = k1 .* (k_2 + k3 * D^2 .* omega.^2) .* sqrt(k_4 / B);

    V_total_m3 = V * 1e-3 * z;
    P_m2 = p_m .* V_total_m3 .* (omega / (2*pi)) / s_r;

    P_i = P_e + P_m2;
    P_f = P_i ./ eta;

    P_e_safe = abs(P_e);
    P_e_safe(P_e_safe < 1) = NaN;

    Ge_calc = (P_f ./ P_e_safe) .* (3.6e3 / H_u);

    bad = (eta <= 0) | ~isfinite(eta) | ~isfinite(Ge_calc) | (Ge_calc <= 0);
    Ge_calc(bad) = NaN;
end

% ======================================================================
function pts = pack_points(w_rad, T, b_e_ref, b_e_calc, tag)
    w_rad    = w_rad(:);
    T        = T(:);
    b_e_ref  = b_e_ref(:);
    b_e_calc = b_e_calc(:);

    n_rpm = w_rad * 30/pi;
    err = (b_e_calc - b_e_ref) ./ b_e_ref * 100;
    err(~isfinite(err)) = NaN;

    if any(~isnan(err))
        RMS_pct         = sqrt(mean(err(~isnan(err)).^2));
        max_abs_err_pct = max(abs(err(~isnan(err))));
    else
        RMS_pct         = NaN;
        max_abs_err_pct = NaN;
    end

    pts = struct( ...
        'tag',      tag, ...
        'n_rpm',    n_rpm, ...
        'T',        T, ...
        'b_e_ref',  b_e_ref, ...
        'b_e_calc', b_e_calc, ...
        'error_pct', err, ...
        'RMS_pct',  RMS_pct, ...
        'max_abs_err_pct', max_abs_err_pct);
end