% % % % Calculation delta
function delta = delta_f(i_tr, efficiency, J_dv, n_0, J_kol, radius, mass)
   delta = 1 + (J_dv * i_tr .* i_tr  .* efficiency + n_0 * J_kol)...
       / (mass*radius*radius^2);
end