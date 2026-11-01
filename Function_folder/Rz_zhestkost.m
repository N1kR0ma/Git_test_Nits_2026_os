function Rz_mass = Rz_zhestkost(Force_ort, F_axial, X, C, CM_count, CM_y)
%%%%  Force --- Сила приложенная к центру масс ортогонал ос авт
%%%%  Lenght --- расстояни до оси отсчитывая от 1й оси
%%%%  C --- Жёсткость осей начиная с 1й
%%%%  CM_count --- Расстояние до центра масс

%%%% Перевод системы координат в ЦМ от 1й оси
X = X - CM_count;

%%% Количество элементов в массиве
L_x = length(X);

%%% Создание матрицы с коэффициентами в соотв с курсом ДТС МГТУ
Matrix_kf = -eye(L_x+1,L_x+1);

%%% Промежуточная матрица смещённая единичная
Plus = vertcat(eye(L_x,L_x), zeros(1, L_x));
Plus = horzcat(zeros(L_x+1, 1),Plus);

%%%  Получение коэффициентов вычитания сил
Matrix_kf = Matrix_kf + Plus;
ones(1,L_x+1);

%%%% Коэффициенты из уравнения силового баланса
Matrix_kf(end-1,:) = ones(L_x+1,1);
Matrix_kf(end,:) = horzcat(X, [0]);

%%% Промежуточные матрицы для разницы координат осей
X_1 = X;
X_1(1) = [];
X_end = X;
X_end(end) = [];

%%%%  Финальная матрица коэффициентов для автомобиля
Minus = X_end - X_1;
Minus = horzcat(Minus,zeros(1, 2));
Matrix_kf(:,end) = Minus;

%%%% Матрица значений
Matrix_b = zeros(L_x+1, 1);
Matrix_b(end-1,1) = Force_ort;
Matrix_b(end,1) = F_axial * CM_y;

%%%% Решение матричного уравнения для получения массива сил
% Matrix_force = Matrix_kf^-1*Matrix_b;
Matrix_force = Matrix_kf \ Matrix_b;
%%%% Вывод значений силы по осям
Rz_mass = Matrix_force(1:end-1,1);

%%%% 
disp('Распределение реакций по осям автомобиля начиная с 1й')
for i =1:length(Rz_mass)
    fprintf('Реакция на оси № %.1d --- %.2f Н \n', i, Rz_mass(i))
end
    fprintf('Угол наклона автомобиля %.2f рад \n', Matrix_force(end)/C)
end