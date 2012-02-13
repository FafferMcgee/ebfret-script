function [FRET raw labels orig idxs] = load_traces(data_files, varargin)
% Loads traces from a number of data files into a single dataset.
%
% Data must be formatted as a matrix with T rows (time points) and
% 2N columns (donor/acceptor signal for each trace). Donor signals
% are assumed to be located on odd columns (:,1:2:end-1), whereas
% acceptor signals are on even columns (:,2:2:end). 
%
%
% Inputs
% ------
%
% data_files (1xD cell)
%   Names of datasets to analyse (e.g. {'file1.dat' 'file2.dat'}). 
%   Datasets are T x 2N, with the donor signal on odd columns
%   and acceptor signal on even columns.
%
%   TODO: Modify this function to deal with other inputs
%   (e.g. vbFRET saved sessions)
%   
%
% Variable Inputs
% ---------------
%
% 'HasLabels' (boolean, default:true)
%   Assume first row contains trace labels
%
% 'RemoveBleaching' (boolean, default:true)
%   Remove photobleaching from traces
%
% 'MinLength' (integer, default:0)
%   Minimum length of traces 
%
% 'MaxOutliers' (integer, default:inf)
%	Reject trace if it contains more than a certain number of points
%   which are outside of ClipRange
%
% 'ClipRange' ([min, max], default: [-0.2, 1.2])
%   Defines lower and upper limits of valid range. Points outside
%   this range are considered outliers.
%
% 'BlackList' (array of indices, default:[])
%   Array of trace indices to throw out (e.g. because they contain a
%   photoblinking event or other anomaly)   
%
% 'ShowProgress' (boolean, default:false)
%   Display messages to indicate loading progress 
%   (for large datasets where photobleaching removal takes long time)
%
%
% Outputs
% -------
%
% FRET (1xN cell)
%   FRET signals (Tx1 == acceptor / (donor + acceptor)) 
%
% raw (1xN cell)
%   Raw 2D donor/acceptor signals (Tx2)
%
% labels (1xN int)
%   Index of each trace
%
% orig (1xN cell)
%   Raw 2D signals without removal of photobleaching
%   or blacklisted/short traces
%
% idxs (1xN int)
%	Indices of accepted traces
%
% Jan-Willem van de Meent
% $Revision: 1.00 $  $Date: 2011/05/04$

% parse variable arguments
HasLabels = true;
RemoveBleaching = false;
MinLength = 0;
MaxOutliers = inf;
BlackList = [];
ShowProgress = false;
ClipRange = [-0.2, 1.2];
for i = 1:length(varargin)
    if isstr(varargin{i})
        switch lower(varargin{i})
        case {'haslabels'}
            HasLabels = varargin{i+1};
        case {'removebleaching'}
            RemoveBleaching = varargin{i+1};
        case {'minlength'}
            MinLength = varargin{i+1};
        case {'maxoutliers'}
            MaxOutliers = varargin{i+1};
        case {'cliprange'}
            ClipRange = sort(varargin{i+1});
        case {'blacklist'}
            BlackList = varargin{i+1};
        case {'showprogress'}
            ShowProgress = varargin{i+1};
        end
    end
end 

FRET = {};
raw = {};
orig = {};
labels = {};
for d = 1:length(data_files)
    if ShowProgress
        disp(sprintf('Loading Dataset: %s', data_files{d}));
    end

    % load dataset
    dat = load(data_files{d});
    
    % strip labels if necessary
    if HasLabels
        labelsd = num2cell(dat(1, 1:2:end));
        dat = dat(2:end, :);
    end

    % strip first point (usually bad data)
    dat = dat(2:end, :);

    % convert to cell array
    origd = mat2cell(dat, size(dat,1), 2 * ones(size(dat,2) / 2, 1));

    % mask out bad traces
    mask = ones(length(origd),1);
    mask(BlackList) = 0;

	
    % construct FRET signal and remove photobleaching
    FRETd = cell(1, length(origd));
    rawd = cell(1, length(origd));
	idxs = [];
    for n = 1:length(origd)
        if mask(n)
            if ShowProgress
                disp(sprintf('   processing trace: %d', n));
            end

            % every 1st column is assumed to contain donor signal,
            % whereas every 2nd column is assumed to contain acceptor
            don = origd{n}(:, 1);
            acc = origd{n}(:, 2);
            fret = acc ./ (don + acc);
   
   			% clip outlier points 
            fret(fret<ClipRange(1)) = ClipRange(1);
            fret(fret>ClipRange(2)) = ClipRange(2);

            if RemoveBleaching
                % find photobleaching point in donor and acceptor
                id = photobleach_index(don);
                ia = photobleach_index(acc);
            else
                id = length(don);
                ia = length(acc);
            end
            
            % sanity check: donor bleaching should result in acceptor bleaching
            % but we'll allow a few time points tolerance
			tol = 5;
            if (ia < (id + tol)) & (min(id,ia) >= MinLength)
				rng = 1:min(id,ia);
				outliers = sum((fret(rng)<=ClipRange(1)) | (fret(rng)>=ClipRange(2)));
				if (outliers <= MaxOutliers)
                	% keep stripped signal
                	FRETd{n} = fret(1:min(id,ia));
                	rawd{n} = [don(1:min(id,ia)) acc(1:min(id,ia))];
					idxs(end+1) = n;
			    elseif ShowProgress
                	disp(sprintf('   rejecting trace (too many outlier points): %d', n));
				end
            end
        else
            if ShowProgress
                disp(sprintf('   skipping trace: %d', n));
            end
        end
    end

    FRET = {FRET{:} FRETd{~cellfun(@isempty, FRETd)}};
    raw = {raw{:},  rawd{~cellfun(@isempty, rawd)}};
    orig = {orig{:}, origd{:}};
    labels = {labels{:}, labelsd{:}};
    clear dat;
end