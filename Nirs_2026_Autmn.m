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
Vehicle.mass_f = 32000; % % % Full mass vehicle
Vehicle.alpha_veh = 10;      % % %  Maximum climb gradient;

% % %  Tire parametr
Vehicle.Tire_1 = 315;
Vehicle.Tire_2 = 80;
Vehicle.Tire_R = 22.5;
Vehicle.I_w =  15;      % % % Wheel moment inertia
Vehicle.Wheel = 10;

%%% Transmission
Vehicle.i_fd = 29/17; % % % Final drive ratio
Vehicle.i_wr = 37/13; % % % Wheel reduction gear ratio
% % % Gearbox ratio
Vehicle.i_gb = [13.8   11.54   9.49    7.93    6.53    5.46    ...   
     4.57    3.82    3.02    2.53    2.08    1.74    1.43    1.20...
    1   0.84];

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

Moment_coeff = 0.25:0.05:1;   % % % % Part load moment

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

% % %  Test with Shlipce function
[Engine_shlipce, info] = build_engine_map_func(Engine, min(Ge_e), T_e,...
    Moment_coeff, Const,struct('plot', graphic_cr, 'verbose', true));


%% Definition real torque matrix with efficiency coefficient
% % % Radius
Vehicle.radius =...
    ((Vehicle.Tire_1   *   Vehicle.Tire_2/100)      +     ...
    ((25.4       *       Vehicle.Tire_R)    /   2))   /   1000;
Vehicle.efficiency = Vehicle.eta_gb * Vehicle.eta_fd * Vehicle.eta_wr;


% % % Transmission
Vehicle.transmission = Vehicle.i_fd * Vehicle.i_wr * Vehicle.i_gb;

% % % Realizable momet of engine
Vehicle.Force =...
    Engine.T *Engine.Coef_use / Vehicle.radius ...
    .* reshape(Vehicle.efficiency .* Vehicle.transmission, 1, 1, []);


% % % Midel area
Vehicle.Midel = Vehicle.C_m * Vehicle.H * Vehicle.B * Vehicle.C_d;

% % % Inertion coefficient
Vehicle.Delta =...
    delta_f(Vehicle.transmission, Vehicle.efficiency,...
    Vehicle.I_e, Vehicle.Wheel , Vehicle.I_w,...
    Vehicle.radius, Vehicle.mass_f);

% Speed, Accekeration
[Road.Time, Road.Velocity, Road.Acceleration]...
    = readRoadProfile(['Road_parametr\', Road.file_name], 1000, ...
        struct('plot',graphic_cr, 'verbose', false));
 
%% Definition Road-Vehicle parametr

% % %  Force sopr 
Road.F_sopr_rolling =...
    Soprotivlenie_function(...
    Road.f_r, Road.k_f, Road.alpha,...
    Road.Velocity, Const.g, Vehicle.mass_f );

% % %  Wozduh sopr
Road.F_sopr_air =...
   Air_resistance(Vehicle.C_d, Vehicle.Midel, Const.rho, Road.Velocity);  

% % % 


























