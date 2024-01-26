%% Throttle Code
% PSP Active Control

clear;
clc;
fclose all;
CEA_input_name = 'throttle';


%% System Constants
breakpoints = 10;

R_t = 0.7335/39.37; % throat radius [m]
At =  pi*R_t^2; % Throat Area [meters]
exp_ratio = 2.8153; % Expansion ratio;
Pc_max = 250;   % Max Throttle Chamber Pressure [psi]
Pe_max = 17;    % Max Throttle Exit Pressure [psi]
cstar_eff = 0.92;   % C* efficency
cf_eff = 0.95;  % Cf efficiency;
throttle_pct = linspace(0.4, 1, breakpoints);
thrust_max = 2446.52;   % Max Thrust [N]
g = 9.81;   % Gravity [m/s^2]
Pa = 14.7;  % Atmospheric Pressure [P]


%% Injector Geometry
injector_type = "pintle";   % injector type (i.e. pintle, impinging, coax shear, ect.)
pintle_center = "OX";       % which propellant is centered (injected through the holes on the pintle post)
A_OX = 0.048759654633879;              % ox orifice area [in^2]
A_FUEL = 0.040310068980444;             % fuel orifice area [in^2]
cd_OX = .7;                % ox orifice discharge coefficient [N/A]
cd_FUEL = .7;              % fuel orifice discharge coefficient [N/A]
hole_number = 66;           % number of holes on pintle tip
hole_diameter = 0.031;      % hole diameter [in]
annulus_width = 0.017;     % annulus width [in]


%% Propellant Values
fuel_temp = 293.15; % [K]
oxidizer_temp = 90.17; % [K]
fuel = 'C3H8O,2propanol'; % fuel definition
fuel_weight = 100; % 
oxidizer = 'O2(L)'; % oxidizer definition
OF = 1.2; % oxidizer/fuel ratio
mdot = 1.2566; % Propellant mass flow rate [kg/s]
rho_FUEL = 49.06838 / 12^3; % fuel density [lbm/in^3]
rho_OX = 56.34 / 12^3;      % oxidizer density [lbm/in^3]


%% Matrix Initialization

throttle_thrust_actual = zeros(1, breakpoints);
Pc_throttle_actual = zeros(1, breakpoints);
mdot_throttle_actual = zeros(1, breakpoints);
fuel_massflow_rate = zeros(1, breakpoints);
ox_massflow_rate= zeros(1, breakpoints);
P_OX_manifold = zeros(1, breakpoints);
P_FUEL_manifold = zeros(1, breakpoints);
isp_throttle = zeros(1, breakpoints);
Pe_throttle = zeros(1, breakpoints);

%% Throttle Iteration

for i=1:length(throttle_pct)
    
    Target_thrust = throttle_pct(i)*thrust_max;
    converged = 0;
    Pc_Max = 300;   % [psi]
    Pc_Min = 50;    % [psi]
    counter = 0;
    Pc_throttle_guess = Pc_max * throttle_pct(i);   % Inital guess[psi]
    
    while ~(converged)
        % Enter CEA Call
        [cstar_cea, cf_cea, ~, ~, ~, ~, Pe_cea, ~, ~, ~, ~, ~, ~, ~, ~] = throttleCEA(Pc_throttle_guess, 0, fuel, fuel_weight, fuel_temp, oxidizer, oxidizer_temp, OF, 0, exp_ratio, 2, 1, 0, CEA_input_name);
        Pc_throttle_guess_SI = Pc_throttle_guess * 6895; % [Pa]
        Pe_cea = Pe_cea / 6895; % Convert the CEA Pa to PSI
        
        % Adjust perfectly expanded parameters 
        cf_cea = cf_cea + (Pe_cea - Pa) / Pc_throttle_guess * exp_ratio; % Adjust the Cf from perfectly expanded to desired nozzle geometry
        cstar_guess_actual = cstar_cea * cstar_eff; % Adjusting C* with efficiency
        cf_guess_actual = cf_cea * cf_eff; % Adjusting Cf with efficiency;
        isp_actual = cstar_guess_actual * cf_guess_actual / g; % Adjust the isp from perfectly expanded to desired nozzle geometry
        mdot_guess = (Pc_throttle_guess_SI) * At / cstar_guess_actual; % Propellant mass flow guess
        thrust_guess = cf_guess_actual*(Pc_throttle_guess_SI)*At;
    
        % Check for convergence
        if abs(thrust_guess - Target_thrust) > 1 && counter < 250 % check for tolerance
            % convergence loop
            if thrust_guess - Target_thrust > 0
                Pc_Max = Pc_throttle_guess;
            else 
                Pc_Min = Pc_throttle_guess;
            end 
            Pc_throttle_guess = (Pc_Max+Pc_Min) / 2;
    
            counter = counter + 1;
        else
            converged = 1;
    
        end
    end
    
    % Throttle results
    throttle_thrust_actual(i) = thrust_guess;   % N
    Pc_throttle_actual(i) = Pc_throttle_guess;   % Psi
    Pe_throttle(i) = Pe_cea;
    mdot_throttle_actual(i) = mdot_guess * 2.20462;  % lbm/s
    fuel_massflow_rate(i) = mdot_guess / (1 + OF);  % lbm/s
    ox_massflow_rate(i)= mdot_guess - fuel_massflow_rate(i); % lbm/s
    isp_throttle(i) = isp_actual; % s

    % Injector pressure calculations
    P_OX_manifold(i) = (ox_massflow_rate(i) / cd_OX * A_OX * hole_number) ^ 2 / rho_OX + Pc_throttle_actual(i);
    P_FUEL_manifold(i) = (ox_massflow_rate(i) / cd_FUEL * A_FUEL) ^ 2 / rho_FUEL + Pc_throttle_actual(i);

end

%% FIGURES

% Throttle results for chamber
figure('Name', 'Throttle Chamber Results')

subplot(2,2,1)
hold on 
plot(throttle_pct, throttle_thrust_actual * 0.224809)
title("Thrust")
xlabel("Throttle %")
ylabel("Thrust (lbf)")

subplot(2,2,2)
hold on 
plot(throttle_pct, Pe_throttle)
title("Exit Pressure")
xlabel("Throttle %")
ylabel("Pressure (Psi)")

subplot(2,2,3)
hold on 
plot(throttle_pct, Pc_throttle_actual)
title("Chamber Pressure")
xlabel("Throttle %")
ylabel("Pressure (psi)")

subplot(2,2,4)
hold on 
plot(throttle_pct, isp_throttle)
title("Isp")
xlabel("Throttle %")
ylabel("Thrust")


% Throttle results for injector
figure('Name', 'Throttle Injector Results')

subplot(1,2,1)
hold on 
plot(throttle_pct, P_OX_manifold)
title("Oxidizer Manifold Pressure")
xlabel("Throttle %")
ylabel("Pressure (psi)")

subplot(1,2,2)
hold on 
plot(throttle_pct, P_FUEL_manifold)
title("Fuel Manifold Pressure (psi)")
xlabel("Throttle %")
ylabel("Pressure (psi)")


fclose all;