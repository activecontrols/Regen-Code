% %% HELP Regenerative Cooling Sizing Code
% % Authors: Kamon Blong (kamon.blong@gmail.com), Jan Ayala, Andrew Radulovich, Alex Suppiah
% % First Created: 10/23/2022
% % Last Updated: 04/15/2023

   %{ 
    Description:
    This program calculates the heat flux and wall temperture across a
    regen engine. The user inputs engine definition parameters and channel
    inlet conditions. Steady state equilibrium equations are utilized to
    converge on a heatflux and temperature at each point. Calculations at
    the previous point are used as the initial conditions of the next as
    it moves down the engine. The program utilized CEA and CoolProp for
    combustion properties and coolant properties respectively.

    Program Methodology
    - define engine with user input
    - run CEA and get bartz film coefficient axially along chamber
    - begin iterating along channel length from nozzle end to the injector face
        - integrate heat entry and pressure loss for the given step size
        - repeat process all the way up the channel
    - repeat calculation at the throat using interpolated values from the
    previous step as the initial conditions
    - display heat transfer, temperatures, pressure drop, film coefficient,
    channel geometry, coolant velocity on the engine contour
    
    Inputs:
    - x_contour: 
    - y_contour:
    - R_t: Throat Radius
    - nozzle_regen_pct: 
    - mdotf: Mass flow rate of fuel/coolant (lb/s)
    - P_c: Chamber Pressure
    - P_e: Exit Pressure
    - Oxidizer: 
    - Fuel:
    - OF_ratio: 
    - wall_material:
    
    Outputs: 
    - 
    
    Assumptions:
    - Steady state
    - No backside wall heat transfer
    - Equally distributed temperature inside channels
    - Wicking heat into fuel doesn't change bulk gas temperature

   %}

%% INITIALIZATION
%clear;
clc; 
close all;
u = convertUnits;
CEA_input_name = 'regenCEA';

%% SIMULATION PARAMETERS (INPUTS)
plots = 0; % Do ansys or not ???? Dumb name
steps = 100; % Number of steps along chamber (Change resolution of simulation)
qdot_tolerance = 0.0001; % set heat transfer convergence tolerance


%% ENGINE DEFINITION (INPUTS)

% Engine Contour
contour = readmatrix('contour_100pts.xlsx'); % import engine contour
r_contour = (contour(:,2) * u.IN2M)'; % contour radius [m]
x_contour = (contour(:,1) * u.IN2M)'; % contour x-axis [m]
[R_t, t_local] = min(r_contour); % throat radius, throat location [m]
chamber_length = 0.0254 * 5.205; % chamber length (m) [conversion * in]
converging_length = 0.0254 * 1.8251; %  converging length (m) [conversion * in]
diverging_length = 0.0254 * 1.8557; % diverging length (m) [conversion * in]
total_length = chamber_length + converging_length + diverging_length; % total length (mm) 

% Propulsion Parameters
P_c = 250; % chamber pressure [psi] 
P_e = 17; % exit pressure [psi]
m_dot = 5 * u.LB2KG; % Coolant/fuel mass flow [kg/s]
fuel = 'C3H8O,2propanol'; % fuel definition
oxidizer = 'O2(L)'; % oxidizer definition
fuel_weight = 0; % ???  
fuel_temp = 293.15; % [K]
oxidizer_temp = 90.17; % [K]
OF = 1.2; % oxidizer/fuel ratio
cstar_eff = 0.92;  % C* efficiency;

% material properties
properties = readmatrix(pwd + "/bin/material_properties.xlsx");
k_w = properties(13:end,1:2); % thermal conductivity [W/m-K]
E = [properties(1:6, 9) properties(1:6,10)];
CTE = [properties(1:5,1) properties(1:5,3)]; % [ppm]
nu = 0.3; % poissons ratio (guess)
%e = 24 * 0.001; % surface roughness (mm) [micrometer*conversion]
roughness_table = readmatrix(pwd + "/bin/surface_roughness.xlsx",'Range','A12:E16');
e = [roughness_table(2,2), roughness_table(5,2)] .* 0.001; %Surface roughness (mm) [micrometer*conversion] [45, 90]
yield_strength = properties(1:8,1:2);
elongation_break = [properties(1:8,1) properties(1:8,5)];
N = 20*4;

% Cooling channel inlet initialization
coolant = 'Water'; %coolant definition
inlet_temperature = 293.16; % inlet temperature [K]
inlet_pressure = 600 * u.PSI2PA; % inlet pressure [PA]
coolantdirection = 0; % 1: direction opposite of hot gas flow direction
                      % 0: direction same as hot flow gas direction
                        
% channel geometry: (1: chamber) (min: throat) (2: nozzle end)
%t_w = 0.0005; % inner wall thickness [m]
t_w = [.001 .00075 .001];
%inter_length = .02 ; % Length where wall thickness will interpolate between chamber and nozzle
h_c = [.004 .003 .003]; % channel height [1 min 2] [m]    
w_c = [.007 .003 .004];% channel width [1 min 2] [m]
num_channels = 30; 


%t_w_c = .001778 ; % channel width at torch igniter
%t_h_c = .003 ; % channel height at torch igniter
h_c_extra = h_c(2);
w_c_extra = w_c(2);
offset_extra = 0.02;
inter_length =  converging_length - offset_extra; % Length where wall thickness will interpolate between chamber and nozzle
%extra_loc = [chamber_length, chamber_length + converging_length - .011547, chamber_length + converging_length];
extra_loc = [chamber_length, chamber_length + converging_length - offset_extra, chamber_length + converging_length];
t_w_c = w_c(1) ; % channel width at torch igniter
t_h_c =  h_c(1); % channel height at torch igniter
torch_loc = [2.2 3.2 3.7] .* 0.0254; % location of torch changing area [mm] [inch * conversion] [1 min 2]

heatflux_factor = 1;

%% Parse variables && initial calculations

% Convert imperial units to metric
A_t = (R_t ^ 2) * pi; % throat area [m^2]
P_c = P_c * u.PSI2PA; % chamber pressure [Pa]
P_e = P_e * u.PSI2PA; % exit pressure [Pa]

% Chamber Geometry 
D_t = R_t * 2; % diameter at nozzle throat [m]
R_of_curve = 1.5 * D_t / 2; % [m]
A_local = pi * (R_t) ^ 2; % local cross sectional areas of engine
        
% Discretize Chamber Length 
deltax = (total_length/(steps-1)); % change in distance per step [m]
points = steps; % number of points along chamber
x = 0:deltax:total_length; % length vector
x_plot = (x - chamber_length - converging_length); % length vector adjusted so that 0 is at the throat (mm)

% Parse engine section length vectors
torch_conv_length = torch_loc(2) - torch_loc(1);
torch_div_length = torch_loc(3)-torch_loc(2);
conv_1_length = extra_loc(2) - extra_loc(1);
conv_2_length = extra_loc(3) - extra_loc(2);

x_chamber1 = []; % chamber length vector before igniter
x_torch_conv = []; % igniter convergence
x_torch_div = []; % igniter divergence
x_chamber2 = []; % chamber length vector after igniter
x_converging1 = [];
x_diverging1 = [];
x_converging2 = [];% converging length vector
x_diverging = [];% diverging length vectir
for i = x 
    if i <= torch_loc(1)
        x_chamber1 = [x_chamber1 i];
    end
    if (torch_loc(1) < i) && (i <= torch_loc(2))
        x_torch_conv = [x_torch_conv i];
    end
    if (torch_loc(2) < i) && (i <= torch_loc(3))
        x_torch_div = [x_torch_div i];
    end
    if (torch_loc(3) < i) && (i <= chamber_length)
        x_chamber2 = [x_chamber2 i];
    end 
    if (chamber_length < i) && (i <= extra_loc(2))
        x_converging1 = [x_converging1 i];
    end 
    if (extra_loc(2) < i) && (i <= chamber_length + converging_length)
        x_converging2 = [x_converging2 i];
    end 
    if i > (chamber_length + converging_length)
        x_diverging = [x_diverging i];
    end 
end 

% parse channel geometry [1 min 2]
A = w_c .* h_c; % channel cross-sectional area (m^2) [1 min 2]
p_wet = 2*w_c + 2*h_c; % wetted perimeter of the pipe (m) [1 min 2]
hydraulic_D = (4.*A)./p_wet; % hydraulic diameter (m) [1 min 2]

% parse channel geometry over channel length
w_c_chamber1 = ones(1,size(x_chamber1,2)).*w_c(1); % channel width over chamber length (constant)
w_c_torch_conv = ((t_w_c-w_c(1))/(torch_conv_length)).*(x_torch_conv -x_torch_conv(1)) ... 
    + ones(1,size(x_torch_conv,2)).*w_c(1); % channel width over converging torch section
w_c_torch_div = ((w_c(1)-t_w_c)/(torch_div_length)).*(x_torch_div-x_torch_div(1))... 
    + ones(1,size(x_torch_div,2)).*t_w_c; % channel width over diverging torch section
w_c_chamber2 = ones(1,size(x_chamber2,2)).*w_c(1); % channel width over chamber length (constant)


w_c_converging1 = ((w_c_extra-w_c(1))/(conv_1_length)).*(x_converging1 -x_converging1(1)) ... 
         + ones(1,size(x_converging1,2)).*w_c(1); % channel width over converging length (linear interpolation)
if size(x_converging2,2) > 0
    w_c_converging2 = ((w_c(2)-w_c_extra)/(conv_2_length)).*(x_converging2 -x_converging2(1)) ... 
         + ones(1,size(x_converging2,2)).*w_c_extra; % channel width over converging length (linear interpolation)
else
    w_c_converging2 = [];
end
w_c_diverging = ((w_c(3)-w_c(2))/(diverging_length)).*(x_diverging-x_diverging(1))... 
        + ones(1,size(x_diverging,2)).*w_c(2);   % channel width over diverging length (linear interpolation)
w_c_x = [w_c_chamber1 w_c_torch_conv w_c_torch_div w_c_chamber2 w_c_converging1 w_c_converging2 w_c_diverging]; % combine channel width vectors


h_c_chamber1 = ones(1,size(x_chamber1,2)).*h_c(1); % channel height over chamber length (constant)
h_c_torch_conv = ((t_h_c-h_c(1))/(torch_conv_length)).*(x_torch_conv -x_torch_conv(1)) ... 
    + ones(1,size(x_torch_conv,2)).*h_c(1); % channel height over converging torch section
h_c_torch_div = ((h_c(1)-t_h_c)/(torch_div_length)).*(x_torch_div-x_torch_div(1))... 
    + ones(1,size(x_torch_div,2)).*t_h_c; % channel height over diverging torch section
h_c_chamber2 = ones(1,size(x_chamber2,2)).*h_c(1); % channel height over chamber length (constant


h_c_converging1 = ((h_c_extra-h_c(1))/(conv_1_length)).*(x_converging1 -x_converging1(1)) ... 
     + ones(1,size(x_converging1,2)).*h_c(1);    % channel height over converging length (linear interpolation)
if size(x_converging2,2) > 0
    h_c_converging2 = ((h_c(2)-h_c_extra)/(conv_2_length)).*(x_converging2 -x_converging2(1)) ... 
         + ones(1,size(x_converging2,2)).*h_c_extra;    % channel height over converging length (linear interpolation)
else
    h_c_converging2 = [];
end

h_c_diverging = ((h_c(3)-h_c(2))/(diverging_length)).*(x_diverging-x_diverging(1))... 
     + ones(1,size(x_diverging,2)).*h_c(2); % channel height over diverging length (linear interpolation)
h_c_x = [h_c_chamber1 h_c_torch_conv h_c_torch_div h_c_chamber2 h_c_converging1 h_c_converging2 h_c_diverging]; % combine channel height vectors

A_x = (w_c_x .* h_c_x); % channel area vector over channel length [m^2]
AR_channel = w_c_x ./ h_c_x;  % channel aspect ration over channel length
p_wet_x = 2.*w_c_x + 2 .* h_c_x; % wet perimeter over channel length [m]
hydraulic_D_x = ((4.*(A_x))./p_wet_x); % bydraulic Diameter over channel length [m]

x_to_chamber2 = [x_chamber1 x_torch_conv x_torch_div];
x_to_converging = [x_to_chamber2 x_chamber2];
x_to_throat = [x_to_converging x_converging1 x_converging2];
% calculate channel flow
m_dot_CHANNEL = m_dot / num_channels; % mass flow of channel (EQ 6.31)

% Wall thickness vector
x_inter_wall = [];
x_min_wall_section = [];
x_nozzle_wall = [];
for i = x
    if ((chamber_length) < i) && (i <= chamber_length + inter_length)
        x_inter_wall = [x_inter_wall i];
    end
    if((chamber_length + inter_length < i) && (i < chamber_length + converging_length))
        x_min_wall_section = [x_min_wall_section i];
    end
    if(chamber_length + converging_length <= i)
        x_nozzle_wall = [x_nozzle_wall i];
    end
end

t_w_chamber = t_w(1) * ones(size(x_to_converging));
t_w_inter = ((t_w(2)-t_w(1))/(inter_length)).*(x_inter_wall -x_inter_wall(1)) ... 
    + ones(1, size(x_inter_wall,2)).*t_w(1); % channel width over converging torch section
t_w_min_wall_section = ones(1,size(x_min_wall_section,2)) .* t_w(2);
t_w_nozzle = ((t_w(3)-t_w(2))/(diverging_length)).*(x_nozzle_wall -x_nozzle_wall(1)) ... 
    + ones(1, size(x_nozzle_wall,2)).*t_w(2); 
t_w_x = [t_w_chamber t_w_inter t_w_min_wall_section t_w_nozzle];


%% CHAMBER HEAT TRANSFER CALCULATIONS

% Step 1: Prescribe initial properties

% Prescribe area ratios
r_interpolated = interp1(x_contour,r_contour,x_plot,'linear','extrap'); % linearly interpolate radius vector  
subsonic_area_ratios = (pi * r_interpolated(x_plot < 0) .^ 2) / A_t; % subsonic area ratios on discretized points
supersonic_area_ratios = (pi * r_interpolated(x_plot > 0) .^ 2) / A_t; %  supersonic area ratios on discretized points
A_ratio = [subsonic_area_ratios, supersonic_area_ratios]; % area ratio vector [sub, sup]

% initialize property matrices
% axial coolant property matrices
P_l = zeros(1, points); % coolant pressure
T_l = zeros(1, points); % coolant temp
rho_l = zeros(1, points); % coolant density
v = zeros(1, points); % coolant ???

% axial cooling property matrices
qdot_l = zeros(1, points);  % liquid convective heat flux
qdot_g = zeros(1, points);  % gas convective heat flux
T_wl = zeros(1, points);    % liquid wall temperature
T_wg = zeros(1, points);    % gas wall temperature
h_g = zeros(1, points);     % gas film coefficient
sigma = zeros(1, points);   % film coefficient correction factor
h_l = zeros(1, points);     % liquid film coefficient

% % axial combustion property matrices
% c_star = zeros(1, points);  % characteristic velocity
% M = zeros(1, points);       % mach number
% gamma = zeros(1, points);   % ratio of specific heats
% P_g = zeros(1, points);     % combustion pressure
% T_g = zeros(1, points);     % combustion temperature
% mu_g = zeros(1, points);    % combustion viscosity 
% Pr_g = zeros(1, points);    % combustion prantl number
% cp_g = zeros(1, points);    % combustion coefficient of pressure ???

% fin matricies
rib_thickness = zeros(1,points);
A_c_fin = zeros(1,points);
fin_q = zeros(1,points);
eta_fin = zeros(1,points);
biot_fin = zeros(1,points);

% stress matricies
k_w_current = zeros(1,points);
yield = zeros(1,points);
elong = zeros(1,points);
E_current = zeros(1,points);
CTE_current = zeros(1,points);
CTE_liq_side = zeros(1,points);

epsilon_emax = zeros(1,points);
sigma_t = zeros(1,points); % tangential stress
sigma_tp = zeros(1,points); % tangential stress pressure
sigma_tt = zeros(1,points); % tangential stress temp
sigma_l = zeros(1,points); % longitudinal stress
sigma_ll = zeros(1,points); % longitudinal stress
sigma_lc = zeros(1,points); % longitudinal stress
sigmab = zeros(1,points); % buckling stress
sigma_v = zeros(1,points); % von mises stress
sigma_vl = zeros(1,points); % von mises stress
sigma_vc = zeros(1,points); % von mises stress
sigma_tp_cold = zeros(1,points); % Pressing channels before hotfire
epsilon_lc = zeros(1,points);
epsilon_ll = zeros(1,points); 
epsilon_t = zeros(1,points);
epsilon_vc = zeros(1,points);
epsilon_vl = zeros(1,points);
epsilon_tp = zeros(1,points);
epsilon_tt = zeros(1,points);

epsilon_tota = zeros(1,points);
epsilon_tott = zeros(1,points);
epsilon_pa = zeros(1,points);
epsilon_pt = zeros(1,points);
epsilon_peff = zeros(1,points);
epsilon_cs = zeros(1,points);
MS = zeros(1,points);
num_fires = zeros(1,points);
epsilon_toteff = zeros(1,points);
sigma_eff = zeros(1,points);
sigma_a = zeros(1,points);
sigma_t2 = zeros(1,points);
epsilon_cs_tot = zeros(1,points);
MS_lowcycle = zeros(1,points);

deltaT1 = zeros(1,points);
deltaT2 = zeros(1,points);

%call cea for all area ratios
i = 1;
for sub = subsonic_area_ratios
    [c_star, ~, ~, M(i), gamma(i), P_g(i), T_g(i), ~, mu_g(i), Pr_g(i), ~, ~, ~, cp_g(i)] = RunCEA(P_c, P_e, fuel, fuel_weight, fuel_temp, oxidizer, oxidizer_temp, OF, sub, 0, 2, 0, 0, CEA_input_name);
    i = i + 1;
end
i = size(subsonic_area_ratios, 2) + 1;
for sup = supersonic_area_ratios
    [c_star, ~, ~, M(i), gamma(i), P_g(i), T_g(i), ~, mu_g(i), Pr_g(i), ~, ~, ~, cp_g(i)] = RunCEA(P_c, P_e, fuel, fuel_weight, fuel_temp, oxidizer, oxidizer_temp, OF, 0, sup, 2, 0, 0, CEA_input_name);
    i = i + 1;
end
[~, ~, ~, ~, ~, P_g_tot, T_g_tot, ~, mu_g_tot, Pr_g_tot, ~, ~, ~, cp_g_tot] = RunCEA(P_c, P_e, fuel, fuel_weight, fuel_temp, oxidizer, oxidizer_temp, OF, 0, 0, 1, 0, 0, CEA_input_name);
c_star = c_star * cstar_eff;

% Steps 2 & 3: Set channel inlet properties
P_l(1) = inlet_pressure;
T_l(1) = inlet_temperature;

% Step 4: Take hot wall temperature guess and initialize loop
T_wg(1) = 1000; % initial guess of wall side temperature [K]

%% perform cooling loop along the chamber
for i = 1:points % where i is the position along the chamber (1 = injector, end = nozzle)

    T_wg_mn = 280; % minimum temperature bound [K]
    T_wg_mx = 1500; % maximum temperature bound [K]

    converged = 0; % wall temperature loop end condition
    counter = 0; % counter for loop
    while ~(converged)
        % Step 5: Calculate gas film coefficient and gas-side convective heat flux
        sigma(i) = (.5 * T_wg(i) / T_g_tot * (1 + (gamma(i) - 1) / 2 * M(i) ^ 2) + .5) ^ -.68 * (1 + (gamma(i) - 1) / 2 * M(i) ^ 2) ^ -.12; % film coefficient correction factor [N/A] (Huzel & Huang 86).
        h_g(i) = heatflux_factor * (0.026 / D_t ^ 0.2) * (mu_g_tot ^ 0.2 * cp_g_tot / Pr_g_tot ^ 0.6) * (P_c / c_star) ^ 0.8 * (D_t / R_of_curve) ^ 0.1 * (1 / A_ratio(i)) ^ .9 * sigma(i); % gas film coefficient [W/m^2-K] - bartz equation (Huzel & Huang 86).
        r = Pr_g(i) ^ (1 / 3); % recovery factor for a turbulent free boundary layer [N/A] - biased towards larger engines, very small engines should use Pr^.5 (Heister Table 6.2).
        T_r = T_g(i) * (1 + (gamma(i) - 1) / 2 * r * M(i) ^ 2); % recovery temperature [K] - corrects for compressible boundry layers (Heister EQ 6.15). 
        qdot_g(i) = h_g(i) * (T_r - T_wg(i)); % gas convective heat flux [W/m^2] (Heister EQ 6.16).
    
        % Step 6: Calculate liquid wall temperature
        k_w_current(i) = interp1(k_w(:,1), k_w(:,2), T_wg(i), 'nearest', 'extrap');
        T_wl(i) = T_wg(i) - qdot_g(i) * t_w_x(i) / k_w_current(i); % liquid wall temperature calculated via conduction through wall [K] (Heister EQ 6.29).

        % Step 7: Calculate liquid film coefficient
        % run coolprop to get coolant properties
        T_film = (T_wl(i) + T_l(i)) / 2;
        mu_lb = py.CoolProp.CoolProp.PropsSI('V','T', T_film, 'P', P_l(i), coolant); % viscosity of bulk coolant [Pa-s]
        cp_l = py.CoolProp.CoolProp.PropsSI('C' , 'T', T_film, 'P', P_l(i), coolant); % specific heat of coolant [J/kg-k] 
        k_l = py.CoolProp.CoolProp.PropsSI('L', 'T', T_film, 'P', P_l(i), coolant); % thermal conductivity of coolant [W/m-K]
        rho_l(i) = py.CoolProp.CoolProp.PropsSI('D','T', T_film,'P', P_l(i), coolant); % density of the coolant [???]
        v(i) = m_dot_CHANNEL / rho_l(i) / A_x(i); % velocity at step [m/s]
       
        Re_l = (rho_l(i) * v(i) * hydraulic_D_x(i)) / mu_lb; % reynolds number for channel flow [N/A] (Huzel and Huang , pg 90)
        Pr_l = (cp_l * mu_lb) / k_l; % prantl number [N/A] (Huzel and Huang, pg 90) 

            % Use moody diagram to find coefficient of friction
            if (i < size(x_chamber1,2)) || (((size(x_to_chamber2,2)) <= i) && (i < size(x_to_converging,2)))
                ed = e(2)/(hydraulic_D_x(i)*1000); % 90 degrees
            else
                ed = e(1)/(hydraulic_D_x(i)*1000); % 45 degrees
            end
            %ed = e/(hydraulic_D_x(i)*1000); % relative roughness
            f = moody(ed, Re_l); % friction factor

        % Nu_l = 0.023 * (Re_l ^ .8) * (Pr_l ^ .4) * (T_wl / T_l) ^ -.3; % nusselt number [N/A] - applicable for Re > 10,000, .7 < Pr < 160 (Heister EQ 6.19). ****
        Nu_l = (f / 8) * (Re_l - 1000) * Pr_l / (1 + 12.7 * (f / 8) ^ 0.5 * (Pr_l ^ (2/3) - 1)); % Gnielinksy correlation nusselt number [N/A] - 0.5 < Pr < 2000, 3000 < Re < 5e6
        h_l(i) = (Nu_l * k_l) / hydraulic_D_x(i); % liquid film coefficient [W/m^2-K] (Heister EQ 6.19)
        
        % Step 7.5: Fin heat transfer, adiabatic tip
        T_base = T_wl(i); % Temperature at fin base
        rib_thickness(i) = ((pi * (r_interpolated(i) + t_w_x(i) + h_c_x(i)) ^ 2 - pi * (r_interpolated(i) + t_w_x(i)) ^ 2 - h_c_x(i) * w_c_x(i) * num_channels) / num_channels) / h_c_x(i);
        P_fin = 2 * rib_thickness(i) + 2 * deltax; % Fin perimeter (step distance & channel width)
        A_c_fin(i) = rib_thickness(i) * deltax; % Fin area at current step
        m_fin = sqrt(h_l(i) * P_fin / (k_w_current(i) * A_c_fin(i))); % Fin m
        fin_q(i) = sqrt(h_l(i) * P_fin * k_w_current(i) * A_c_fin(i)) * (T_base - T_l(i)) * tanh(m_fin * h_c_x(i)) / (2 * deltax * h_c_x(i)); % Fin heat flux

        L_c = h_c_x + rib_thickness(i) / 2; % Corrected fin length (relate convection to adiabatic tip condition)
        eta_fin(i) = tanh(m_fin * L_c) / (m_fin * L_c);  % Fin efficiency

        % Step 8: Calculate liquid-side convective heat flux
        qdot_l(i) = h_l(i) * (T_wl(i) - T_l(i)) + 2 * fin_q(i); % liquid convective heat flux [W/m^2] (Heister EQ 6.29).

        % Step 9: Check for convergence and continue loop / next step
        if abs(qdot_g(i) - qdot_l(i)) > qdot_tolerance && counter < 250 % check for tolerance
            
            % convergence loop
            if qdot_g(i) - qdot_l(i) > 0
                T_wg_mn = T_wg(i);
            else 
                T_wg_mx = T_wg(i);
            end 
            T_wg(i) = (T_wg_mx + T_wg_mn) / 2;
    
            counter = counter + 1;
        else
            if i < points
                % Step 10: End step & update fluid properties
                wall_area = (w_c_x(i) + 2 * h_c_x(i) * eta_fin(i)) * deltax;
                T_l(i+1) = T_l(i) + (1 / (m_dot_CHANNEL * cp_l)) * qdot_g(i) * wall_area; % new liquid temperature [K] (Heister EQ 6.39)
                
                cf = f/4; % friction coefficient

                if i > 1
                    deltaP = (2*cf*(deltax/(hydraulic_D_x(i))) * rho_l(i) *(v(i))^(2)  + .5 * ((v(i)^2) -(v(i-1)^2))); % change in pressure (Bernoulli's equation)
                else
                    deltaP = (2*cf*(deltax/(hydraulic_D_x(i))) * rho_l(i) *(v(i))^(2)); % change in pressure (Heister 6.36)
                end
                
                % prepare for next step
                P_l(i+1) = P_l(i) - deltaP; % Update pressure for next iteration
                T_wg(i+1) = T_wg(i);  % new gas wall temp guess based on current temp
            end  

            if i <= points % structural calculations
                yield(i) = interp1(yield_strength(:,1), yield_strength(:,2), T_wg(i), 'linear', 'extrap');
                E_current(i) = interp1(E(:,1), E(:,2), T_wg(i), 'linear', 'extrap');
                CTE_current(i) = interp1(CTE(:,1), CTE(:,2), T_wg(i), 'nearest', 'extrap');
                CTE_liq_side(i) = interp1(CTE(:,1), CTE(:,2), T_wl(i), 'nearest', 'extrap');
                elong(i) = interp1(elongation_break(:,1), elongation_break(:,2), T_wg(i),'linear','extrap');
                epsilon_emax(i) = ((yield(i)*1000000)/ E_current(i));

                deltaT1(i) = T_wg(i) - T_wl(i);
                deltaT2(i) = ((T_wg(i) + T_wl(i))/2) - T_l(i);

                sigma_tp(i) = ( ((P_l(i)-P_g(i))/2).*((w_c_x(i)./t_w_x(i)).^2) );
                sigma_tp_cold(i) =  ( ((P_l(i))/2).*((w_c_x(i)./t_w_x(i)).^2) );
                sigma_tt(i) = (E_current(i)*CTE_current(i)*qdot_g(i)*t_w_x(i))/(2*(1-nu)*k_w_current(i));
                sigma_t(i) = ( ((P_l(i)-P_g(i))/2).*((w_c_x(i)./t_w_x(i)).^2) ) + (E_current(i)*CTE_current(i)*qdot_g(i)*t_w_x(i))/(2*(1-nu)*k_w_current(i)); % tangential stress
                %sigma_l(i) = E*CTE*(T_wg(i)-T_wl(i)); % longitudinal stress (The temperatures here are wrong and I'm not sure this is applicable to rectagular channels
                sigma_lc(i) = E_current(i)*(CTE_liq_side(i)*(T_wl(i)-T_l(i)) + ((CTE_liq_side(i)*deltaT1(i))/(2*(1-nu))));
                sigma_ll(i) = E_current(i)*(CTE_current(i)*(T_wg(i)-T_l(i)) + ((CTE_current(i)*deltaT1(i))/(2*(1-nu))));


                %sigmab = ??? ; % buckling stress
                sigma_vc(i) = sqrt(sigma_lc(i)^2 + sigma_t(i)^2 - sigma_lc(i)*sigma_t(i));
                sigma_vl(i) = sqrt(sigma_ll(i)^2 + sigma_t(i)^2 - sigma_ll(i)*sigma_t(i));

                % Calculate total Strains
                epsilon_lc(i) = ((CTE_liq_side(i)*deltaT1(i))/(2*(1-nu))) + CTE_liq_side(i)*(T_wl(i)-T_l(i));
                epsilon_ll(i) = ((CTE_current(i)*deltaT1(i))/(2*(1-nu))) + CTE_current(i)*(T_wg(i)-T_l(i));  
                epsilon_tp(i) = ( ((P_l(i)-P_g(i))/2).*((w_c_x(i)./t_w_x(i)).^2) )  /E_current(i);
                epsilon_tt(i) = ((E_current(i)*CTE_current(i)*qdot_g(i)*t_w_x(i))/(2*(1-nu)*k_w_current(i)))  /E_current(i);
                epsilon_t(i) = (( ((P_l(i)-P_g(i))/2).*((w_c_x(i)./t_w_x(i)).^2) ) + (E_current(i)*CTE_current(i)*qdot_g(i)*t_w_x(i))/(2*(1-nu)*k_w_current(i))) / E_current(i); % tangential stress
                epsilon_vc(i) = sqrt(epsilon_lc(i)^2 + epsilon_t(i)^2 - epsilon_lc(i)*epsilon_t(i));
                epsilon_vl(i) = sqrt(epsilon_ll(i)^2 + epsilon_t(i)^2 - epsilon_ll(i)*epsilon_t(i));



                % New structural calcs !?
                
                epsilon_tota(i) = ((CTE_current(i)*deltaT1(i))/(2*(1-nu))) + CTE_current(i) * deltaT2(i); 
                epsilon_tott(i) = epsilon_t(i);
                epsilon_toteff(i) = (2/sqrt(3)) * sqrt(((epsilon_tott(i)^2)+ epsilon_tott(i)*epsilon_tota(i) + (epsilon_tota(i))^2));
                sigma_a(i) = E_current(i) * epsilon_tota(i);
                sigma_t2(i) = E_current(i) * epsilon_tott(i);


                epsilon_pa(i) = epsilon_tota(i) - epsilon_emax(i);
                epsilon_pt(i) = epsilon_tott(i) - epsilon_emax(i);
                if epsilon_pa(i) < 0
                    epsilon_pa(i) = 0;
                end 
                if epsilon_pt(i) < 0
                    epsilon_pt(i) = 0;
                end
                epsilon_peff(i) = (2/sqrt(3)) * sqrt(((epsilon_pt(i)^2) + epsilon_pt(i)*epsilon_pa(i) + (epsilon_pa(i))^2));
                epsilon_cs(i) = ((elong(i)*(N^(-1/2)))/2);
                epsilon_cs_tot(i) = epsilon_cs(i) + 2*epsilon_emax(i);
                MS_lowcycle(i) = epsilon_cs(i) / (2*epsilon_peff(i));
                MS(i) = epsilon_cs_tot(i) / (2*epsilon_toteff(i));
%                 num_fires(i) = 1/4 * ((elong(i)/(4*(epsilon_peff(i))))^(2));
                num_fires(i) = 1/4 * (2 * ((epsilon_peff(i) - epsilon_emax(i)) / elong(i))) ^ (-2);
                sigma_eff(i) = E_current(i) * epsilon_toteff(i);
                sigma_a(i) = E_current(i) * epsilon_tota(i);
                sigma_t2(i) = E_current(i) * epsilon_tott(i);
              
            end

            converged = 1;
        end
    end
end

%% FEA INPUTS
ambient_chamber = [x; T_g]'; 
ambient_water = [x; T_l]';
gas_h = [x; h_g]';
liquid_h = [x; h_l]';
gas_p = [x; P_g]';
liquid_p = [x; P_l]';

%% PLOT OUTPUTS
overall_MS = min(MS);
Engine_life = min(num_fires);
yield_SF = min(yield)/(max(sigma_vl)*.000001);
fprintf("Margin of safety for engine life of %f hot fires: %.02f\n", N/4, overall_MS)
fprintf("Engine life (hot fires): %.02f\n", Engine_life)
fprintf("Safety factor to yield: %.02f\n", yield_SF)




figure('Name', 'Temperature Plot');
hold on;
set(gca, 'FontName', 'Times New Roman')
% temperature plot
% subplot(2,1,1)
yyaxis left
plot(x_plot .* 1000, T_wg, 'red', 'LineStyle', '-');
plot(x_plot .* 1000, T_wl, 'magenta', 'LineStyle', '-');
plot(x_plot .* 1000, T_l, 'blue', 'LineStyle', '-');
ylabel('Temperature [K]')
set(gca, 'Ycolor', 'k')
grid on

yyaxis right
%plot(x_contour .* 1000, r_contour .* 1000, 'black', 'LineStyle', '-');
plot(x_plot .* 1000, r_interpolated .* 1000, 'black', 'LineStyle', '-');
ylabel('Radius [mm]')
set(gca, 'Ycolor', 'k')
axis equal;

legend('T_w_g', 'T_w_l', 'T_l', 'Chamber Contour', 'Location', 'southoutside', 'Orientation', 'horizontal','Location','best')
title('Temperature Distribution')
xlabel('Location [mm]')

figure('Name', 'Heat Transfer Plots');
subplot(2,2,[1,2])
hold on;
set(gca, 'FontName', 'Times New Roman')
% heat flux plot
%subplot(2,1,2)
yyaxis left
plot(x_plot .* 1000, qdot_g ./ 1000, 'red', 'LineStyle', '-');
ylabel('Heat Flux [kW/m^2]')
set(gca, 'Ycolor', 'k')
grid on

yyaxis right
plot(x_plot .* 1000, r_interpolated .* 1000, 'black', 'LineStyle', '-');
ylabel('Radius [mm]')
set(gca, 'Ycolor', 'k')
axis equal;

legend('Convective Heat Flux', 'Chamber Contour','Location','best')
title('Heat Flux Distribution')
xlabel('Location [mm]')

subplot(2,2,3)
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.*1000, h_g)
title("Gas Film Coeffcient [W/m^2-K]")
xlabel("Location [mm]");
grid on
subplot(2,2,4)
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.*1000, h_l)
title("Liquid Film Coefficient [W/m^2-K]")
grid on


figure('Name','Water Flow')
subplot(2,2,[1,2])
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, P_l * 1/6894.757)
plot(x_plot.*1000, P_g *1/6894.757, 'y')
title("Liquid Pressure Loss")
xlabel("Location [mm]")
ylabel("Pressure [PSI]")
yyaxis right
plot(x_plot .* 1000, r_interpolated .* 1000, 'black', 'LineStyle', '-');
ylabel('Radius [mm]')
set(gca, 'Ycolor', 'k')
axis equal;
legend("Pressure Curve","Gas Pressure"," Chamber Contour",'Location','best')
grid on

subplot(2,2,3)
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, v);
title("Coolant Velocity [m/s]")
xlabel("Location [mm]")
grid on
subplot(2,2,4)
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.*1000, T_l)
title("Coolant Temperature [K]");
grid on




figure('Name','Channel Geometry');
subplot(2,2,[1,2]);
hold on
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, w_c_x .*1000);
plot(x_plot.*1000, h_c_x .*1000);
plot(x_plot.*1000, t_w_x .* 1000);
plot(x_plot.*1000, rib_thickness .*1000);
title("Channel Dimensions");
xlabel("Location [mm]");
ylabel("Channel Dimensions [mm]")
yyaxis right
plot(x_plot .* 1000, r_interpolated .* 1000, 'black', 'LineStyle', '-');
ylabel('Chamber Contour [mm]')
set(gca, 'Ycolor', 'k')
axis equal;
legend('Channel Width', 'Channel Height', 'Wall Thickness', 'Fin Thickness', 'Chamber Contour','Location','northwest')
grid on

subplot(2,2,3);
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.*1000, h_c_x./rib_thickness);
title("Fin Aspect Ratio [mm]");
xlabel("Location [mm]");
grid on
subplot(2,2,4);
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, AR_channel);
title("Channel Aspect Ratio");
xlabel("Location [mm]");
grid on

    
figure('Name', 'Structural results (Stress)')
subplot(2,2,[1,2])
hold on
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, sigma_vl*0.000001,'g',x_plot.* 1000, sigma_vc*0.000001)
plot(x_plot.* 1000, yield)
title("Von Mises Stress")
xlabel("Location [mm]")
ylabel("[MPA]")
yyaxis right
plot(x_plot .* 1000, r_interpolated .* 1000, 'black', 'LineStyle', '-');
ylabel('Radius [mm]')
set(gca, 'Ycolor', 'k')
axis equal;
legend('Von Mises Stress (Lands)','Von Mises Stress (Channels)', 'Yield Stress at Temperature', 'Chamber Contour','Location','best')
grid on
subplot(2,2,3)
hold on 
set(gca, 'FontName', 'Times New Roman')
hold on
plot(x_plot.* 1000, sigma_t*0.000001,"b");
plot(x_plot.* 1000, sigma_tp*0.000001,"m");
plot(x_plot.* 1000, sigma_tt*0.000001,"r");
legend("Total Stress", "Pressure contribution", "Thermal Contribution",'Location','best')
title("Tangential Stress (MPA)")
hold off
grid on
subplot(2,2,4)
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, sigma_lc*0.000001,x_plot.* 1000, sigma_ll*0.000001);
title("Longitudinal Stress (MPA)")
legend("At the channel", "At the lands",'Location','best');
xlabel("Location [mm]")
grid on
% subplot(2,2,3)
% plot(x_plot.* 1000, sigmab*0.000001)
% title("Buckling Stress (MPA)")
% xlabel("Location [mm]")
figure('Name', 'Structural results (Strain)')
subplot(2,2,[1,2])
hold on
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, epsilon_vl*100,'g',x_plot.* 1000, epsilon_vc*100)
title("Von Mises Strain [%]")
xlabel("Location [mm]")
ylabel("[%]")
yyaxis right
plot(x_plot .* 1000, r_interpolated .* 1000, 'black', 'LineStyle', '-');
ylabel('Radius [mm]')
set(gca, 'Ycolor', 'k')
axis equal;
legend('Von Mises Strain (Lands)','Von Mises Strain (Channels)', 'Chamber Contour','Location','best')
grid on
subplot(2,2,3)
hold on 
set(gca, 'FontName', 'Times New Roman')
hold on
plot(x_plot.* 1000, epsilon_t*100,"b");
plot(x_plot.* 1000, epsilon_tp*100,"m");
plot(x_plot.* 1000, epsilon_tt*100,"r");
legend("Total Strain", "Pressure contribution", "Thermal Contribution",'Location','best')
title("Tangential Strain (%)")
hold off
grid on
subplot(2,2,4)
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, epsilon_lc*100,x_plot.* 1000, epsilon_ll*100);
title("Longitudinal Strain (%)")
legend("At the channel", "At the lands",'Location','best');
xlabel("Location [mm]")
grid on

figure('Name', 'Fin results')
subplot(2,2,[1,2])
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, fin_q / 1000,'g')
title("Heat Flux")
xlabel("Location [mm]")
ylabel("[kW/m^2]")
yyaxis right
plot(x_plot .* 1000, r_interpolated .* 1000, 'black', 'LineStyle', '-');
ylabel('Radius [mm]')
set(gca, 'Ycolor', 'k')
axis equal;
legend('Fin Heat Flux', 'Chamber Contour','Location','best')
grid on
subplot(2,2,[3,4])
hold on 
set(gca, 'FontName', 'Times New Roman')
plot(x_plot.* 1000, eta_fin);
plot(x_plot.* 1000, h_c_x./rib_thickness);
title("Fin Efficiency")
legend("Fin Efficiency", "Aspect Ratio",'Location','best');
xlabel("Location [mm]")
hold off
grid on

figure("Name","pressing")
plot(x_plot.*1000, sigma_tp_cold*0.000001);
title("Cold water pressing stress")
ylabel("MPA");
xlabel("Location [mm]");

figure("Name","comparison")
plot(x_plot.*1000, epsilon_ll, x_plot.*1000, epsilon_tota)
legend("Definition1","Definition2")
figure("Name","effl")
plot(x_plot.*1000, epsilon_toteff, x_plot.*1000, epsilon_cs)
legend("total effective strain", "allowable cyclic strain")



%% THERMAL FEA
L_seg = 0.0283;
length = L_seg * u.IN2M;   
if plots

    M = 150;
    N = 150;
    R1 = R_t; % inner radius 
    R2 = R_t + h_c(2) * 4;  % outer radius
    nR = linspace(R1,R2,M);
    nT = linspace(-pi/num_channels, pi/num_channels + w_c(2) / R_t, N);
    [R, T_g] = meshgrid(nR,nT) ;
    xg = R.*cos(T_g); 
    yg = R.*sin(T_g);
    xg = xg(:);
    yg = yg(:);
    
    % Define partial channel 
    M = 50;
    N = 50;
    R1 = R_t + t_w; % inner radius 
    R2 = R_t + t_w + h_c(2);  % outer radius
    x = linspace(R1,R2,M);
    y = linspace(-pi/num_channels - w_c(2) / R_t / 2, -pi/num_channels + w_c(2) / R_t / 2, N);
    [R, T_g] = meshgrid(x, y);
    x = R.*cos(T_g); 
    y = R.*sin(T_g);
    x = x(:);
    y = y(:);
    channel = alphaShape(x,y);
    in = inShape(channel,xg,yg);
    xg = xg(~in);
    yg = yg(~in);
    
    % Define full channel 
    M = 50;
    N = 50;
    R1 = R_t + t_w; % inner radius 
    R2 = R_t + t_w + h_c(2);  % outer radius
    x = linspace(R1,R2,M);
    y = linspace(pi/num_channels - w_c(2) / R_t / 2, pi/num_channels + w_c(2) / R_t / 2, N);
    [R, T_g] = meshgrid(x, y);
    x = R.*cos(T_g); 
    y = R.*sin(T_g);
    x = x(:);
    y = y(:);
    channel = alphaShape(x,y);
    in = inShape(channel,xg,yg);
    xg = xg(~in);
    yg = yg(~in);
    
    zg = ones(numel(xg),1);
    xg = repmat(xg,5,1);
    yg = repmat(yg,5,1);
    zg = zg*linspace(0,length,5);
    zg = zg(:);
    shp = alphaShape(xg,yg,zg);
    
    [elements,nodes] = boundaryFacets(shp);
    
    nodes = nodes';
    elements = elements';
    
    % Generate model
    model = createpde("thermal","steadystate");
    geometryFromMesh(model,nodes,elements);
    
    pdegplot(model,"FaceLabels","on","FaceAlpha",0.5)
    
    generateMesh(model,"Hmax",h_c(2)/12);
    % figure
    % pdemesh(model)
    
    % Define material thermal properties
    thermalProperties(model,"ThermalConductivity",k_w);
    
    % Thermal boundary conditions
    thermalBC(model,"Face",10, ...
                     "ConvectionCoefficient",h_g_t, ...
                     "AmbientTemperature",T_r);
    thermalBC(model,"Face",[5 13 7 3 11 12 14], ...
                     "ConvectionCoefficient",h_l_t, ...
                     "AmbientTemperature",T_l(1));
    Rt = solve(model);
    
    figure
    pdeplot3D(model,"ColorMapData",Rt.Temperature)
    view([-90,90]);
    
    maxTempFEA = max(Rt.Temperature)
    
    %% Structural FEA
    model = createpde("structural","static-solid");
    geometryFromMesh(model,nodes,elements);
    generateMesh(model,"Hmax",1.84e-04);
    
    % Material properties
    structuralProperties(model,"YoungsModulus",E, ...
                                 "PoissonsRatio",nu, ...
                                 "CTE",CTE);
    model.ReferenceTemperature = 300 + 273.15; %in degrees K
    structuralBodyLoad(model,"Temperature",Rt);
    
    % Structural boundary conditions
    structuralBC(model,"Face",8,"Constraint","fixed");
    structuralBoundaryLoad(model,"Face",[5 13 7 3 11 12 14],"Pressure",P_l(end));
    structuralBoundaryLoad(model,"Face",10,"Pressure",P_c);
    
    % Solve structural
    Rts = solve(model);
    
    % Display results
    figure("units","normalized");
    hold on
    plot3(x(1),y(1),zg(end), "+", "LineWidth", 2,'Color','r')
    pdeplot3D(model,"ColorMapData",Rts.VonMisesStress, ...
                      "Deformation",Rts.Displacement, ...
                      "DeformationScaleFactor",2)
    view([-90,90]);
    caxis([1e6, 3e8])
    
    channelVonMises(1) = interpolateVonMisesStress(Rts,x(1),y(1),zg(end));
    channelVonMises(2) = interpolateVonMisesStress(Rts,x(1),y(end),zg(end));
    channelVonMises(3) = interpolateVonMisesStress(Rts,x(end),y(1),zg(end));
    channelVonMises(4) = interpolateVonMisesStress(Rts,xg(round(size(xg,1)-13200)),y(end),zg(end));
    maxVonMisesStressFEA = max(channelVonMises)

end

