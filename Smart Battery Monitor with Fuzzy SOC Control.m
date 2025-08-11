clc;
clear;
close all;

% --- Simulation Parameters ---
time_step = 1;         % seconds
total_time = 200;      % seconds
SOC = 80;              % initial state of charge (%)
load_demand = 50;      % W (initial)
battery_capacity = 1000; % Wh
max_charge_rate = 100; % W
max_discharge_rate = 100; % W

% Log variables
SOC_log = [];
demand_log = [];

% --- Create Fuzzy Logic Controller ---
fis = mamfis('Name','BatteryFuzzy');

% Inputs: SOC and Load Demand
fis = addInput(fis,[0 100],'Name','SOC');
fis = addMF(fis,'SOC','trapmf',[0 0 20 40],'Name','Low');
fis = addMF(fis,'SOC','trimf',[30 50 70],'Name','Medium');
fis = addMF(fis,'SOC','trapmf',[60 80 100 100],'Name','High');

fis = addInput(fis,[0 100],'Name','Demand');
fis = addMF(fis,'Demand','trapmf',[0 0 20 40],'Name','Low');
fis = addMF(fis,'Demand','trimf',[30 50 70],'Name','Medium');
fis = addMF(fis,'Demand','trapmf',[60 80 100 100],'Name','High');

% Output: Charge/Discharge Rate
fis = addOutput(fis,[-max_discharge_rate max_charge_rate],'Name','PowerFlow');
fis = addMF(fis,'PowerFlow','trimf',[-100 -50 0],'Name','DischargeFast');
fis = addMF(fis,'PowerFlow','trimf',[-50 -20 0],'Name','DischargeSlow');
fis = addMF(fis,'PowerFlow','trimf',[-10 0 10],'Name','Idle');
fis = addMF(fis,'PowerFlow','trimf',[0 20 50],'Name','ChargeSlow');
fis = addMF(fis,'PowerFlow','trimf',[0 50 100],'Name','ChargeFast');

% Rules
rules = [
    % SOC Low
    "SOC==Low & Demand==High => PowerFlow=DischargeFast"
    "SOC==Low & Demand==Medium => PowerFlow=DischargeSlow"
    "SOC==Low & Demand==Low => PowerFlow=ChargeFast"
    % SOC Medium
    "SOC==Medium & Demand==High => PowerFlow=DischargeFast"
    "SOC==Medium & Demand==Medium => PowerFlow=Idle"
    "SOC==Medium & Demand==Low => PowerFlow=ChargeSlow"
    % SOC High
    "SOC==High & Demand==High => PowerFlow=DischargeFast"
    "SOC==High & Demand==Medium => PowerFlow=DischargeSlow"
    "SOC==High & Demand==Low => PowerFlow=Idle"
];

fis = addRule(fis,rules);

% --- Simulation Loop ---
for t = 1:time_step:total_time
    % Evaluate fuzzy controller
    power_flow = evalfis(fis,[SOC load_demand]);
    
    % Update SOC
    SOC = SOC + (power_flow * time_step / 3600) / (battery_capacity/100);
    SOC = max(0,min(100,SOC)); % limit between 0 and 100%
    
    % Random load demand change
    load_demand = max(0,min(100, load_demand + randi([-5,5])));
    
    % Log data
    SOC_log(end+1) = SOC;
    demand_log(end+1) = load_demand;
end

% --- Plot Results ---
figure;
subplot(2,1,1);
plot(1:total_time,SOC_log,'LineWidth',2);
xlabel('Time (s)');
ylabel('SOC (%)');
title('Battery State of Charge');
grid on;

subplot(2,1,2);
plot(1:total_time,demand_log,'r','LineWidth',2);
xlabel('Time (s)');
ylabel('Load Demand (%)');
title('Load Demand Profile');
grid on;

fprintf('Simulation finished. Final SOC = %.2f%%\n', SOC_log(end));
