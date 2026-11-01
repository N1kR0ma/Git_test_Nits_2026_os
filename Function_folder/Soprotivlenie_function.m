% % % % Calculation of rolling resistance force
function P_f = Soprotivlenie_function(f_speed_0, k_f, alpha, v, g, m)

        f_a = f_speed_0 * (1 + k_f * v.*v);
        f_0 = f_a.*cos(alpha) + sin(alpha);
        P_f = f_0 * m * g;

end

