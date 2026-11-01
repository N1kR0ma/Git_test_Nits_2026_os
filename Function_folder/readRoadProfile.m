function...
    [Time,...
    Velocity,...
    Acceleration...
    ] = readRoadProfile(filename, nPoints, opts)
%READROADPROFILE Чтение профиля скорости из txt и расчёт ускорения.
%
%   Road = readRoadProfile(filename)
%   Road = readRoadProfile(filename, nPoints)
%   Road = readRoadProfile(filename, nPoints, opts)
%
%   Входные аргументы:
%       filename — имя .txt-файла (может содержать путь). Первый столбец —
%                  время [с], второй — скорость [км/ч]. Файл читается
%                  функцией readArrayFromTxt.
%       nPoints  — число точек для уплотнения (по умолчанию 1000).
%       opts     — структура опций:
%                    .plot    — строить ли график (по умолчанию false)
%                    .verbose — выводить ли info-сообщения (по умолчанию false)
%
%   Выход:
%       Road — структура с полями:
%           .Time         — равномерный вектор времени [с]
%           .Velocity     — скорость [м/с]
%           .Acceleration — ускорение [м/с^2]
%
%   Примеры:
%       Road = readRoadProfile('cycle.txt');
%       Road = readRoadProfile('cycle.txt', 2000);
%       Road = readRoadProfile('cycle.txt', 1000, ...
%                              struct('plot', true, 'verbose', true));

    arguments
        filename (1,:) char {mustBeFile}
        nPoints  (1,1) double {mustBePositive, mustBeInteger} = 1000
        opts     (1,1) struct = struct()
    end

    % --- Значения по умолчанию для опций ---
    if ~isfield(opts, 'plot'),    opts.plot    = false; end
    if ~isfield(opts, 'verbose'), opts.verbose = false; end

    % --- Чтение файла ---
    Change_p = readArrayFromTxt(filename);

    if isempty(Change_p) || size(Change_p, 2) < 2
        error('readRoadProfile:badData', ...
            'Файл "%s" не содержит двух столбцов (время, скорость).', filename);
    end

    time     = Change_p(:, 1);          % время [с]
    Velocity = Change_p(:, 2) / 3.6;    % км/ч -> м/с

    % --- Уплотнение на равномерную сетку ---
    Road.Time     = linspace(time(1), time(end), nPoints);
    Road.Velocity = interp1(time, Velocity, Road.Time, 'linear');

    % --- Численное дифференцирование ---
    dt = Road.Time(2) - Road.Time(1);
    Road.Acceleration = gradient(Road.Velocity, dt);

    % --- Info-сообщения ---
    if opts.verbose
        fprintf('readRoadProfile: "%s"\n', filename);
        fprintf('  исходных точек: %d, после уплотнения: %d\n', ...
                numel(time), nPoints);
        fprintf('  t = [%.3f ... %.3f] с\n', Road.Time(1), Road.Time(end));
        fprintf('  V: min = %.3f, max = %.3f м/с\n', ...
                min(Road.Velocity), max(Road.Velocity));
        fprintf('  a: min = %.3f, max = %.3f м/с^2\n', ...
                min(Road.Acceleration), max(Road.Acceleration));
    end

    % --- График ---
    if opts.plot
        figure;

        subplot(2,1,1)
        title('а)')
        hold on;
        xlabel('Время, с');
        ylabel({'Скорость', 'автомобиля, м/с'});
        plot(Road.Time, Road.Velocity);

        subplot(2,1,2)
        title('б)')
        hold on;
        xlabel('Время, с');
        ylabel({'Ускорение', 'автомобиля, м/с^2'});
        plot(Road.Time, Road.Acceleration);
    end
    Time = Road.Time;
    Velocity = Road.Velocity;
    Acceleration = Road.Acceleration;
end