%% Throttle Code
% PSP Active Control

clear;
clc;
fclose all;
CEA_input_name = 'throttle';


%% System Constants
R_t = 0.7335/39.37; % throat radius [m]
At =  pi*R_t^2; % Throat Area [meters]
exp_ratio = 2.8153; % Expansion ratio;
Pc_max = 250;   % Max Throttle Chamber Pressure [psi]
Pe_max = 17;    % Max Throttle Exit Pressure [psi]
cstar_eff = 0.92;   % C* efficency
cf_eff = 0.95;  % Cf efficiency;
throttle_pct = linspace(0.4,1,50);
thrust_max = 2446.52;   % Max Thrust [N]
g = 9.81;   % Gravity [m/s^2]
Pa = 14.7;  % Atmospheric Pressure [P]


%% Injector Geometry
injector_type = "pintle";   % injector type (i.e. pintle, impinging, coax shear, ect.)
pintle_center = "OX";       % which propellant is centered (injected through the holes on the pintle post)
A_OX = 0.048759654633879;              % ox orifice area [in^2]
A_FUEL = 0.040310068980444;             % fuel orifice area [in^2]
c_d_OX = .7;                % ox orifice discharge coefficient [N/A]
c_d_FUEL = .7;              % fuel orifice discharge coefficient [N/A]
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


%% Throttle Guess
for i=1:length(throttle_pct)
    
    Target_thrust = throttle_pct(i)*thrust_max;
    converged = 0;
    Pc_Max = 300;   % [psi]
    Pc_Min = 50;    % [psi]
    counter = 0;
    Pc_throttle_guess = Pc_max * throttle_pct(i);   % Inital guess[psi]
    
    while ~(converged)
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Enter CEA Call
        [cstar_cea, cf_cea, ~, ~, ~, ~, Pe_cea, ~, ~, ~, ~, ~, ~, ~, ~] = throttleCEA(Pc_throttle_guess, 0, fuel, fuel_weight, fuel_temp, oxidizer, oxidizer_temp, OF, 0, exp_ratio, 2, 1, 0, CEA_input_name);
        Pc_throttle_guess_SI = Pc_throttle_guess * 6895; % [Pa]
        Pe_cea = Pe_cea / 6895; % Convert the CEA Pa to PSI
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        cf_cea = cf_cea + (Pe_cea-Pa)/Pc_throttle_guess * exp_ratio; % Adjust the Cf from perfectly expanded to desired nozzle geometry
        cstar_guess_actual = cstar_cea * cstar_eff; % Adjusting C* with efficiency
        cf_guess_actual = cf_cea * cf_eff; % Adjusting Cf with efficiency;
        mdot_guess = (Pc_throttle_guess_SI) * At / cstar_guess_actual; % Propellant mass flow guess
        thrust_guess = cf_guess_actual*(Pc_throttle_guess_SI)*At;
    
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
    throttle_thrust_actual(i) = thrust_guess;
    Pc_throttle_actual(i) = Pc_throttle_guess;
    mdot_throttle_actual(i) = mdot_guess;
    fuel_massflow_rate(i) = mdot_guess/(1+OF)*2.20462;
    ox_massflow_rate(i)= mdot_guess*2.20462-fuel_massflow_rate(i);
   
end




fclose all;