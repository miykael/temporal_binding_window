% Computes temporal binding window (TBW) for each subjects in a given dataset
%
% This script computes the temporal binding window (TBW) for each subjects in a
% multisensory integration study. The computed output will look like the ones
% from:
%     Stevenson, R. A., Zemtsov, R. K., & Wallace, M. T. (2012). Individual
%     differences in the multisensory temporal binding window predict
%     susceptibility to audiovisual illusions. Journal of Experimental
%     Psychology: Human Perception and Performance, 38(6), 1517.
%     http://dx.doi.org/10.1037/a0027339
%
% But in contrast to their approach, the following two changes were done:
%     First, this script splits the subject data into two equally big parts to
%         create the AV and VA condition.
%     Second, the resulting temporal binding window curve (the curve that
%         combines the two sigmoid functions, was not resized to reach 100%.
%
% For more information about this script see:
%     https://github.com/miykael/temporal_binding_window
%
% Syntax:  [subj] = tbw_subj(xlsxfile, hoi, x_bound)
%
% Input parameters:
%    xlsxfile - Path to the xlsxfile containing subject information such as
%               subject_ids, category_id, offsets & simultaneity information
%    hoi      - (optional) Hight of interest to compute TBW (default 50%)
%    x_bound  - (optional) Range between which to compute TBW (default -+750ms)
%
% Output parameters:
%    subj     - This output variable contains the b-values and the binding
%               points for the AV and VA side of the TBW-curve, the TBW point
%               and the temporal bind curve for each category for each subject.
%
% Examples:
% >> tbw_subj('dataset.xlsx')
% >> tbw_subj('dataset.xlsx', 0.5, 750)
%
% See also: glmfit, glmval

% Author:   Michael Notter
% History:  25.05.2017  file created

function [subj] = tbw_subj(xlsxfile, hoi, x_bound)

% Set input parameters
sampling_rate = 0.1;    % sampling rate for TBW-curve
if ~exist('hoi','var')
    hoi = 0.5;          % Hight of interest (hoi) to compute TBW
end
if ~exist('x_bound','var')
    x_bound = 750;      % Left and Right bound in ms for the estimation of TBW
end

% Read data from xlsx-file
data = xlsread(xlsxfile, 1);
subj_list = data(:, 1);      % Array indicating subject number
categ = data(:, 2);          % Array indicating category number
offset = data(:, 3);         % Array indicating stimuli offset (x-axis)
simultaneity = data(:, 4);   % Array indicating stimuli percept, 0 or 1 (y-axis)

% Run computation for each subject separately
subjects = unique(subj_list)';
for s = subjects

    % Extract data of current subject
    s_id = subj_list==s;
    sOffset = offset(s_id);
    sSimultaneity = simultaneity(s_id);
    sCateg = categ(s_id);

    % Run computation for each category separately, and add an additional
    %   category that includes all elements of a category
    categories = [unique(sCateg)', max(sCateg) + 1];
    for c = categories

        % Select elements of current category
        if c == max(sCateg) + 1
            selector = true(length(sCateg), 1);
        else
            selector = sCateg==c;
        end
        cOffset = sOffset(selector);
        cSimultaneity = sSimultaneity(selector);

        % Sort everything by offset
        [cOffset, sort_id] = sort(cOffset);
        cSimultaneity = cSimultaneity(sort_id);

        % Execute glmfit for AV and VA condition (split offset in middle)
        split = ceil(length(cOffset) / 2);
        [b_AV, dev_AV, stats_AV] = glmfit(cOffset(1:split), ...
            cSimultaneity(1:split), 'binomial', 'link', 'logit');
        [b_VA, dev_VA, stats_VA] = glmfit(cOffset(split+1:length(cOffset)), ...
            cSimultaneity(split+1:length(cOffset)), 'binomial', 'link', 'logit');

        % Sampling points for TBW curve
        x_line = [-x_bound:sampling_rate:x_bound]';

        % Fit sigmoid function to estimated data
        y_AV = glmval(b_AV, x_line, 'logit');
        y_VA = glmval(b_VA, x_line, 'logit');

        % Estimate temporal binding window at hight of interest
        [minimum_AV, min_AV_id] = min(abs(y_AV - hoi));
        bind_AV = x_line(min_AV_id);

        [minimum_VA, min_VA_id] = min(abs(y_VA - hoi));
        bind_VA = x_line(min_VA_id);

        temp_bind_window = -1 * bind_AV + bind_VA;

        % Compute temporal binding curve
        cut_id = find(y_AV > y_VA, 1);
        temp_bind_curve = [y_AV(1:cut_id) ; y_VA(cut_id+1:end)];

        % Store relevant values in subject variable for later use
        subj(s).categ(c).b_AV = b_AV;
        subj(s).categ(c).b_VA = b_VA;
        subj(s).categ(c).bind_AV = bind_AV;
        subj(s).categ(c).bind_VA = bind_VA;
        subj(s).categ(c).temp_bind_window = temp_bind_window;
        subj(s).categ(c).temp_bind_curve = temp_bind_curve;
    end
    subj(s).x_line = x_line;

    % Create overwiev plot for given subject
    figure;
    set(gcf,'Renderer','OpenGL');
    plot(x_line, [subj(s).categ.temp_bind_curve]);
    title(['Subject: ', num2str(s)]);
    xlabel(sprintf('Stimulus Onset Asynchrony [ms]\n(from AV to VA)'));
    ylabel('%-Perceived Synchronous');
    txt_legend = [sprintf(repmat('cat_%d ',1,length(categories)-1), ...
        categories(1:end-1)), 'all'];
    fig_legend = strsplit(txt_legend);
    legend(fig_legend);
    ylim([0 1]);

    hold on
    % Plot hight of interest
    xlimits = get(gca,'xlim');
    plot(xlimits, [hoi hoi], '--', 'Color',[0.5,0.5,0.5]);
    hold off

    % Plot information about binding points in figure
    txt_AV = sprintf(['AV: ', repmat('%5d',1,length(categories))], ...
        round([subj(s).categ.bind_AV]));
    txt_VA = sprintf(['VA: ', repmat('%5d',1,length(categories))], ...
        round([subj(s).categ.bind_VA]));
    txt_TBW = sprintf(['TBW:', repmat('%5d',1,length(categories))], ...
        round([subj(s).categ.temp_bind_window]));
    text(xlimits(1) * 0.9, 0.95,['      ', txt_legend], ...
        'HorizontalAlignment','left', 'FontName', 'FixedWidth');
    text(xlimits(1) * 0.9, 0.90,txt_AV, ...
        'HorizontalAlignment','left', 'FontName', 'FixedWidth');
    text(xlimits(1) * 0.9, 0.85,txt_VA, ...
        'HorizontalAlignment','left', 'FontName', 'FixedWidth');
    text(xlimits(1) * 0.9, 0.80,txt_TBW, ...
        'HorizontalAlignment','left', 'FontName', 'FixedWidth');

    % Save Figure
    pbaspect([1.2 1 1])
    print(sprintf('result_sub%.2d', s),'-dpng')
    close()

end
