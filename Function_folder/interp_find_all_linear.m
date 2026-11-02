function x_roots = interp_find_all_linear(x, y, y_target)
    x = x(:); y = y(:);
    [x, idx] = sort(x); y = y(idx);

    x_roots = [];
    for k = 1:numel(x)-1
        y1 = y(k); y2 = y(k+1);
        % y_target между y1 и y2 (включая границы)
        if (y_target - y1) * (y_target - y2) <= 0 && y1 ~= y2
            t = (y_target - y1) / (y2 - y1);
            x_roots(end+1,1) = x(k) + t*(x(k+1)-x(k)); %#ok<AGROW>
        elseif y1 == y2 && y1 == y_target
            % Целый отрезок постоянен и равен y_target — вернуть оба конца
            x_roots(end+1,1) = x(k);   %#ok<AGROW>
            x_roots(end+1,1) = x(k+1); %#ok<AGROW>
        end
    end
    x_roots = unique(round(x_roots, 12));
end