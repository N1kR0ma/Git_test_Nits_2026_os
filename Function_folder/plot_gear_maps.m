function plot_gears_maps2(MM_up_h, MM_up_speed, MM_down_h, MM_down_speed, varargin)
%PLOT_GEARS_MAPS Графики скорости переключения от педали газа (UP и DOWN).
%
%   plot_gears_maps(Map.MM_up_h, Map.MM_up_speed, ...
%                   Map.MM_down_h, Map.MM_down_speed)
%   plot_gears_maps(..., 'Name', Value, ...)
%
%   Строит окно из трёх областей:
%     - СЛЕВА  : UP   — Speed(h)
%     - ЦЕНТР  : легенда
%     - СПРАВА : DOWN — Speed(h)
%
%   ВХОД:
%     MM_up_h       — коэффициенты использования (педаль) для UP
%     MM_up_speed   — скорости переключения для UP
%     MM_down_h     — коэффициенты использования (педаль) для DOWN
%     MM_down_speed — скорости переключения для DOWN
%
%   ДОПОЛНИТЕЛЬНЫЕ ПАРАМЕТРЫ (Name-Value):
%     'Title'      — общий заголовок ('' по умолчанию)
%     'XLabel'     — подпись X ('Педаль газа, h')
%     'YLabel'     — подпись Y ('Скорость переключения, км/ч')
%     'UpTitle'    — заголовок UP ('UP')
%     'DownTitle'  — заголовок DOWN ('DOWN')
%     'FigureSize' — [ширина высота] ([1200 500] по умолчанию)
%     'FontSize'   — размер шрифта (10 по умолчанию)
%     'Markers'    — показывать маркеры (true по умолчанию)

    % ---------- Параметры по умолчанию ----------
    opts.Title      = '';
    opts.XLabel     = 'Педаль газа, h';
    opts.YLabel     = 'Скорость переключения, км/ч';
    opts.UpTitle    = 'UP';
    opts.DownTitle  = 'DOWN';
    opts.FigureSize = [1200 500];
    opts.FontSize   = 10;
    opts.Markers    = true;

    % ---------- Разбор Name-Value ----------
    if mod(numel(varargin), 2) ~= 0
        error('plot_gears_maps: параметры задаются парами Name, Value.');
    end
    for k = 1:2:numel(varargin)
        name = varargin{k};
        val  = varargin{k+1};
        if ~isfield(opts, name)
            error('plot_gears_maps: неизвестный параметр "%s".', name);
        end
        opts.(name) = val;
    end

    if opts.Markers
        mk_size = 6;
    else
        mk_size = 0;
    end

    % ---------- Фигура и layout ----------
    fig = figure('Color','w', 'Position',[100 100 opts.FigureSize(1) opts.FigureSize(2)]);
    if ~isempty(opts.Title)
        fig.Name = opts.Title;
    end
    tl = tiledlayout(fig, 1, 3, 'TileSpacing','compact', 'Padding','compact');

    % ---------- ЛЕВЫЙ график: UP ----------
    ax_up = nexttile(tl, 1);
    hold(ax_up,'on'); grid(ax_up,'on'); box(ax_up,'on');

    [h_up_sorted, idx_up] = sort(MM_up_h(:));
    sp_up_sorted = MM_up_speed(:);
    sp_up_sorted = sp_up_sorted(idx_up);

    plot(ax_up, h_up_sorted, sp_up_sorted, '-o', ...
        'Color',[0 0 1], 'LineWidth',1.8, 'MarkerSize',mk_size, ...
        'DisplayName','UP');

    xlabel(ax_up, opts.XLabel, 'FontSize', opts.FontSize);
    ylabel(ax_up, opts.YLabel, 'FontSize', opts.FontSize);
    title(ax_up, opts.UpTitle, 'FontSize', opts.FontSize+1, 'FontWeight','bold');

    % ---------- ЦЕНТР: легенда ----------
    ax_leg = nexttile(tl, 2);
    axis(ax_leg,'off'); hold(ax_leg,'on');

    plot(ax_leg, NaN, NaN, '-o', 'Color',[0 0 1], ...
        'LineWidth',1.8, 'MarkerSize',mk_size, 'DisplayName','UP');
    plot(ax_leg, NaN, NaN, '--s', 'Color',[1 0 0], ...
        'LineWidth',1.8, 'MarkerSize',mk_size, 'DisplayName','DOWN');

    lgd = legend(ax_leg, 'Location','center', 'FontSize',opts.FontSize, 'Box','on');

    % ---------- ПРАВЫЙ график: DOWN ----------
    ax_dn = nexttile(tl, 3);
    hold(ax_dn,'on'); grid(ax_dn,'on'); box(ax_dn,'on');

    [h_dn_sorted, idx_dn] = sort(MM_down_h(:));
    sp_dn_sorted = MM_down_speed(:);
    sp_dn_sorted = sp_dn_sorted(idx_dn);

    plot(ax_dn, h_dn_sorted, sp_dn_sorted, '--s', ...
        'Color',[1 0 0], 'LineWidth',1.8, 'MarkerSize',mk_size, ...
        'DisplayName','DOWN');

    xlabel(ax_dn, opts.XLabel, 'FontSize', opts.FontSize);
    ylabel(ax_dn, opts.YLabel, 'FontSize', opts.FontSize);
    title(ax_dn, opts.DownTitle, 'FontSize', opts.FontSize+1, 'FontWeight','bold');

    % ---------- Общий заголовок ----------
    if ~isempty(opts.Title)
        title(tl, opts.Title, 'FontSize', opts.FontSize+2, 'FontWeight','bold');
    end
end