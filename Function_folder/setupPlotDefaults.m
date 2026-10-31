function setupPlotDefaults()
%SETUPPLOTDEFAULTS Установка настроек графиков по умолчанию
%   Настраивает шрифты, цвета, толщину линий, сетку и размер фигур
%   для единообразного оформления всех графиков.
%
%   Использование:
%       setupPlotDefaults();
%
%   Рекомендуется вызывать в начале скрипта после clear/close.
%
%   Примечание: функция НЕ создаёт пустую фигуру/оси. Настройка
%   ColorOrder для текущих осей применяется только если оси уже есть.

    % --- Шрифты осей ---
    set(groot, 'DefaultAxesFontName', 'Times New Roman');
    set(groot, 'DefaultAxesFontSize', 30);

    % --- Шрифты текста ---
    set(groot, 'DefaultTextFontName', 'Times New Roman');
    set(groot, 'DefaultTextFontSize', 30);

    % --- Цвет фигуры ---
    set(groot, 'defaultFigureColor', 'w');

    % --- Пользовательская палитра цветов ---
    customColors = [...
             0         0         0
        0.8500    0.3250    0.0980
        0.9290    0.6940    0.1250
        0.4940    0.1840    0.5560
        0.4660    0.6740    0.1880
        0.3010    0.7450    0.9330
        0.6350    0.0780    0.1840];

    % Порядок цветов по умолчанию для новых осей
    set(0, 'DefaultAxesColorOrder', customColors);

    % Для УЖЕ существующих осей — только если они есть
    % (иначе gca создаст пустую фигуру)
    existingAxes = findall(0, 'Type', 'axes');
    if ~isempty(existingAxes)
        set(existingAxes, 'ColorOrder', customColors);
    end

    % --- Толщина линий ---
    set(groot, 'defaultLineLineWidth', 2);

    % --- Сетка ---
    set(groot, 'defaultAxesXGrid', 'on');
    set(groot, 'defaultAxesYGrid', 'on');

    % --- Размер фигуры ---
    set(groot, 'defaultFigurePosition', [0, 0, 1500, 1500]);
end