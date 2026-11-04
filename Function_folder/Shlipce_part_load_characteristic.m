function ...
    [Ge_real] ...           % ge_graf  - load characteristic matrix
    = Shlipce_part_load_characteristic( ...
    ge_basik, ...      % specific fuel consumption data
    Moment_coefficient, ...   % power range data
    w ...          % speed range data
   )             
    
    omega_max = max(w);
       
    way = erase(fileparts(which(mfilename)),'Function_folder');
    
    file_k_n = [way,'Data\Shlipke_coefficient\k_n_graf.txt'];
    file_k_ch = [way, 'Data\Shlipke_coefficient\k_ch_graf.txt'];
    
    % ---------- Load data from files ----------
    k_n_graf    = readmatrix(file_k_n);
    k_ch_graf   = readmatrix(file_k_ch);

    % ---------- Interpolate coefficients ----------
    k_01 = linspace(min(k_n_graf(:,1)), max(k_n_graf(:,1)), 100);
    k_02 = linspace(min(k_ch_graf(:,1)), max(k_ch_graf(:,1)), 100);

    k_n = interp1(k_n_graf(:,1), k_n_graf(:,2), w/omega_max*100);
    k_ch = interp1(k_ch_graf(:,1), k_ch_graf(:,2),  Moment_coefficient);

    % ---------- Minimum specific fuel consumption ----------
    ge_min = min(ge_basik);

k_n  = k_n(:);        % N×1 — по скорости (столбец)
k_ch = k_ch(:).';     % 1×K — по моменту (строка)
Ge_real = k_n * k_ch * ge_min;   % N×K:  Ge_real(i,j) = g_e(w_i, Me_j)
   
end