% Computes temporal binding window (TBW) group analysis
%
% This script computes the temporal binding window (TBW) for a group in a
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
% Syntax:  tbw_group(subj, threshold, hoi)
%
% Input parameters:
%    subj       - subject parameter computed from twb_subj.m script
%    threshold  - TBW of each subject must exceed this threshold so that
%                 subject is considered in the group analysis
%    hoi        - (optional) Hight of interest to compute TBW (default 50%)
%
% Examples:
% >> tbw_group(subj)
% >> tbw_group(subj, 0, 0.5)
% >> subj=tbw_subj('dataset.xlsx'); tbw_group(subj)
%
% See also: glmfit, glmval

% Author:   Michael Notter
% History:  25.05.2017  file created

function [group] = tbw_group(subj, threshold)

% Set input parameters
if ~exist('threshold','var')
    threshold = 0;      % Threshold of minimum TBW to include subject
end
if ~exist('hoi','var')
    hoi = 0.5;          % Hight of interest (hoi) to compute TBW
end

nSubj = length(subj);
nCate = length(subj(1).categ);

% Read data from subj parameter if TBW is above threshold
bind_AV = cell(nCate, 1);
bind_VA = cell(nCate, 1);
temp_bind_window = cell(nCate, 1);
temp_bind_curve = cell(nCate, 1);
subj_used = 0;
for s=1:nSubj

    % Drop subject if smalles TBW is below threshold
    if min([subj(s).categ.temp_bind_window]) > threshold

        for c=1:nCate

            bind_AV{c} = [bind_AV{c} subj(s).categ(c).bind_AV];
            bind_VA{c} = [bind_VA{c} subj(s).categ(c).bind_VA];
            temp_bind_window{c} = [temp_bind_window{c} subj(s).categ(c).temp_bind_window];
            temp_bind_curve{c} = [temp_bind_curve{c} subj(s).categ(c).temp_bind_curve];

        end
        subj_used = subj_used + 1;
    end
end

% Compute temporal binding window plot for each category
for c=1:nCate

    % Get relevant Data
    x = -1 * bind_AV{c}';
    y = bind_VA{c}';

    % Compute correlation statistic
    [r p] = corr(x,y);

    % Plot Figure
    figure;
    set(gcf,'Renderer','OpenGL');
    plot(x, y, 'x')
    if c==nCate
        category = 'all';
    else
        category = num2str(c);
    end
    title(['Temporal Binding Window for Category: ', category]);
    xlabel(sprintf('Left\nTemporal Binding Window [ms]'));
    ylabel(sprintf('Right\nTemporal Binding Window [ms]'));

    xlimits = get(gca,'xlim');
    ylimits = get(gca,'ylim');
    text(xlimits(1)*1.1, ylimits(2)*0.95,['r = ' num2str(r)], ...
        'HorizontalAlignment','left', 'FontName', 'FixedWidth');
    text(xlimits(1)*1.1, ylimits(2)*0.90,['p = ' num2str(p)], ...
        'HorizontalAlignment','left', 'FontName', 'FixedWidth');
    text(xlimits(1)*1.1, ylimits(2)*0.85,['n = ' num2str(subj_used)], ...
        'HorizontalAlignment','left', 'FontName', 'FixedWidth');
    lsline

    % Plot value and p-value of mean-TBW
    [h,ptest] = ttest(temp_bind_window{c}, 0, 0.05, 'right');
    txt_meanTBW = sprintf(['Mean TBW: ', num2str(mean(temp_bind_window{c})), ...
        '\np-value:  ', num2str(ptest)]);
    text(xlimits(1)*1.1, ylimits(2)*0.25, txt_meanTBW, ...
        'HorizontalAlignment','left', 'FontName', 'FixedWidth');

    pbaspect([1.2 1 1])
    print(sprintf('result_TBW_categ%.2d', c),'-dpng')
    close()

end

% Compute mean temporal binding curve for each category
x_line = subj(1).x_line;
for c=1:nCate

    % Get curves
    x_curves = temp_bind_curve{c};

    % Plot Figure
    figure;
    set(gcf,'Renderer','OpenGL');
    shadedErrorBar(x_line, x_curves', {@mean, @(x_curves) std(x_curves)}, ...
        {'-k', 'LineWidth', 2}, 0);
    if c==nCate
        category = 'all';
    else
        category = num2str(c);
    end
    title(['Mean Temporal Binding Window for Category: ', category]);
    xlabel(sprintf('Stimulus Onset Asynchrony [ms]\n(from AV to VA)'));
    ylabel('%-Perceived Synchronous');
    ylim([0 1]);

    hold on
    % Plot hight of interest
    xlimits = get(gca,'xlim');
    plot(xlimits, [hoi hoi], '--', 'Color',[0.5,0.5,0.5]);

    % Find TBW of average curve
    tbw_diff = abs(mean(x_curves,2) - hoi);
    minima_id = find(imregionalmin(tbw_diff));
    minima_val = x_line(minima_id);
    plot([minima_val(1), minima_val(1)], [0, hoi], '-', 'Color',[0, 0, 0]);
    plot([minima_val(end), minima_val(end)], [0, hoi], '-', 'Color',[0, 0, 0]);
    text(minima_val(1) * 0.9, 0.25, num2str(minima_val(1)), ...
        'HorizontalAlignment','left');
    text(minima_val(end) * 0.9, 0.25, num2str(minima_val(end)), ...
        'HorizontalAlignment','right');
    hold off

    pbaspect([1.2 1 1])
    print(sprintf('result_TBC_categ%.2d', c),'-dpng')
    close()

end
