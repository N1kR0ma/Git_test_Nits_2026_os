% % % % % % % % % NIRS_2026_Autmn
% % % % % % % % % hdejfklghdkls
close all
clear all
clear command window
%% Настройка путей
way = fileparts(which(mfilename));
way2func = fullfile(way, "Function_folder");
way2data = fullfile(way, "Data");
way2engine = fullfile(way, "Engine_parametr");
addpath(way2func);

clear way2func 

% % % Function setting of graph
setupPlotDefaults();

%% Input Data
graphic_cr = false;
%% Standart constrant
Const.g = 9.80665;
Const.rho = 1.225;
Const.rad = pi/180;
Const.rpm = pi / 30;

%% Road parametr

Road.f_r = 0.007;    % % %  Coefficient of rolling resistance
Road.mu = 0.8;       % % %  Tip-road friction coefficient
Road.k_f = 2.9e-4;      % % %  Coefficient of dependence of type rolling resistance on speed
Road.alpha_max = 10; % % %  Maximum road angle
Road.alpha = 0;
Road.file_name = 'Millbrook Heavy Duty_urban.txt'; % % % Name file with 

%% Vehicle parametr
Vehicle.mass_f = 32e3; % % % Full mass vehicle
Vehicle.alpha_veh = 16;      % % %  Maximum climb gradient;

% % %  Tire parametr
Vehicle.Tire_1 = 315;
Vehicle.Tire_2 = 80;
Vehicle.Tire_R = 22.5;
Vehicle.I_w =  20;      % % % Wheel moment inertia
Vehicle.Wheel = 10;     % % % Number wheel (2 tire = 2 wheel)

%%% Transmission
Vehicle.i_fd = 29/17; % % % Final drive ratio
Vehicle.i_wr = 37/13; % % % Wheel reduction gear ratio
% % % Gearbox ratio
Vehicle.i_gb = [13.8   11.54   9.49    7.93    6.53    5.46    ...   
     4.57    3.82    3.02    2.53    2.08    1.74    1.43    1.20...
    1   0.84];

%%%%%% Массив расстояний между осями
Vehicle.Axle_x = [0, 3.3, 4.7];
% % % Drive Axle
Vehicle.Drive_axle = [2,3];
Vehicle_DA_mass = [11500, 11500];
 

%%%%%% Положение центра масс 
Vehicle.CM_x = sum( Vehicle.Axle_x(Vehicle.Drive_axle) .* Vehicle_DA_mass)...
/Vehicle.mass_f;
Vehicle.CM_y = 1.8;


%%% Efficiency
Vehicle.eta_fd = 0.95; % % % Final drive efficiency
Vehicle.eta_wr = 0.97; % % % Wheel reduction gear efficiency
% % %  Average efficiency gearbox
Vehicle.eta_gb = [ ...
    0.915, 0.920, 0.920, 0.925, ... % Передачи 1-4
    0.925, 0.930, 0.935, 0.940, ... % Передачи 5-8
    0.945, 0.950, 0.950, 0.955, ... % Передачи 9-12
    0.955, 0.960, 0.975, 0.965  ... % Передачи 13-16
];

%%% Aerodinamic 
Vehicle.C_d = 0.6; % % % Aerodinamic drag coefficient
Vehicle.H = 3.65;  % % % Frontal area heigth
Vehicle.B = 2.05;  % % % Frontal area width
Vehicle.C_m = 0.8; % % % Frontal area coefficient (Midel)

%%% Engine 
Vehicle.I_e = 2; % % %  Engine moment inertia
Engine_charascteristic_curve_data = 'D_2876_LF_04_EURO_3';
Engine.Diametr = 0.128;
Engine.Pist_stroke = 0.166;
Engine.Volume = 12816e-6;
Engine.Hu = 42.5;
Engine.Number_cil = 6;
Engine.Coef_use = 0.92;

%%% Suspention
Vehicle.Omega = 1.5;

Moment_coeff = 0.2:0.05:1;   % % % % Part load moment



%% Pre-processing of variables
Way2EngineParametr = ['Engine_parametr/', ...
Engine_charascteristic_curve_data];
Omega_file = [Way2EngineParametr, '_w', '.txt'];
Torque_file = [Way2EngineParametr, '_t', '.txt'];
Fuel_file = [Way2EngineParametr, '_ge', '.txt'];

Way2RoadParametr = ['Road_parametr/']

% Reading_engine_data
Engine.W_e = readArrayFromTxt(Omega_file) * Const.rpm;   % рад/с
T_e        = readArrayFromTxt(Torque_file);               % Н·м, 1×N_w
Ge_e       = readArrayFromTxt(Fuel_file);                  % г/(кВт·ч), 1×N_w

% % % % Stable oriantation column
if isrow(T_e) 
    T_e= T_e(:);
    disp('Oriantation engine Torque vector was changed')
end

if isrow(Engine.W_e) 
    Engine.W_e = Engine.W_e(:);
    disp('Oriantation engine Omega vector was changed')
end

if isrow(Ge_e) && (size(Ge_e,1) * size(Ge_e,2) ~= 1)
    Engine.Ge_e = Engine.Ge_e(:);
    disp('Oriantation engine Ge vector was changed')
else
    if isrow(Engine.W_e) && ~isvector(Ge_e)
       Engine.Ge_e = Engine.Ge_e(:);
       disp('Oriantation engine Ge vector was changed')
    end
end


% % %  Test with Willins function
[Engine, info] = build_engine_map_func(Engine, Ge_e, T_e,...
        Moment_coeff, Const, struct('plot', graphic_cr, 'verbose', true));
    
Engine.Koeff_use = Engine.T ./ max(Engine.T,[],2);

% % % %  Test with Shlipce function
% [Engine_shlipce, info] = build_engine_map_func(Engine, min(Ge_e), T_e,...
%     Moment_coeff, Const,struct('plot', graphic_cr, 'verbose', true));
  
    % --- Контуры + 3D ---
    figure('Color','w','Position',[100 100 1400 600]);

    subplot(1,2,1);
    contourf(Engine.W_e, Engine.Koeff_use', Engine.G_e', 20, 'LineColor','none'); hold on;
    contour(Engine.W_e, Engine.Koeff_use', Engine.G_e', 'k');
    colorbar;
    xlabel('Скорость, rpm'); ylabel('Момент, N\cdotm');
    title('Изолинии g_e (вид сверху)'); grid on;

    subplot(1,2,2);
    surf(Engine.W_e, Engine.Koeff_use', Engine.G_e', 'EdgeColor','none');
    shading interp; colormap turbo; colorbar;
    xlabel('Скорость, rpm'); ylabel('Момент, N\cdotm');
    zlabel('g_e, г/(кВт\cdotч)');
    title('3D-поверхность'); grid on; view(45, 30);

%% Definition real torque matrix with efficiency coefficient
% Vehicle.Axle_x = Vehicle.Axle_x - Vehicle.CM_x;

% % % Radius
Vehicle.radius =...
    ((Vehicle.Tire_1   *   Vehicle.Tire_2/100)      +     ...
    ((25.4       *       Vehicle.Tire_R)    /   2))   /   1000;
Vehicle.efficiency = Vehicle.eta_gb * Vehicle.eta_fd * Vehicle.eta_wr;


% % % Midel area
Vehicle.Midel = Vehicle.C_m * Vehicle.H * Vehicle.B * Vehicle.C_d; 

% % % Transmission
Vehicle.Transmission = Vehicle.i_fd * Vehicle.i_wr * Vehicle.i_gb;

% % %  Wozduh sopr
Vehicle.F_sopr_air =...
   Air_resistance(Vehicle.C_d, Vehicle.Midel, Const.rho,...
   Engine.W_e * (1./Vehicle.Transmission));  

% % % Realizable momet of engine
Vehicle.Force_xeng =...
    Engine.T *Engine.Coef_use / Vehicle.radius ...
    .* reshape(Vehicle.efficiency .* Vehicle.Transmission, 1, 1, []);

% % %  Suspention shtiffness from omega
Vehicle.Susp_Cx =...
    Suspention_shtiifness_func(Vehicle.mass_f, Vehicle.Omega);

% % % Inertion coefficient
Vehicle.Delta =...
    delta_f(Vehicle.Transmission, Vehicle.efficiency,...
    Vehicle.I_e, Vehicle.Wheel , Vehicle.I_w,...
    Vehicle.radius, Vehicle.mass_f);

% % %  R_z vehicle
Vehicle.Rz = Rz_zhestkost(Vehicle.mass_f * cos(Road.alpha) * Const.g,...
    Vehicle.mass_f * sin(Road.alpha) * Const.g,...
    Vehicle.Axle_x, Vehicle.Susp_Cx, Vehicle.CM_x , Vehicle.CM_y);

% % % Tip-road friction force
Vehicle.F_xmu = sum(Vehicle.Rz(Vehicle.Drive_axle))* Road.mu;

% % %  Real rorce on torque, i_tr
Vehicle.F_x = min(Vehicle.Force_xeng, Vehicle.F_xmu);
% % %  Вычитаение сопротивления воздуха по правильным осям
Vehicle.Fx_air = Vehicle.F_x - reshape(Vehicle.F_sopr_air, ...
                                       size(Vehicle.F_sopr_air,1), 1, ...
                                       size(Vehicle.F_sopr_air,2));

if graphic_cr
% % % Surf crate
figure
hold on
for i = 1:size(Vehicle.Fx_air,3)
x = Engine.W_e;              % 53×1
y = Engine.Koeff_use(i, :);          % 1×16  (или T(:,1), если T — 16×53 по смыслу)
[X, Y] = meshgrid(y, x);     % 53×16
surf(X, Y, Vehicle.Fx_air(:,:,i));
xlabel('T'); ylabel('W_e'); zlabel('Fx');
end
view(3); grid on; hold off;
end

DVS_1_torqe = [Engine.W_e, Engine.T(:,end)];
% 
% [accel, Din_f, v] = Din_f_und_accel( ...
%         Vehicle.Transmission, ...          % u_tr
%         Vehicle.efficiency,  ...           % h_tr
%         Engine.Coef_use,     ...           % kch
%         Vehicle.Delta,       ...           % delta
%         'Геометрическое распределение', ... % Name
%         Vehicle.mass_f,      ...           % m
%         Const.g,             ...           % g
%         Vehicle.radius,      ...           % r0
%         DVS_1_torqe,         ...           % [W_e, T_e]
%         Vehicle.C_d,         ...           % c_x
%         Vehicle.Midel,       ...           % Area
%         Const.rho,           ...           % ro
%         Road.f_r,            ...           % f_speed_0
%         Road.k_f,            ...           % k_f
%         Road.alpha);                       % alpha
%% Gear shifting map create

% % Max omega
Calc.n_shift = size(Vehicle.Transmission, 2) - 1;   % X-1 переключений
Calc.n_koeff = size(Engine.Koeff_use, 2);           % число коэффициентов (16)

% --- Верхняя граница: скорости для каждой передачи, затем отбрасываем последнюю ---
Calc.speed_up_all   = max(Engine.W_e) * Vehicle.radius ...
                 ./ Vehicle.Transmission * 3.6;        % длина X
Calc.speed_up_shift = Calc.speed_up_all(1:Calc.n_shift);              % длина X-1 (без последней)

% --- Нижняя граница: скорости для каждой передачи, затем отбрасываем первую ---
Calc.speed_down_all   = min(Engine.W_e) * Vehicle.radius ...
                   ./ Vehicle.Transmission * 3.6;      % длина X
Calc.speed_down_shift = Calc.speed_down_all(2:end);              % длина X-1 (без первой)

% --- Коэффициенты использования (1 × n_koeff) ---
Calc.h_up   = max(Engine.Koeff_use, [], 1);   % максимум по оборотам для каждого коэффициента
Calc.h_down = min(Engine.Koeff_use, [], 1);   % минимум по оборотам для каждого коэффициента

% --- Размножаем до размерности (n_shift × n_koeff) ---
% h: одна и та же строка h_up/h_down повторяется n_shift раз
Map.MM_up_h   = repmat(Calc.h_up,   Calc.n_shift, 1);   % (n_shift × n_koeff)
Map.MM_down_h = repmat(Calc.h_down, Calc.n_shift, 1);   % (n_shift × n_koeff)

% speed: один и тот же столбец speed_*_shift повторяется n_koeff раз
Map.MM_up_speed   = repmat(Calc.speed_up_shift(:),   1, Calc.n_koeff);   % (n_shift × n_koeff)
Map.MM_down_speed = repmat(Calc.speed_down_shift(:), 1, Calc.n_koeff);   % (n_shift × n_koeff)
 
plot_gears_maps2(Map.MM_up_h, Map.MM_up_speed, ...
                 Map.MM_down_h, Map.MM_down_speed);
             
 

%% до циклов
clc
clear Calc_m
clear Map
 
n_i = size(Vehicle.Transmission,2)-12;
n_W = size(Engine.W_e,1);
Calc_m.Engine_coef = zeros(n_W, size(Engine.Koeff_use,2));
 

for i = 1:n_i
    for j = 1:size(Engine.Koeff_use,2) 
        Calc_m.Speed    = nan(1, n_W);
        Calc_m.Fx_air   = nan(1, n_W);
        Calc_m.G_e      = nan(1, n_W);
        Calc_m.Omega_2  = nan(1, n_W);
        Calc_m.Fx_air_2 = nan(1, n_W);
        Calc_m.G_e2     = nan(1, n_W);

        for k = 1:n_W
% % Скорость (угловая скорость на выходе трансмиссии) для текущей передачи i
Calc_m.Speed(k)  = Engine.W_e(k,1) / Vehicle.Transmission(i);

% % Коэффициент использования двигателя в точке (обороты k, момент j)
Calc_m.Engine_coef(k,j) = Engine.Koeff_use(k,j);

% % Тягловая сила (за вычетом аэродинамики) для текущей передачи i,
% % в точке (обороты k, момент j)
Calc_m.Fx_air(k) = Vehicle.Fx_air(k,j,i);

        if Engine.W_e(k,1) == Engine.W_e(end)
                Map.Ge_up_Speed(i,j) = Calc_m.Speed(k) * 3.6 * Vehicle.radius;
                Map.Ge_up_h(i,j)     = Calc_m.Engine_coef(k,j);
                continue
        end



% % Удельный расход топлива для текущих оборотов k и момента j
Calc_m.G_e(k)    = Engine.G_e(k, j);

% % Обороты двигателя, которые установятся на следующей передаче i+1
% % при той же скорости автомобиля (Speed неизменна в момент переключения)
Calc_m.Omega_2(k) = Calc_m.Speed(k) * Vehicle.Transmission(i+1);

% % Проверка: переключение не должно опустить двигатель на холостой ход
% % (Omega_2 ниже минимальных оборотов) и не должно превысить максимальные
% % обороты. Если условие не выполнено — пропускаем итерацию.
if Calc_m.Omega_2(k) <= min(Engine.W_e) || ...
   Calc_m.Omega_2(k) >= max(Engine.W_e)
      continue;
end
 
% Сила на передаче i+1 при частоте Omega_2(k) — вектор по моментам
Calc_m.Fx_air_2_pr = interp1(Engine.W_e, ...
    Vehicle.Fx_air(:,:,i+1), Calc_m.Omega_2(k), 'linear', NaN);

% Коэффициент использования при этой частоте (скаляр, момент j)
Calc_m.Engine_Use_pr = interp1(Engine.W_e, ...
    Engine.Koeff_use, Calc_m.Omega_2(k), 'linear', NaN);

% % %  Определение возможных тягловых сил для данной частоты вращения
% % %  на следующей передаче i+1 (вектор по моментам)
Calc_m.Fx_air_2_pr = interp1(Engine.W_e, ...
    Vehicle.Fx_air(:,:,i+1), Calc_m.Omega_2(k), 'linear', NaN);

% % %  Определение коэффициентов использования, обеспечивающих
% % %  движение с той же тягловой силой Fx_air(k)
Calc_m.Engine_Use = interp_find_all_linear( ...
    Calc_m.Engine_Use_pr, Calc_m.Fx_air_2_pr, Calc_m.Fx_air(k));

            if isempty(Calc_m.Engine_Use) || any(isnan(Calc_m.Engine_Use(:)))
                continue;
            end
% % %  Получения графика зависимости удельного расхода от коэф исп
            Calc_m.Ge_2_int = interp1(Engine.W_e, Engine.G_e, ...
                Calc_m.Omega_2(k), 'linear', NaN);            
            
% % %  Вычисление конкретных удельных расходов для использвоания обеспеч
% % %  возможности смены передачи
            Calc_m.Ge_2_pr = interp1(Calc_m.Engine_Use_pr,  Calc_m.Ge_2_int, ...
                Calc_m.Engine_Use, 'linear', NaN)

            if isempty(Calc_m.Ge_2_pr)
                continue;
            end

            [Calc_m.G_e2, Calc_m.index] = min(Calc_m.Ge_2_pr);
            Calc_m.Fx_air_2(k) = Calc_m.Fx_air_2_pr(Calc_m.index);

            if  Calc_m.G_e2 < Calc_m.G_e(k)
                if Calc_m.Fx_air_2(k) <Calc_m.Fx_air(k)
                disp('Переключение для экономичности');
                Map.Ge_up_Speed(i,j) = Calc_m.Speed(k) * 3.6 * Vehicle.radius;
                Map.Ge_up_h(i,j)     = Calc_m.Engine_Use(Calc_m.index);
                break;
                end
            end           
        end
    end
end
 

plot_gears_maps2(Map.Ge_up_h,Map.Ge_up_Speed, ...
                 Map.Ge_up_h , Map.Ge_up_Speed );

%% Definition reaL Road-Vehicle parametr
% % % % Speed, Accekeration
% [Road.Time, Road.Velocity, Road.Acceleration]...
%     = readRoadProfile(['Road_parametr\', Road.file_name], 1000, ...
%         struct('plot',graphic_cr, 'verbose', false));
% 
% % % %  Force sopr 
% Cycle.F_sopr_rolling =...
%     Soprotivlenie_function(...
%     Road.f_r, Road.k_f, Road.alpha,...
%     Road.Velocity, Const.g, Vehicle.mass_f );
% 
% Cycle.F_sopr_delta = Road.Acceleration * Vehicle.mass_f  





















