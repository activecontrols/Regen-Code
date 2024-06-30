% This function defines the GUI and initial default inputs
function ChugGUI
global h2 % make h2 sharable for radio button query later
%%% GUI Pixel Size Position Parameters
wall=10; % spacing from the walls of the figure
txh=125; % horizontal length of a text window
txv=30; % vertical length of a text window
edh=75; % horizontal length of an edit window
edv=txv; % vertical length of an edit window
sph=10; % general horizontal spacing
spv=10; % general vertical spacing
figx=2*wall+2*txh+4*sph+2*edh; % figure horizontal length
figy=770; % figure vertical length
%%% Structure s1 contains all the GUI handles (figure, edit windows, text
%%% windows, and buttons).
% % Create figure that contains all the GUIs
s1.fig = figure('position', [450 50 figx figy],...
    'name','Chug Stability Code v1.7','MenuBar','none','NumberTitle','off');
% % Create editable text areas (with default input strings) and
% % description text areas on the figure
% Gas MW (lbm/lbmol)
s1.edit1 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+7*edv+7*spv edh edv],...
    'string', '11.54');
s1.text1 = uicontrol ('style', 'text', ...
    'position', [wall wall+7*txv+7*spv txh txv],...
    'string', 'Gas MW (lbm / lbmol)');
% c* (ft/sec)
s1.edit2 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+8*edv+8*spv edh edv],...
    'string', '7702');
s1.text2 = uicontrol ('style', 'text',...
    'position', [wall wall+8*txv+8*spv txh txv],...
    'string', 'c* (ft/sec)');
% Chamber Pressure (psia)
s1.edit3 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+9*edv+9*spv edh edv],...
    'string', '36.4');
s1.text3 = uicontrol ('style', 'text',...
    'position', [wall wall+9*txv+9*spv txh txv],...
    'string', ' Chamber Pressure (psia)');
% Oxidizer Time Lag (msec)
s1.edit4 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+10*edv+10*spv edh edv],...
    'string', '3.7');
s1.text4 = uicontrol ('style', 'text',...
    'position', [wall wall+10*txv+10*spv txh txv],...
    'string', ' Oxidizer Time Lag (msec)');
% Slope of c*(MR) (ft/sec-MR)
s1.edit5 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+4*sph+edh wall+8*edv+8*spv edh edv],...
    'string', '-330');
s1.text5 = uicontrol ('style', 'text',...
    'position', [wall+txh+3*sph+edh wall+8*txv+8*spv txh txv],...
    'string', 'Slope of c*(MR) (ft/sec-MR)');
% Chamber Temperature (deg R)
s1.edit6 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+9*edv+9*spv edh edv],...
    'string', '5532');
s1.text6 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+9*txv+9*spv txh txv],...
    'string', 'Chamber Temperature (deg R)');
% Fuel Time Lag (msec)
s1.edit7 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+10*edv+10*spv edh edv],...
    'string', '0.1');
s1.text7 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+10*txv+10*spv txh txv],...
    'string', ' Fuel Time Lag (msec)');
% Label for Combustion Parameters
s1.textA = uicontrol ('style', 'text' , 'fontweight', 'bold',...
    'fontsize', 9, 'HorizontalAlignment', 'left',...
    'position', [wall wall+11*txv+10*spv 2*txh txv],...
    'string', 'Combustion Parameters');
% Oxidizer Exponent, a (mo=Cd*Dpo^a)
s1.edit8 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+12*edv+12*spv edh edv],...
    'string', '0.5');
s1.text8 = uicontrol ('style', 'text',...
    'position', [wall wall+12*txv+12*spv txh txv],...
    'string', ' Oxidizer Exponent, a (mo=Cd*Dpo^a)');
% Oxidizer Flow Rate (lbm/sec)
s1.edit9 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+13*edv+13*spv edh edv],...
    'string', '2.49');
s1.text9 = uicontrol ('style', 'text',...
    'position', [wall wall+13*txv+13*spv txh txv],...
    'string', 'Oxidizer Flow Rate (lbm/sec)');
% Oxidizer Pressure Drop (psi)
s1.edit10 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+14*edv+14*spv edh edv],...
    'string', '6');
s1.text10 = uicontrol ('style', 'text',...
    'position', [wall wall+14*txv+14*spv txh txv],...
    'string', 'Oxidizer Pressure Drop (psi)');
% Fuel Exponent, b (mf=Cd*Dpf^b)
s1.edit11 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+12*edv+12*spv edh edv],...
    'string', '1.0');
s1.text11 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+12*txv+12*spv txh txv],...
    'string', ' Fuel Exponent, b (mf=Cd*Dpf^b)');
% Fuel Flow Rate (lbm/sec)
s1.edit12 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+13*edv+13*spv edh edv],...
    'string', '0.49');
s1.text12 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+13*txv+13*spv txh txv],...
    'string', ' Fuel Flow Rate (lbm/sec)');
% Fuel Pressure Drop (psi)
s1.edit13 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+14*edv+14*spv edh edv],...
    'string', '4.9');
s1.text13 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+14*txv+14*spv txh txv],...
    'string', ' Fuel Pressure Drop (psi)');
% Label for Hydraulics
s1.textB = uicontrol ('style', 'text',...
    'fontweight', 'bold', 'fontsize', 9, 'HorizontalAlignment', 'left',...
    'position', [wall wall+15*txv+14*spv 2*txh txv],...
    'string', 'Hydraulics');
% Cylinder Length (in)
s1.edit14 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+16*edv+16*spv edh edv],...
    'string', '5.0');
s1.text14 = uicontrol ('style', 'text',...
    'position', [wall wall+16*txv+16*spv txh txv],...
    'string', ' Cylinder Length (in)');
% Chamber Diameter (in)
s1.edit15 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+17*edv+17*spv edh edv],...
    'string', '10.0');
s1.text15 = uicontrol ('style', 'text',...
    'position', [wall wall+17*txv+17*spv txh txv],...
    'string', ' Chamber Diameter (in)');
% Convergent Section Length (in)
s1.edit16 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+16*edv+16*spv edh edv],...
    'string', '7.1');
s1.text16 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+16*txv+16*spv txh txv],...
    'string', 'Convergent Section Length (in)');
% Throat Diameter (in)
s1.edit17 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+17*edv+17*spv edh edv],...
    'string', '4.95');
s1.text17 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+17*txv+17*spv txh txv],...
    'string', ' Throat Diameter (in)');
% Label for Geometry
s1.textC = uicontrol ('style', 'text',...
    'fontweight', 'bold', 'fontsize', 9, 'HorizontalAlignment', 'left',...
    'position', [wall wall+18*txv+17*spv 2*txh txv],...
    'string', 'Geometry');
% Dpo/Pc Axis Max
s1.edit18 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+edv+spv edh edv],...
    'string', '0.5');
s1.text18 = uicontrol ('style', 'text',...
    'position', [wall wall+txv+spv txh txv],...
    'string', 'Dpo/Pc Axis Max');
% Maximum Frequency (Hz)
s1.edit19 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+2*edv+2*spv edh edv],...
    'string', '300');
s1.text19 = uicontrol ('style', 'text',...
    'position', [wall wall+2*txv+2*spv txh txv],...
    'string', ' Max Frequency (Hz)');
% Dpf/Pc Axis Max
s1.edit20 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+edv+spv edh edv],...
    'string', '0.5');
s1.text20 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+txv+spv txh txv],...
    'string', 'Dpf/Pc Axis Max');
% Frequency Resolution (Hz)
s1.edit21 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+edh+4*sph wall+2*edv+2*spv edh edv],...
    'string', '0.1');
s1.text21 = uicontrol ('style', 'text',...
    'position', [wall+txh+edh+3*sph wall+2*txv+2*spv txh txv],...
    'string', 'Frequency Resolution (Hz)');
% Label for Ranging Information
s1.textD = uicontrol ('style', 'text',...
    'fontweight', 'bold', 'fontsize', 9, 'HorizontalAlignment', 'left',...
    'position', [wall wall+3*txv+2*spv 2*txh txv],...
    'string', 'Ranging Information');
% Oxidizer Injector Inertance
s1.edit22 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+5*edv+5*spv edh edv],...
    'string', '0.00658');
s1.text22 = uicontrol ('style', 'text',...
    'position', [wall wall+5*txv+5*spv txh txv],...
    'string', 'Ox. Injector Inertance (lbf*s^2/lbm-in^2)');
% Oxidizer Injector Compliance
s1.edit23 = uicontrol ('style', 'edit',...
    'position', [wall+txh+sph wall+4*edv+4*spv edh edv],...
    'string', '0.0015');
s1.text23 = uicontrol ('style', 'text',...
    'position', [wall wall+4*txv+4*spv txh txv],...
    'string', 'Ox. Injector Compliance (lbm*in^2/lbf)');
% Fuel Injector Inertance
s1.edit24 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+4*sph+edh wall+5*edv+5*spv edh edv],...
    'string', '8.47e-5');
s1.text24 = uicontrol ('style', 'text',...
    'position', [wall+txh+3*sph+edh wall+5*txv+5*spv txh txv],...
    'string', 'Fuel Injector Inertance (lbf*s^2/lbm-in^2)');
% Fuel Injector Compliance
s1.edit25 = uicontrol ('style', 'edit',...
    'position', [wall+2*txh+4*sph+edh wall+4*edv+4*spv edh edv],...
    'string', '1.49e-5');
s1.text25 = uicontrol ('style', 'text',...
    'position', [wall+txh+3*sph+edh wall+4*txv+4*spv txh txv],...
    'string', 'Fuel Injector Compliance (lbm*in^2/lbf)');
% Label for Feed System Parameters
s1.textE = uicontrol ('style', 'text',...
    'fontweight', 'bold', 'fontsize', 9, 'HorizontalAlignment', 'left',...
    'position', [wall wall+6*txv+5*spv 1.5*txh txv],...
    'string', 'Feed System Parameters');
%%% This sets the GUI colors
% Set Background of text windows to be the figure color (Factory Default)
set(s1.text1,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text2,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text3,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text4,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text5,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text6,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text7,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text8,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text9,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text10,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text11,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text12,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text13,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text14,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text15,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text16,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text17,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text18,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text19,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text20,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text21,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text22,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text23,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text24,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.text25,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.textA,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.textB,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.textC,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.textD,'BackgroundColor',get(0,'defaultFigureColor'))
set(s1.textE,'BackgroundColor',get(0,'defaultFigureColor'))
% % Set background of edit windows to white
set(s1.edit1 ,'BackgroundColor','white');
set(s1.edit2 ,'BackgroundColor','white');
set(s1.edit3 ,'BackgroundColor','white');
set(s1.edit4 ,'BackgroundColor','white');
set(s1.edit5 ,'BackgroundColor','white');
set(s1.edit6 ,'BackgroundColor','white');
set(s1.edit7 ,'BackgroundColor','white');
set(s1.edit8 ,'BackgroundColor','white');
set(s1.edit9 ,'BackgroundColor','white');
set(s1.edit10 ,'BackgroundColor','white');
set(s1.edit11 ,'BackgroundColor','white');
set(s1.edit12 ,'BackgroundColor','white');
set(s1.edit13 ,'BackgroundColor','white');
set(s1.edit14 ,'BackgroundColor','white');
set(s1.edit15 ,'BackgroundColor','white');
set(s1.edit16 ,'BackgroundColor','white');
set(s1.edit17 ,'BackgroundColor','white');
set(s1.edit18 ,'BackgroundColor','white');
set(s1.edit19 ,'BackgroundColor','white');
set(s1.edit20 ,'BackgroundColor','white');
set(s1.edit21 ,'BackgroundColor','white');
set(s1.edit22 ,'BackgroundColor','white');
set(s1.edit23 ,'BackgroundColor','white');
set(s1.edit24 ,'BackgroundColor','white');
set(s1.edit25 ,'BackgroundColor','white');
%%% Create a button group Container Object containing the Radio Buttons
s1.cont = uibuttongroup('visible','off',...
'pos', [(4*sph+edh+txh)/figx (6.5*spv+6*txv)/figy ...
((figx-wall)-(4*sph+edh+txh))/figx txv/figy]);
% Create two radio buttons in button group (these are children of s1.cont)
h1 = uicontrol('Style','Radio',...
    'String','Feed Sys. Off',...
    'pos',[5 1 90 25],...
    'parent',s1.cont,'Tag','1');
h2 = uicontrol('Style','Radio',...
    'String','Feed Sys. On',...
    'pos',[110 1 90 25],...
    'parent',s1.cont,'Tag', '2');
% Initialize some button group properties.
set(s1.cont,'SelectionChangeFcn',{@selcbk,s1});
set(s1.cont,'SelectedObject',h2); % Initial Selection is Feed Sys. On
set(s1.cont,'Visible','on'); % Turns on Button Group Visibility
set(s1.cont,'BackgroundColor',get(0,'defaultFigureColor')); % default color
set(h1,'BackgroundColor',get(0,'defaultFigureColor')); % default color
set(h2,'BackgroundColor',get(0,'defaultFigureColor')); % default color
%%% Create 'Use Input File' button
s1.button1 = uicontrol ('style', 'pushbutton',...
    'position', [figx/4-1.5*edh/2 wall 1.5*edh edv],...
    'string', 'Use Input File');
% % 'Use Input File' button points to function 'inparams1'
set(s1.button1, 'callback', {@inparams1, s1});
%%% Create 'Execute' button, this has to be last so that all of s1 is passed
s1.button2 = uicontrol ('style', 'pushbutton',...
    'position', [3*figx/4-1.5*edh/2 wall 1.5*edh edv],...
    'string', 'Execute');
% % 'Go' Push Button points to the function 'inparams2'
set(s1.button2, 'callback', {@inparams2, s1});