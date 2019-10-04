% eegplugin_erpsource() - Plugin to perform ERP source reconstruction. This
%                         function is called by EEGLAB at startup to create
%                         a menu.
%
% Usage:
%   >> eegplugin_roiconnect(fig, trystrs, catchstrs);
%
% Inputs:
%   fig        - [integer] eeglab figure.
%   trystrs    - [struct] "try" strings for menu callbacks.
%   catchstrs  - [struct] "catch" strings for menu callbacks.
%
% Authors: Arnaud Delorme and Robert Oostenveld
%
% The web page https://sccn.ucsd.edu/wiki/plugins contain information
% on how to structure this function

function vers = eegplugin_erpsource(fig, trystrs, catchstrs)

vers = 'erpsource1.0'; % write the name of your plugin here and version
if nargin < 3
    error('eegplugin_roiconnect requires 3 arguments');
end

% find DIPFIT menu handle
dipfit_m = findobj(fig, 'tag', 'dipfit'); % find by tag
if isempty(dipfit_m)
    % find by label for older versions of DIPFIT
    dipfit_m = findobj(fig, 'label', 'Locate dipoles using DIPFIT');
end

% we create the menu below
cb = [ 'try, LASTCOM = pop_erpsource(EEG);' catchstrs.add_to_hist  ]; 
roi_m = uimenu( dipfit_m, 'label', 'Source reconstruction of ERP', ...
                'CallBack', cb, 'separator', 'on');


