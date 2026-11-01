% Air resistance strength
function P_w =Air_resistance(c_x, Area, ro, v)
P_w = c_x * Area * ro * ( v.* v ) / 2;
end
