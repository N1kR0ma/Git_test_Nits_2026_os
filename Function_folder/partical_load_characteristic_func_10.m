function [G_e, w_load, T_load, X_opt, calib] = partical_load_characteristic_func_10( ...
        w_load, T_load, D, B, V, b_e_fl, T_ref, H_u, z, ...
        b_e_part, T_part, w_part, L_opt, delta_bump, depth_target)
% PARTICAL_LOAD_CHARACTERISTIC_FUNC_12
%   Карта удельного расхода топлива g_e(w, T) по методике Lauren et al. (2022)
%   с локальной параболической поправкой и ЯВНЫМ заданием глубины островка.
%
%   Новые входы:
%     L_opt        — ориентировочное положение минимума b_e по нагрузке
%                    (доля от полной, 0..1; например 0.9). По умолчанию 0.9.
%     delta_bump   — сдвиг вершины поправки влево от L_opt (по умолчанию 0.1).
%     depth_target — ЖЕЛАЕМАЯ относительная глубина островка (0..0.25).
%                    b_e(L_opt) = (1 - depth_target) * b_e(1) при omega_opt.
%                    По умолчанию 0.05 (5 %). При 0 — без поправки.
%
%   Поправка: eta_eff(L) = eta_base(w) * (1 + a*phi(L)),
%   phi(L) — кусочно-параболическая "шляпа" с максимумом 1 в L_c=L_opt-delta,
%   равная 0 при L=0 и L=1.

    % =====================================================================
    %  БЛОК 0. ВХОДНЫЕ ПРОВЕРКИ
    % =====================================================================
    G_e = []; X_opt = []; calib = struct();

    if nargin < 9  || isempty(z),            z = 1; end
    if nargin < 10, b_e_part = []; end
    if nargin < 11, T_part   = []; end
    if nargin < 12, w_part   = []; end
    if nargin < 13 || isempty(L_opt),        L_opt = 0.9; end
    if nargin < 14 || isempty(delta_bump),   delta_bump = 0.1; end
    if nargin < 15 || isempty(depth_target), depth_target = 0.07; end

    L_opt        = min(max(L_opt, 0.05), 0.99);
    delta_bump   = min(max(delta_bump, 0.01), L_opt - 0.01);
    depth_target = min(max(depth_target, 0.0), 0.25);

    w_load = w_load(:).';
    T_ref  = T_ref(:).';
    b_e_fl = b_e_fl(:).';

    if numel(T_ref) ~= numel(w_load) || numel(b_e_fl) ~= numel(w_load)
        error('T_ref и b_e_fl должны быть той же длины, что w_load.');
    end
    if any(b_e_fl <= 0)
        error('b_e_fl должен быть > 0.');
    end

    has_part = ~isempty(b_e_part) && ~isempty(T_part) && ~isempty(w_part);
    if has_part
        b_e_part = b_e_part(:).';
        T_part   = T_part(:).';
        w_part   = w_part(:).';
        if numel(b_e_part) ~= numel(T_part) || numel(T_part) ~= numel(w_part)
            error('b_e_part, T_part, w_part должны быть одной длины.');
        end
        if any(b_e_part <= 0)
            error('b_e_part должен быть > 0.');
        end
    end

    % =====================================================================
    %  ФИКСИРОВАННЫЕ ПАРАМЕТРЫ ETH-МОДЕЛИ
    % =====================================================================
    k_2_fix = 0.5;
    k_4_fix = 0.075;

    % =====================================================================
    %  СЕТКА k_1, k_3
    % =====================================================================
    k_1_grid = [120e3, 132e3, 144e3, 152e3, 160e3];
    k_3_grid = [1.1e-3, 1.2e-3, 1.3e-3, 1.45e-3, 1.6e-3];
    k_1_ref  = 144e3;
    k_3_ref  = 1.1e-3;

    % =====================================================================
    %  ПАРАМЕТРЫ ПОПРАВКИ
    % =====================================================================
    L_c     = max(0.02, L_opt - delta_bump);
    s_left  = L_c;
    s_right = 1 - L_c;
    phi_opt = bump_phi(L_opt, L_c, s_left, s_right);

    fprintf('\n===== ПОПРАВКА НА ОСТРОВОК =====\n');
    fprintf('L_opt = %.3f, delta = %.3f, L_c = %.3f, s_left = %.3f, s_right = %.3f\n', ...
            L_opt, delta_bump, L_c, s_left, s_right);
    fprintf('phi(L_opt) = %.4f, depth_target = %.1f %%\n', ...
            phi_opt, depth_target * 100);
    if phi_opt < 1e-3
        warning('phi(L_opt) близко к 0: островок не удастся сформировать при delta = %.3f. Уменьшите delta_bump.', delta_bump);
    end

    % =====================================================================
    %  ШАГ 1: ОПОРНЫЕ ЧАСТОТЫ И КРАЕВЫЕ ТОЧКИ
    % =====================================================================
    omega_min = min(w_load);
    omega_max = max(w_load);

    [~, idx_min] = min(b_e_fl);
    omega_opt = w_load(idx_min);

    if idx_min > 1 && idx_min < numel(b_e_fl)
        x = w_load(idx_min-1:idx_min+1);
        y = b_e_fl(idx_min-1:idx_min+1);
        p = polyfit(x, y, 2);
        w_ref = -p(2) / (2*p(1));
        if w_ref > x(1) && w_ref < x(3)
            omega_opt = w_ref;
        end
    end
    n_opt_rpm = omega_opt * 30/pi;

    [~, i_min] = min(abs(w_load - omega_min));
    [~, i_max] = min(abs(w_load - omega_max));
    T_edge_min = T_ref(i_min);
    T_edge_max = T_ref(i_max);
    b_e_edge_min = b_e_fl(i_min);
    b_e_edge_max = b_e_fl(i_max);

    [~, i_opt] = min(abs(w_load - omega_opt));
    T_opt = T_ref(i_opt);
    b_e_opt_ref = b_e_fl(i_opt);

    fprintf('\n===== ШАГ 1: ОПОРНЫЕ ТОЧКИ =====\n');
    fprintf('w_min = %.1f rpm (T=%.1f, b_e=%.2f)\n', ...
            omega_min*30/pi, T_edge_min, b_e_edge_min);
    fprintf('w_opt = %.1f rpm (T=%.1f, b_e=%.2f)\n', ...
            n_opt_rpm, T_opt, b_e_opt_ref);
    fprintf('w_max = %.1f rpm (T=%.1f, b_e=%.2f)\n', ...
            omega_max*30/pi, T_edge_max, b_e_edge_max);

    % =====================================================================
    %  ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: eta из b_e на полной нагрузке
    % =====================================================================
    eta_from_be = @(omega, Tq, b_e, k1, k3) ...
        compute_eta_from_be(omega, Tq, b_e, D, B, V, H_u, k_2_fix, k_4_fix, z, k1, k3);

    % =====================================================================
    %  ШАГ 2: СОВМЕСТНЫЙ ПЕРЕБОР (k_1, k_3) И eta_opt
    % =====================================================================
    fprintf('\n===== ШАГ 2: перебор (k_1, k_3) x eta_opt =====\n');

    eta_opt_grid = [0.38, 0.40, 0.42, 0.44, 0.46, 0.48];
    n1 = numel(k_1_grid);
    n3 = numel(k_3_grid);
    nO = numel(eta_opt_grid);

    best_fval    = inf;
    best_k       = [k_1_ref, k_3_ref];
    best_etaL    = NaN;
    best_etaR    = NaN;
    best_etaO    = NaN;
    best_a       = [NaN, NaN, NaN];
    best_a_bump  = 0;
    score_table  = inf(n1, n3);

    for i1 = 1:n1
        for i3 = 1:n3
            k1 = k_1_grid(i1);
            k3 = k_3_grid(i3);

            eta_L = eta_from_be(omega_min, T_edge_min, b_e_edge_min, k1, k3);
            eta_R = eta_from_be(omega_max, T_edge_max, b_e_edge_max, k1, k3);

            if ~isfinite(eta_L) || ~isfinite(eta_R) || eta_L <= 0 || eta_R <= 0
                continue;
            end

            % --- амплитуда поправки для этой пары (k1,k3) ---
            p_m_opt = k1 * (k_2_fix + k3 * D^2 * omega_opt^2) * sqrt(k_4_fix / B);
            P_m_opt = p_m_opt * (V * 1e-3 * z) * (omega_opt / (2*pi)) / (4/2);
            P_e_max_opt = T_opt * omega_opt;
            K_opt = P_m_opt / P_e_max_opt;
            a_bump = compute_bump_amplitude_depth(K_opt, L_opt, L_c, ...
                                                  s_left, s_right, depth_target);

            for iO = 1:nO
                eta_opt = eta_opt_grid(iO);

                w_nodes   = [omega_min, omega_opt, omega_max];
                eta_nodes = [eta_L,     eta_opt,   eta_R];
                a = polyfit(w_nodes, eta_nodes, 2);

                % full-load: L=1, phi(1)=0 — поправка не влияет
                r = obj_full_one_parab(a, w_load, T_ref, b_e_fl, D, B, V, H_u, ...
                                       k_2_fix, k_4_fix, z, k1, k3);
                fval = mean(r.^2);

                if fval < score_table(i1, i3)
                    score_table(i1, i3) = fval;
                end

                if fval < best_fval
                    best_fval   = fval;
                    best_k      = [k1, k3];
                    best_etaL   = eta_L;
                    best_etaR   = eta_R;
                    best_etaO   = eta_opt;
                    best_a      = a;
                    best_a_bump = a_bump;
                end
            end
        end
    end

    a1 = best_a(1); a2 = best_a(2); a3 = best_a(3);

    fprintf('\nЛучшая комбинация по full-load:\n');
    fprintf('k_1 = %.0f Па, k_3 = %.4e, a_bump = %.4f\n', ...
            best_k(1), best_k(2), best_a_bump);
    fprintf('eta_L = %.4f, eta_opt = %.4f, eta_R = %.4f\n', ...
            best_etaL, best_etaO, best_etaR);
    fprintf('resnorm (full-load) = %.6e, RMS = %.3f %%\n', ...
            best_fval, sqrt(best_fval)*100);

    fprintf('\nСетка k_1 (строки) x k_3 (столбцы), full-load RMS, %%:\n');
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

    w_check = [omega_min, omega_opt, omega_max];
    eta_chk = a1*w_check.^2 + a2*w_check + a3;
    fprintf('Проверка узлов: eta(w_min)=%.4f, eta(w_opt)=%.4f, eta(w_max)=%.4f\n', ...
            eta_chk(1), eta_chk(2), eta_chk(3));

    % =====================================================================
    %  ШАГ 3: уточнение k_1, k_3 по part-load (если есть)
    % =====================================================================
    fprintf('\n===== ШАГ 3: уточнение k_1, k_3 по part-load =====\n');

    if has_part
        best_score_part = inf;
        best_k_part     = best_k;
        best_a_bump_part = best_a_bump;
        best_label = sprintf('k1=%g,k3=%.2e', best_k(1)/1000, best_k(2));
        score_part_table = zeros(n1, n3);

        for i1 = 1:n1
            for i3 = 1:n3
                k1 = k_1_grid(i1);
                k3 = k_3_grid(i3);

                eta_L = eta_from_be(omega_min, T_edge_min, b_e_edge_min, k1, k3);
                eta_R = eta_from_be(omega_max, T_edge_max, b_e_edge_max, k1, k3);
                if ~isfinite(eta_L) || ~isfinite(eta_R) || eta_L <= 0 || eta_R <= 0
                    score_part_table(i1,i3) = inf;
                    continue;
                end

                p_m_opt = k1 * (k_2_fix + k3 * D^2 * omega_opt^2) * sqrt(k_4_fix / B);
                P_m_opt = p_m_opt * (V * 1e-3 * z) * (omega_opt / (2*pi)) / (4/2);
                P_e_max_opt = T_opt * omega_opt;
                K_opt = P_m_opt / P_e_max_opt;
                a_bump = compute_bump_amplitude_depth(K_opt, L_opt, L_c, ...
                                                      s_left, s_right, depth_target);

                [~, iO_best] = min(arrayfun(@(iO) local_full_rms( ...
                    eta_opt_grid(iO), eta_L, eta_R, omega_min, omega_opt, omega_max, ...
                    w_load, T_ref, b_e_fl, D, B, V, H_u, k_2_fix, k_4_fix, z, k1, k3), ...
                    1:nO));
                eta_opt = eta_opt_grid(iO_best);

                a = polyfit([omega_min, omega_opt, omega_max], ...
                            [eta_L, eta_opt, eta_R], 2);

                Ge_part = calc_Ge_one(a, w_part, T_part, D, B, V, H_u, ...
                                      k_2_fix, k_4_fix, z, k1, k3, ...
                                      a_bump, L_c, s_left, s_right, w_load, T_ref);
                r_part = (Ge_part(:) - b_e_part(:)) ./ b_e_part(:);
                r_part(~isfinite(r_part)) = 1e2;
                score = mean(r_part.^2);
                score_part_table(i1,i3) = score;

                if score < best_score_part
                    best_score_part  = score;
                    best_k_part      = [k1, k3];
                    best_a_bump_part = a_bump;
                end
            end
        end

        fprintf('Сетка k_1 (строки) x k_3 (столбцы), part-load RMS, %%:\n');
        fprintf('              ');
        for i3 = 1:n3
            fprintf('k_3=%.2e  ', k_3_grid(i3));
        end
        fprintf('\n');
        for i1 = 1:n1
            fprintf('k1=%3.0f кПа: ', k_1_grid(i1)/1000);
            for i3 = 1:n3
                fprintf('%9.2f  ', sqrt(score_part_table(i1,i3))*100);
            end
            fprintf('\n');
        end

        fprintf('Выбрано по part-load: k_1 = %.0f Па, k_3 = %.4e, a_bump = %.4f, RMS = %.2f %%\n', ...
                best_k_part(1), best_k_part(2), best_a_bump_part, sqrt(best_score_part)*100);

        eta_L = eta_from_be(omega_min, T_edge_min, b_e_edge_min, best_k_part(1), best_k_part(2));
        eta_R = eta_from_be(omega_max, T_edge_max, b_e_edge_max, best_k_part(1), best_k_part(2));

        rms_by_etaO = arrayfun(@(iO) local_full_rms( ...
            eta_opt_grid(iO), eta_L, eta_R, omega_min, omega_opt, omega_max, ...
            w_load, T_ref, b_e_fl, D, B, V, H_u, k_2_fix, k_4_fix, z, ...
            best_k_part(1), best_k_part(2)), 1:nO);
        [best_full_rms, iO_best] = min(rms_by_etaO);
        eta_opt = eta_opt_grid(iO_best);
        a = polyfit([omega_min, omega_opt, omega_max], ...
                    [eta_L, eta_opt, eta_R], 2);
        best_fval    = best_full_rms^2;
        best_etaL    = eta_L;
        best_etaR    = eta_R;
        best_etaO    = eta_opt;
        best_a       = a;
        best_k       = best_k_part;
        best_a_bump  = best_a_bump_part;
        best_label   = sprintf('k1=%g,k3=%.2e', best_k(1)/1000, best_k(2));

        full_rms_pct = best_full_rms * 100;
        part_rms_pct = sqrt(best_score_part) * 100;
    else
        fprintf('Part-load данных нет — оставляем k_1, k_3 по full-load.\n');
        best_label   = sprintf('k1=%g,k3=%.2e', best_k(1)/1000, best_k(2));
        full_rms_pct = sqrt(best_fval) * 100;
        part_rms_pct = NaN;
    end

    a1 = best_a(1); a2 = best_a(2); a3 = best_a(3);

    % =====================================================================
    %  ИТОГ
    % =====================================================================
    X_opt = [a1, a2, a3, best_k(1), best_k(2)];

    fprintf('\n===== ИТОГ =====\n');
    fprintf('X_opt = [a1, a2, a3, k_1, k_3]:\n');
    disp(X_opt);
    fprintf('Опорные eta: eta_L=%.4f, eta_opt=%.4f (w_opt=%.1f rpm), eta_R=%.4f\n', ...
            best_etaL, best_etaO, n_opt_rpm, best_etaR);
    fprintf('Поправка: L_opt=%.3f, L_c=%.3f, a_bump=%.4f, depth_target=%.1f %%\n', ...
            L_opt, L_c, best_a_bump, depth_target*100);
    fprintf('Fixed: k_2 = %.2f, k_4 = %.3f m, z = %d, H_u = %.1f МДж/кг\n', ...
            k_2_fix, k_4_fix, z, H_u);
    fprintf('ФИНАЛ: full-load RMS = %.2f %%, part-load RMS = %.2f %%\n', ...
            full_rms_pct, part_rms_pct);

    % =====================================================================
    %  ПРОВЕРКА: положение и глубина минимума b_e при omega_opt
    % =====================================================================
    fprintf('\n===== ПРОВЕРКА ОСТРОВКА (при omega_opt) =====\n');
    L_scan = linspace(0.05, 1.0, 60);
    T_scan = L_scan * T_opt;
    W_scan = omega_opt * ones(size(T_scan));
    Ge_scan = calc_Ge_one([a1, a2, a3], W_scan, T_scan, D, B, V, H_u, ...
                          k_2_fix, k_4_fix, z, best_k(1), best_k(2), ...
                          best_a_bump, L_c, s_left, s_right, w_load, T_ref);
    [Ge_min, iL] = min(Ge_scan);
    L_star = L_scan(iL);
    Ge_at_1 = Ge_scan(end);
    depth_achieved = (Ge_at_1 - Ge_min) / Ge_at_1;

    fprintf('L* = %.3f (цель L_opt = %.3f)\n', L_star, L_opt);
    fprintf('b_e_min = %.2f г/кВт·ч при L = %.3f\n', Ge_min, L_star);
    fprintf('b_e(1.0) = %.2f г/кВт·ч\n', Ge_at_1);
    fprintf('Глубина (достигнутая) = %.2f %% (цель = %.2f %%)\n', ...
            depth_achieved*100, depth_target*100);
    fprintf('b_e(L=0.5)=%.2f, b_e(L=0.7)=%.2f, b_e(L=0.9)=%.2f, b_e(L=1.0)=%.2f\n', ...
            interp1(L_scan, Ge_scan, 0.5), ...
            interp1(L_scan, Ge_scan, 0.7), ...
            interp1(L_scan, Ge_scan, 0.9), ...
            Ge_at_1);

    % =====================================================================
    %  ТАБЛИЦА ОТКЛОНЕНИЙ (full-load)
    % =====================================================================
    Ge_full_calc = calc_Ge_one([a1, a2, a3], w_load, T_ref, D, B, V, H_u, ...
                               k_2_fix, k_4_fix, z, best_k(1), best_k(2), ...
                               best_a_bump, L_c, s_left, s_right, w_load, T_ref);
    pts_full = pack_points(w_load, T_ref, b_e_fl, Ge_full_calc, 'full');

    fprintf('\n===== ОТКЛОНЕНИЯ ПО ТОЧКАМ (full-load) =====\n');
    fprintf('%8s %10s %12s %12s %10s\n', ...
            'n, rpm', 'T, Н·м', 'b_e_ref', 'b_e_calc', 'error, %');
    for ii = 1:numel(pts_full.n_rpm)
        fprintf('%8.1f %10.1f %12.2f %12.2f %10.2f\n', ...
                pts_full.n_rpm(ii), pts_full.T(ii), ...
                pts_full.b_e_ref(ii), pts_full.b_e_calc(ii), ...
                pts_full.error_pct(ii));
    end

    % =====================================================================
    %  ТАБЛИЦА ОТКЛОНЕНИЙ (part-load)
    % =====================================================================
    if has_part
        Ge_part_calc = calc_Ge_one([a1, a2, a3], w_part, T_part, D, B, V, H_u, ...
                                   k_2_fix, k_4_fix, z, best_k(1), best_k(2), ...
                                   best_a_bump, L_c, s_left, s_right, w_load, T_ref);
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
        'a1',             a1, ...
        'a2',             a2, ...
        'a3',             a3, ...
        'eta_L',          best_etaL, ...
        'eta_opt',        best_etaO, ...
        'eta_R',          best_etaR, ...
        'omega_min',      omega_min, ...
        'omega_opt',      omega_opt, ...
        'omega_max',      omega_max, ...
        'n_opt_rpm',      n_opt_rpm, ...
        'k_1',            best_k(1), ...
        'k_3',            best_k(2), ...
        'resnorm_full',   best_fval, ...
        'k_source',       best_label, ...
        'full_rms_pct',   full_rms_pct, ...
        'part_rms_pct',   part_rms_pct, ...
        'points_full',    pts_full, ...
        'points_part',    pts_part, ...
        'L_opt',          L_opt, ...
        'L_c',            L_c, ...
        's_left',         s_left, ...
        's_right',        s_right, ...
        'a_bump',         best_a_bump, ...
        'delta_bump',     delta_bump, ...
        'depth_target',   depth_target, ...
        'L_star',         L_star, ...
        'depth_achieved', depth_achieved, ...
        'Ge_min',         Ge_min);

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

    G_e = calc_Ge_one([a1, a2, a3], W_grid, T_grid, D, B, V, H_u, ...
                      k_2_fix, k_4_fix, z, best_k(1), best_k(2), ...
                      best_a_bump, L_c, s_left, s_right, w_load, T_ref);

    if ~isequal(size(G_e), size(T_load))
        error('G_e size [%s] ~= T_load size [%s].', ...
              mat2str(size(G_e)), mat2str(size(T_load)));
    end
end

% ======================================================================
function phi = bump_phi(L, L_c, s_left, s_right)
% BUMP_PHI  Кусочно-параболическая "шляпа": 1 в L_c, 0 при L=0 и L=1.
    L = min(max(L, 0), 1);
    phi = zeros(size(L));
    mask_l = L <= L_c;
    mask_r = L >  L_c;
    if any(mask_l(:))
        phi(mask_l) = 1 - ((L(mask_l) - L_c)/s_left).^2;
    end
    if any(mask_r(:))
        phi(mask_r) = 1 - ((L(mask_r) - L_c)/s_right).^2;
    end
    phi = max(phi, 0);
end

% ======================================================================
function a = compute_bump_amplitude_depth(K, L_opt, L_c, s_left, s_right, depth_target)
% COMPUTE_BUMP_AMPLITUDE_DEPTH
%   Амплитуда a из условия b_e(L_opt) = (1 - depth_target) * b_e(L=1)
%   при фиксированной omega_opt, где K = P_m/P_e,max.
    if depth_target <= 0
        a = 0; return;
    end
    phi_opt = bump_phi(L_opt, L_c, s_left, s_right);
    if phi_opt <= 1e-6
        a = 0; return;
    end
    ratio = (1 + K/L_opt) / ((1 + K) * (1 - depth_target));
    a = (ratio - 1) / phi_opt;
    if ~isfinite(a) || a <= 0
        a = 0;
    end
    a = min(max(a, 0), 0.8);
end

% ======================================================================
function eta = compute_eta_from_be(omega, Tq, b_e, D, B, V, H_u, k_2, k_4, z, k1, k3)
% COMPUTE_ETA_FROM_BE  eta из b_e на полной нагрузке (L=1, phi=0).
    tact = 4;  s_r = tact/2;
    P_e  = Tq * omega;
    if abs(P_e) < 1
        eta = NaN; return;
    end
    p_m = k1 * (k_2 + k3*D^2*omega^2) * sqrt(k_4/B);
    V_total_m3 = V * 1e-3 * z;
    P_m2 = p_m * V_total_m3 * (omega/(2*pi)) / s_r;
    eta = (P_e + P_m2) / (P_e * b_e * H_u/3.6e3);
end

% ======================================================================
function rms = local_full_rms(eta_opt, eta_L, eta_R, w_min, w_opt, w_max, ...
                              w, T, b_e_fl, D, B, V, H_u, k2, k4, z, k1, k3)
% LOCAL_FULL_RMS  full-load RMS (L=1, поправка не влияет).
    a = polyfit([w_min, w_opt, w_max], [eta_L, eta_opt, eta_R], 2);
    r = obj_full_one_parab(a, w, T, b_e_fl, D, B, V, H_u, k2, k4, z, k1, k3);
    rms = sqrt(mean(r.^2));
end

% ======================================================================
function r = obj_full_one_parab(a, w, T, b_e_fl, D, B, V, H_u, k2, k4, z, k1, k3)
% OBJ_FULL_ONE_PARAB  Full-load невязки (поправка не влияет при L=1).
    Ge = calc_Ge_one(a, w, T, D, B, V, H_u, k2, k4, z, k1, k3, ...
                     0, 0.5, 0.5, 0.5, [], []);
    r = (Ge(:).' - b_e_fl(:).') ./ b_e_fl(:).';
    bad = ~isfinite(r);
    if any(bad)
        r(bad) = 1e2 * (1 + 0.1*randn(1, sum(bad)));
    end
end

% ======================================================================
function Ge_calc = calc_Ge_one(X, w, T, D, B, V, H_u, k_2, k_4, z, k1, k3, ...
                               a_bump, L_c, s_left, s_right, w_load, T_ref)
% CALC_GE_ONE  Удельный расход с учётом локальной поправки на островок.
    tact = 4;  s_r = tact/2;

    a1 = X(1); a2 = X(2); a3 = X(3);

    omega = w;
    eta_base = a1*omega.^2 + a2*omega + a3;

    % --- относительная нагрузка L = T/T_max(omega) ---
    if nargin >= 16 && ~isempty(w_load) && ~isempty(T_ref) && a_bump > 0
        T_max = reshape(interp1(w_load, T_ref, omega(:), 'linear', 'extrap'), size(omega));
        L = T ./ T_max;
        L = min(max(L, 0), 1);
        phi = bump_phi(L, L_c, s_left, s_right);
        eta_eff = eta_base .* (1 + a_bump * phi);
    else
        eta_eff = eta_base;
    end

    P_e = T .* omega;

    p_m = k1 .* (k_2 + k3 * D^2 .* omega.^2) .* sqrt(k_4 / B);

    V_total_m3 = V * 1e-3 * z;
    P_m2 = p_m .* V_total_m3 .* (omega / (2*pi)) / s_r;

    P_i = P_e + P_m2;
    P_f = P_i ./ eta_eff;

    P_e_safe = abs(P_e);
    P_e_safe(P_e_safe < 1) = NaN;

    Ge_calc = (P_f ./ P_e_safe) .* (3.6e3 / H_u);

    bad = (eta_eff <= 0) | ~isfinite(eta_eff) | ~isfinite(Ge_calc) | (Ge_calc <= 0);
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