function [accel, Din_f, v] = ...
    Din_f_und_accel(u_tr, h_tr, kch, delta, Name, ...
                    m, g, r0, DVS_1_torqe, ...
                    c_x, Area, ro, ...
                    f_speed_0, k_f, alpha)
% Din_f_und_accel  Динамический фактор и ускорение автомобиля.
%
% Вход:
%   u_tr         - передаточные числа КПП (вектор)
%   h_tr         - КПД трансмиссии (скаляр или вектор)
%   kch          - множитель (как в исходнике)
%   delta        - коэффициент вращающихся масс
%   Name         - имя для заголовков / файлов
%   m, g, r0     - масса, ускорение свободного падения, радиус колеса
%   DVS_1_torqe  - матрица [W_e, T_e] (N×2)
%   c_x, Area,ro - параметры аэродинамики (Air_resistance)
%   f_speed_0    - коэффициент сопротивления качению при v=0
%   k_f          - коэффициент скоростной зависимости f
%   alpha        - угол наклона дороги, рад (Soprotivlenie_function)
%
% Выход:
%   accel  - ускорение (N_точек × length(u_tr))
%   Din_f  - динамический фактор
%   v      - скорость, м/с

%% Тягловая сила на колёсах
P_k = DVS_1_torqe(:,2) .* kch .* h_tr .* u_tr ./ r0;

%% Скорость автомобиля
v = DVS_1_torqe(:,1) .* r0 ./ u_tr;

%% Сила сопротивления воздуха
P_w = Air_resistance(c_x, Area, ro, v);

%% Динамический фактор
Din_f = (P_k - P_w) / (m * g);

%% Сила сопротивления качению
P_f = Soprotivlenie_function(f_speed_0, k_f, alpha, v, g, m);

%% Коэффициент сопротивления качению
f_1 = P_f / m / g;

%% Ускорение
accel = (Din_f - f_1) * g ./ delta;

%% Данные для кривой P_f
v_full = linspace(min(v, [], 'all'), max(v, [], 'all'), 500);
f_full = Soprotivlenie_function(f_speed_0, k_f, alpha, v_full, g, m) / m / g;

%% ---------- Огибающие (максимум по передачам) ----------
% Для каждой точки скорости берём максимум по всем передачам.
% Внимание: v(:,k) для разных k — разные скорости, поэтому сначала
% упорядочиваем по скорости, затем интерполируем на общую сетку.
n_gear = length(u_tr);
n_pts  = size(v, 1);

% Общая сетка скорости (для огибающей)
v_min_env = min(v, [], 'all');
v_max_env = max(v, [], 'all');
v_env     = linspace(v_min_env, v_max_env, 1000);

Din_env   = nan(size(v_env));
accel_env = nan(size(v_env));

for k = 1:n_gear
    % Убираем NaN и сортируем по скорости
    vk = v(:,k);
    Dk = Din_f(:,k);
    Ak = accel(:,k);
    good = ~isnan(vk) & ~isnan(Dk) & ~isnan(Ak);
    vk = vk(good); Dk = Dk(good); Ak = Ak(good);
    if numel(vk) < 2, continue; end
    [vk, idx] = sort(vk);
    Dk = Dk(idx); Ak = Ak(idx);

    % Интерполируем на общую сетку (только в диапазоне этой передачи)
    mask = v_env >= vk(1) & v_env <= vk(end);
    Dk_i = interp1(vk, Dk, v_env(mask), 'linear', NaN);
    Ak_i = interp1(vk, Ak, v_env(mask), 'linear', NaN);

    % Обновляем огибающую максимумом
    Din_env(mask)   = max(Din_env(mask),   Dk_i, 'omitnan');
    accel_env(mask) = max(accel_env(mask), Ak_i, 'omitnan');
end

%% ---------- График динамического фактора ----------
Name_1 = [Name, ' динамический фактор'];

figure;
title(Name_1);
hold on;
xlabel('Скорость движения автомобиля, V км/ч');
ylabel('Динамический фактор , D');
grid on;

title_str = strings(1, n_gear + 2);   % +1 P_f, +1 огибающая

for k = 1:n_gear
    plot(v(:,k)*3.6, Din_f(:,k), '-', 'color', rand(1,3));
    title_str(k) = "D_{" + string(k) + "}";
end

% Кривая сопротивления качению
plot(v_full*3.6, f_full, '--', 'color', [0.5 0.5 0.5], 'LineWidth', 2);
title_str(end-1) = 'P_f';

% Огибающая динамического фактора
plot(v_env*3.6, Din_env, '-', 'Color', 'k', 'LineWidth', 2.5);
title_str(end) = 'D_{max}';

% Легенда: в 2 столбца, если передач > 8
if n_gear > 8
    legend(title_str, 'Location', 'best', 'NumColumns', 2);
else
    legend(title_str, 'Location', 'best');
end
saveas(gcf, Name_1, 'png');

%% ---------- График ускорения ----------
Name_2 = [Name, ' ускорение автомобиля'];

figure;
title(Name_2);
hold on;
grid on;
xlabel('Скорость движения автомобиля, V(t) м/с');
ylabel('Ускорение автомобиля, а м/с^2');

title_str = strings(1, n_gear + 1);   % +1 огибающая

for k = 1:n_gear
    plot(v(:,k)*3.6, accel(:,k), '-', 'color', rand(1,3));
    title_str(k) = "a_{" + string(k) + "}";
end

% Огибающая ускорения
plot(v_env*3.6, accel_env, '-', 'Color', 'k', 'LineWidth', 2.5);
title_str(end) = 'a_{max}';

% Легенда: в 2 столбца, если передач > 8
if n_gear > 8
    legend(title_str, 'Location', 'best', 'NumColumns', 2);
else
    legend(title_str, 'Location', 'best');
end
 

saveas(gcf, Name_2, 'png');

end