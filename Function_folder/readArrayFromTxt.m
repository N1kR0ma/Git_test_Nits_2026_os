function data = readArrayFromTxt(filename)
%READARRAYFROMTXT Чтение числового массива из .txt-файла
%   data = readArrayFromTxt(filename) читает текстовый файл,
%   содержащий числа (разделители: пробел, табуляция, запятая,
%   точка с запятой), и возвращает числовую матрицу.
%
%   Пример:
%       A = readArrayFromTxt('data.txt');
%
%   Поддерживаются:
%       - строки с числами, разделёнными пробелами/табами/запятыми
%       - пустые строки (пропускаются)
%       - строки-комментарии, начинающиеся с % или #
%       - десятичная точка и запятая (автоопределение)
%
%   Если в файле найдены комментарии или посторонние символы,
%   в рабочую область выводится предупреждение (warning) с указанием
%   номеров строк и кратким описанием проблемы.
%   При успешном чтении без замечаний — вывод в workspace отсутствует.

    arguments
        filename (1,:) char {mustBeFile}
    end

    % --- Чтение всех строк файла ---
    fid = fopen(filename, 'r');
    if fid == -1
        error('readArrayFromTxt:openFailed', ...
              'Не удалось открыть файл: %s', filename);
    end
    cleaner = onCleanup(@() fclose(fid));

    rawLines = {};
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end
        rawLines{end+1} = line; %#ok<AGROW>
    end

    % --- Классификация строк: числа / пустые / комментарии / мусор ---
    nAll = numel(rawLines);
    isNumeric   = false(nAll, 1);
    isComment   = false(nAll, 1);
    isGarbage   = false(nAll, 1);
    garbageInfo = {};   % {номер строки, текст}

    for k = 1:nAll
        s = strtrim(rawLines{k});

        if isempty(s)
            continue;                       % пустая строка — норм
        elseif startsWith(s, '%') || startsWith(s, '#')
            isComment(k) = true;            % комментарий
            continue;
        end

        % Пробуем распознать строку как набор чисел
        sNum = strrep(s, ',', ' ');
        sNum = strrep(sNum, ';', ' ');
        vals = sscanf(sNum, '%f');
        if isempty(vals)
            isGarbage(k) = true;            % не числа вообще
            garbageInfo{end+1} = sprintf('строка %d: "%s"', k, s); %#ok<AGROW>
        else
            % Проверим, что после извлечения чисел не осталось букв
            % (кроме допустимых разделителей)
            rest = regexprep(sNum, '[-+0-9.eE]', '');
            rest = strtrim(rest);
            if ~isempty(rest)
                isGarbage(k) = true;
                garbageInfo{end+1} = sprintf('строка %d: "%s"', k, s); %#ok<AGROW>
            else
                isNumeric(k) = true;
            end
        end
    end

    % --- Сообщения в workspace (только если есть замечания) ---
    if any(isComment)
        idxC = find(isComment);
        warning('readArrayFromTxt:commentsFound', ...
            'Файл "%s": найдено %d строка(и) комментариев (строки: %s). Они пропущены.', ...
            filename, numel(idxC), mat2str(idxC(:).'));
    end

    if any(isGarbage)
        warning('readArrayFromTxt:garbageFound', ...
            'Файл "%s": найдено %d строка(и) с посторонними символами (пропущены):\n  %s', ...
            filename, numel(garbageInfo), strjoin(garbageInfo, '\n  '));
    end

    % --- Оставляем только числовые строки ---
    lines = rawLines(isNumeric);

    if isempty(lines)
        data = [];
        return;
    end

    % --- Определение десятичного разделителя ---
    sample = strjoin(lines, ' ');
    hasComma = contains(sample, ',');
    hasDot   = contains(sample, '.');
    decimalComma = hasComma && ~hasDot;

    % --- Разбор строк ---
    nRows = numel(lines);
    rows  = cell(nRows, 1);
    nCols = 0;

    for k = 1:nRows
        s = strtrim(lines{k});
        if decimalComma
            s = strrep(s, ',', '.');
        end
        s = strrep(s, ',', ' ');
        s = strrep(s, ';', ' ');
        vals = sscanf(s, '%f');
        rows{k} = vals(:).';
        nCols = max(nCols, numel(vals));
    end

    % --- Сборка матрицы (недостающие элементы -> NaN) ---
    data = NaN(nRows, nCols);
    for k = 1:nRows
        data(k, 1:numel(rows{k})) = rows{k};
    end
end