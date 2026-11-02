function plot_gears_maps2(MM_up_h, MM_up_speed, MM_down_h, MM_down_speed, varargin)
%PLOT_GEARS_MAPS Графики скорости переключения от педали газа.

    % ---------- Параметры по умолчанию ----------
    opts.Title      = '';
    opts.XLabel     = 'Педаль газа, h';
    opts.YLabel     = 'Скорость переключения, км/ч';
    opts.UpTitle    = 'UP (сплошная)';
    opts.DownTitle  = 'DOWN (пунктир)';
    opts.FigureSize = [1200 700]; % Сделали повыше, чтобы легенда в 1 столбец влезла
    opts.FontSize   = 10;
    opts.Markers    = false;

    % ---------- Разбор Name-Value ----------
    if mod(numel(varargin), 2) ~= 0
        error('plot_gears_maps2: параметры задаются парами Name, Value.');
    end
    for k = 1:2:numel(varargin)
        name = varargin{k};
        val  = varargin{k+1};
        if ~isfield(opts, name)
            error('plot_gears_maps2: неизвестный параметр "%s".', name);
        end
        opts.(name) = val;
    end

    % ---------- Цветовая палитра для передач ----------
    n_shift_up = size(MM_up_h, 1);
    n_shift_dn = size(MM_down_h, 1);
    max_gears  = max(n_shift_up, n_shift_dn);
    
    % Генерируем уникальные цвета для каждой передачи
    colors = lines(max_gears); 

    % ---------- Фигура и layout ----------
    fig = figure('Color','w', 'Position',[100 100 opts.FigureSize(1) opts.FigureSize(2)]);
    if ~isempty(opts.Title)
        fig.Name = opts.Title;
    end
    
    % Пропорции ширины: [4 1 4]. Центральная колонка (легенда) уже.
    tl = tiledlayout(fig, 1, 3, 'TileSpacing','compact', 'Padding','compact');
    tl.GridSize = [1 3]; % Явно указываем сетку
    % В MATLAB нельзя напрямую задать пропорции через tiledlayout, 
    % поэтому сделаем это через ширину фигуры и отступы ниже.

    % Общие пределы осей
    min_h = min([MM_up_h(:); MM_down_h(:)]);
    max_h = max([MM_up_h(:); MM_down_h(:)]);
    min_v = min([MM_up_speed(:); MM_down_speed(:)]);
    max_v = max([MM_up_speed(:); MM_down_speed(:)]);
    xlim_common = [min_h - 0.05*(max_h-min_h), max_h + 0.05*(max_h-min_h)];
    ylim_common = [0, max_v + 0.1*(max_v-min_v)];

    % ---------- ЛЕВЫЙ график: UP ----------
    ax_up = nexttile(tl, 1);
    hold(ax_up,'on'); grid(ax_up,'on'); box(ax_up,'on');
    xlim(ax_up, xlim_common); ylim(ax_up, ylim_common);

    for i = 1:n_shift_up
        h_i  = MM_up_h(i, :);
        sp_i = MM_up_speed(i, :);
        [h_sorted, idx] = sort(h_i);
        sp_sorted = sp_i(idx);
        
        c = colors(i, :);
        
        % Убрали text(...) - номера передач больше не рисуем
        plot(ax_up, h_sorted, sp_sorted, '-', ...
            'Color', c, 'LineWidth', 2, 'HandleVisibility', 'off');
    end

    xlabel(ax_up, opts.XLabel, 'FontSize', opts.FontSize);
    ylabel(ax_up, opts.YLabel, 'FontSize', opts.FontSize);
    title(ax_up, opts.UpTitle, 'FontSize', opts.FontSize+1, 'FontWeight','bold');

    % ---------- ЦЕНТР: легенда ----------
    ax_leg = nexttile(tl, 2);
    axis(ax_leg,'off'); hold(ax_leg,'on');
    
    for i = 1:max_gears
        c = colors(i, :);
        plot(ax_leg, NaN, NaN, '-', 'Color', c, 'LineWidth', 2, ...
             'DisplayName', sprintf('Передача %d', i));
    end
    
    % Увеличиваем шрифт до opts.FontSize + 2 (то есть 12 при базовом 10)
    lgd = legend(ax_leg, 'Location','north', 'FontSize', opts.FontSize + 2, 'Box','on');
    lgd.Title.String = 'Цвета передач';
    
    % Увеличиваем и шрифт заголовка легенды
    lgd.Title.FontSize = opts.FontSize + 3;
    
    % Оставляем образцы линий компактными
    lgd.ItemTokenSize = [15, 10]; 

    % ---------- ПРАВЫЙ график: DOWN ----------
    ax_dn = nexttile(tl, 3);
    hold(ax_dn,'on'); grid(ax_dn,'on'); box(ax_dn,'on');
    xlim(ax_dn, xlim_common); ylim(ax_dn, ylim_common);

    for i = 1:n_shift_dn
        h_i  = MM_down_h(i, :);
        sp_i = MM_down_speed(i, :);
        [h_sorted, idx] = sort(h_i);
        sp_sorted = sp_i(idx);
        
        c = colors(i, :);
        
        % Убрали text(...) - номера передач больше не рисуем
        plot(ax_dn, h_sorted, sp_sorted, '--', ...
            'Color', c, 'LineWidth', 2, 'HandleVisibility', 'off');
    end

    xlabel(ax_dn, opts.XLabel, 'FontSize', opts.FontSize);
    ylabel(ax_dn, opts.YLabel, 'FontSize', opts.FontSize);
    title(ax_dn, opts.DownTitle, 'FontSize', opts.FontSize+1, 'FontWeight','bold');

    % ---------- Общий заголовок ----------
    if ~isempty(opts.Title)
        title(tl, opts.Title, 'FontSize', opts.FontSize+2, 'FontWeight','bold');
    end
    
    % Небольшая хитрость, чтобы центральная колонка была физически уже:
    % (в MATLAB tiledlayout делит поровну, но мы можем сжать саму легенду 
    % через ItemTokenSize и шрифт, что уже сделано выше)
end