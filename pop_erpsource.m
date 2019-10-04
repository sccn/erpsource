% pop_erpsource - perform source reconstruction of ERPs with Fieldtrip. This 
%                 plugin was designed in a minimalist fashion so it could 
%                 be used as template for other similar plugins and
%                 contains extensive comments.
% Usage:
%  pop_erpsource(EEG); % pop up window asking users to select method
%  pop_erpsource(EEG, 'key', 'val', ...); % does not pop up a window
%
% Inputs:
%  EEG - EEGLAB dataset where a head model has been selected
% 
% Optional inputs:
%  'method'   - ['eloreta'|'mne'] source reconstruction method. See
%               ft_sourceanalysis for more details.
%
% Output:
%  This function does not return any output expect a string to be added
%  to EEGLAB history. This output is usually not listed. You may also return
%  a modified EEG structure with some custom fields added if you want to
%  retain information. Usually the string for history is always the last 
%  output parameter. Returning history is optional although it is
%  convinient for users.
%
% Author: Arnaud Delorme and Robert Oostenveld. It is usually a good idea to indicate
%         who contributed to the function and any reference to publication.
%
% Example:
%   % Examples are already useful for users
%   pop_erpsource(EEG); % pop up window asking users to select method
%   pop_erpsource(EEG, 'method', 'eloreta'); % does not pop up a window

% It is always a good idea to add a licence to the file you distribute.
% Below is an example of license term (BSD). Note that since Fieldtrip is
% GNU/GPL, users who use your plugin will be under the most restrictive
% license (GNU/GPL) although this does not prevent you from releasing 
% your code using another license.

% Copyright (C) 2019 Arnaud Delorme
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
% 1. Redistributions of source code must retain the above copyright notice,
% this list of conditions and the following disclaimer.
%
% 2. Redistributions in binary form must reproduce the above copyright notice,
% this list of conditions and the following disclaimer in the documentation
% and/or other materials provided with the distribution.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
% THE POSSIBILITY OF SUCH DAMAGE.

function com = pop_erpsource(EEG, varargin)

com = '';
if nargin < 1
    help pop_sourcereconstruction;
    return
end

% list of source reconstruction methods
methodsLong  = { 'eloreta' 'minimum norm estimate' };
methodsShort = { 'eloreta' 'mne' };

% check that head model is present if not return an error
if ~isfield(EEG.dipfit, 'coordformat') || ~strcmpi(EEG.dipfit.coordformat, 'MNI')
    errorMsg = 'You need to select a DIPFIT head model in MNI space first';
    if nargin < 2
        % pop up a window in case the function is called from the menu
        warndlg2(errorMsg, 'Select head model first');
        return
    else
        % otherwise just return an error
        error(errorMsg);
    end
end

% if only one argument is provided, this means that the 
% function is being called from an EEGLAB menu
if nargin < 2
    % allow user to select the type of source reconstruction method
    % below is the standard EEGLAB function to automatically build GUI
    % where you provide the list of uicontrols and a simplified geometry
    uilist = { { 'style' 'text' 'string' 'Source localization method' 'fontweight' 'bold'} ...
               { 'style' 'popupmenu' 'string' methodsLong } };
    res = inputgui('geometry', { [1 1] }, 'uilist', uilist, 'helpcom', 'pophelp(''pop_sourcereconstruction'')', ...
                                        'title', 'Source reconstruction using Fieldtrip');
    if isempty(res), return, end

    % create a cell array containing options
    % using output returned by the function above
    options = { 'method' methodsShort{res{1}} };
    if strcmpi(options{2}, 'mne')
        options = { options{:} 'lambda' 3 'scalesourcecov' 'yes' };
    end
else 
    % in case of more than one argument, use as options
    options = varargin;
end

% below is the standard way to check parameters in EEGLAB
% check other EEGLAB functions contain for a more comprehensive
% example with multiple optional inputs. Note that the 'ignore'
% option allows you to ignore some parameters (returned in ignredOpts)
% which can then be decoded or used by your custom functions.
% If this function is not being used, the function will return an
% error if an unknown parameters is being provided as input.
[opt, ignredOpts] = finputcheck(options, { 'method' 'string' methodsShort methodsShort{1} }, 'pop_sourcereconstruction', 'ignore');
if ischar(opt), error(opt); end

% convert the EEG data structure to fieldtrip. This includes transformation
% of the channel location to the head model space.
dataPre = eeglab2fieldtrip(EEG, 'preprocessing', 'dipfit');  

% The code below is described in detail on this web page
% https://sccn.ucsd.edu/wiki/A08:_DIPFIT#Advanced_source_reconstruction_using_DIPFIT.2FFieldtrip
cfg = [];
cfg.channel = {'all', '-EOG1'};
cfg.reref = 'yes';
cfg.refchannel = {'all', '-EOG1'};
dataPre = ft_preprocessing(cfg, dataPre);
 
% load head model and prepare leadfield matrix
vol = load('-mat', EEG.dipfit.hdmfile);
 
cfg            = [];
cfg.elec       = dataPre.elec;
cfg.headmodel  = vol.vol;
cfg.resolution = 10;   % use a 3-D grid with a 1 cm resolution
cfg.unit       = 'mm';
cfg.channel    = { 'all' };
[sourcemodel] = ft_prepare_leadfield(cfg);

% Compute an ERP in Fieldtrip. Note that the covariance matrix needs to be calculated here for use in source estimation.
cfg                  = [];
cfg.covariance       = 'yes';
cfg.covariancewindow = [EEG.xmin 0]; % calculate the average of the covariance matrices 
                                     % for each trial (but using the pre-event baseline  data only)
dataAvg = ft_timelockanalysis(cfg, dataPre);
 
% source reconstruction
cfg             = [];
cfg.method      = opt.method;
cfg.(opt.method) = struct(ignredOpts{:});
cfg.sourcemodel = sourcemodel;
cfg.headmodel   = vol.vol;
source          = ft_sourceanalysis(cfg, dataAvg);  % compute the source

% plot solution
cfg = [];
cfg.projectmom = 'yes';
cfg.flipori = 'yes';
sourceProj = ft_sourcedescriptives(cfg, source);
 
cfg = [];
cfg.parameter = 'mom';
cfg.operation = 'abs';
sourceProj = ft_math(cfg, sourceProj);
 
cfg              = [];
cfg.method       = 'ortho';
cfg.funparameter = 'mom';
ft_sourceplot(cfg, sourceProj);
fprintf('\nClick on cortical volume and ERP to select different locations/latencies\n');

% This is the standard way to write EEGLAB history. The vararg2str function 
% takes care to convert your option cell array to a string
if nargout > 0
    com = sprintf( 'pop_erpsource(EEG, %s);', vararg2str( options ));
end