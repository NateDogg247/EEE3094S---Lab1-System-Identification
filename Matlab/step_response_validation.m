%% ============================================================
% EEE3094S LAB 1
% SYSTEM IDENTIFICATION - STEP RESPONSE
%
% Student: Junaid Pieters
%
% This script:
% 1. Finds the experimental step-test CSV automatically
% 2. Reads the raw laboratory data
% 3. Detects the step input
% 4. Calculates the DC gain
% 5. Calculates percentage overshoot
% 6. Estimates damping ratio
% 7. Estimates damped and natural frequency
% 8. Determines the complex poles
% 9. Forms the second-order transfer function
% 10. Simulates the identified model
% 11. Compares the model with the measured laboratory response
% 12. Saves publication-quality figures
%
% Requires:
% MATLAB Control System Toolbox
%% ============================================================

clc;
clear;
close all;

%% ============================================================
% 1. FIND REPOSITORY AND DATA FILE
%% ============================================================

% Folder containing this MATLAB script
matlabFolder = fileparts(mfilename('fullpath'));

% Parent of the matlab folder
repoFolder = fileparts(matlabFolder);

fprintf('\n=============================================\n');
fprintf('EEE3094S LAB 1 - STEP RESPONSE ANALYSIS\n');
fprintf('=============================================\n\n');

fprintf('MATLAB script folder:\n%s\n\n', matlabFolder);
fprintf('Repository folder:\n%s\n\n', repoFolder);


%% ------------------------------------------------------------
% Expected location
%% ------------------------------------------------------------

expectedFolder = fullfile( ...
    repoFolder, ...
    'data', ...
    'step_test');

expectedFile = fullfile( ...
    expectedFolder, ...
    'F34BSuspensionTestData.CSV');


%% ------------------------------------------------------------
% Try exact expected filename first
%% ------------------------------------------------------------

if isfile(expectedFile)

    dataFile = expectedFile;

else

    fprintf('Exact expected file was not found.\n');
    fprintf('Searching repository automatically...\n\n');

    %% Search expected step_test folder first

    filesUpper = dir(fullfile(expectedFolder, '*.CSV'));
    filesLower = dir(fullfile(expectedFolder, '*.csv'));

    stepFiles = [filesUpper; filesLower];

    %% If not found, search entire repository recursively

    if isempty(stepFiles)

        filesUpper = dir(fullfile( ...
            repoFolder, ...
            '**', ...
            'F34BSuspensionTestData*.CSV'));

        filesLower = dir(fullfile( ...
            repoFolder, ...
            '**', ...
            'F34BSuspensionTestData*.csv'));

        stepFiles = [filesUpper; filesLower];

    end

    %% If still not found, search for ANY CSV recursively

    if isempty(stepFiles)

        fprintf('Named step-test CSV was not found.\n');
        fprintf('Searching for any CSV files...\n\n');

        filesUpper = dir(fullfile(repoFolder, '**', '*.CSV'));
        filesLower = dir(fullfile(repoFolder, '**', '*.csv'));

        stepFiles = [filesUpper; filesLower];

    end

    %% Use file if exactly one suitable file was found

    if ~isempty(stepFiles)

        fprintf('CSV file(s) found:\n');

        for k = 1:length(stepFiles)

            fprintf('%d. %s\n', ...
                k, ...
                fullfile(stepFiles(k).folder, ...
                stepFiles(k).name));

        end

        % Prefer a file containing F34BSuspensionTestData
        selectedIndex = [];

        for k = 1:length(stepFiles)

            if contains( ...
                    lower(stepFiles(k).name), ...
                    'f34bsuspensiontestdata')

                selectedIndex = k;
                break;

            end

        end

        if isempty(selectedIndex)
            selectedIndex = 1;
        end

        dataFile = fullfile( ...
            stepFiles(selectedIndex).folder, ...
            stepFiles(selectedIndex).name);

    else

        %% Manual selection if automatic search fails

        fprintf('\n');
        fprintf('MATLAB could not locate the CSV automatically.\n');
        fprintf('Please select the STEP TEST CSV manually.\n\n');

        [fileName, filePath] = uigetfile( ...
            {'*.CSV;*.csv', ...
            'CSV Files (*.CSV, *.csv)'}, ...
            'Select the Step Test CSV File', ...
            repoFolder);

        if isequal(fileName, 0)

            error(['No CSV file was selected. ' ...
                   'The program has stopped.']);

        end

        dataFile = fullfile(filePath, fileName);

    end

end


%% ------------------------------------------------------------
% Confirm selected data file
%% ------------------------------------------------------------

fprintf('\nUsing step-test data file:\n');
fprintf('%s\n\n', dataFile);

if ~isfile(dataFile)

    error('The selected CSV file does not exist.');

end


%% ============================================================
% 2. READ RAW EXPERIMENTAL DATA
%% ============================================================

try

    % Preserve original column headings such as Time(s)
    data = readtable( ...
        dataFile, ...
        'VariableNamingRule', ...
        'preserve');

catch

    % Compatibility with older MATLAB versions
    data = readtable(dataFile);

end


%% ------------------------------------------------------------
% Display column names
%% ------------------------------------------------------------

fprintf('Columns found in CSV:\n');

disp(data.Properties.VariableNames);


%% ------------------------------------------------------------
% Identify columns robustly
%% ------------------------------------------------------------

variableNames = data.Properties.VariableNames;

normalizedNames = lower( ...
    regexprep(variableNames, '[^a-zA-Z0-9]', ''));


% Time column
timeIndex = find( ...
    contains(normalizedNames, 'time'), ...
    1);


% Input column
inputIndex = find( ...
    strcmp(normalizedNames, 'input') | ...
    contains(normalizedNames, 'input'), ...
    1);


% Output displacement column
outputIndex = find( ...
    contains(normalizedNames, 'outputdisplacement'), ...
    1);

if isempty(outputIndex)

    outputIndex = find( ...
        contains(normalizedNames, 'output'), ...
        1);

end


%% ------------------------------------------------------------
% Check required columns
%% ------------------------------------------------------------

if isempty(timeIndex)
    error('Could not identify the Time column.');
end

if isempty(inputIndex)
    error('Could not identify the Input column.');
end

if isempty(outputIndex)
    error('Could not identify the Output_Displacement column.');
end


%% ------------------------------------------------------------
% Extract numerical arrays
%% ------------------------------------------------------------

t = data{:, timeIndex};
u = data{:, inputIndex};
y = data{:, outputIndex};


% Ensure column vectors
t = t(:);
u = u(:);
y = y(:);


%% ------------------------------------------------------------
% Remove rows containing invalid values
%% ------------------------------------------------------------

validRows = ...
    isfinite(t) & ...
    isfinite(u) & ...
    isfinite(y);

t = t(validRows);
u = u(validRows);
y = y(validRows);


%% ============================================================
% 3. DETECT STEP INPUT
%% ============================================================

inputChange = abs(diff(u));

stepIndex = find( ...
    inputChange > 1e-6, ...
    1, ...
    'first') + 1;

if isempty(stepIndex)

    error(['No step change could be detected ' ...
           'in the input data.']);

end


%% ------------------------------------------------------------
% Step time
%% ------------------------------------------------------------

stepTime = t(stepIndex);


%% ------------------------------------------------------------
% Initial input
%% ------------------------------------------------------------

uInitial = u(stepIndex - 1);


%% ------------------------------------------------------------
% Final input
%% ------------------------------------------------------------

numberFinalSamples = min(100, length(u));

uFinal = median( ...
    u(end-numberFinalSamples+1:end));


%% ------------------------------------------------------------
% Input step size
%% ------------------------------------------------------------

deltaU = uFinal - uInitial;

if abs(deltaU) < 1e-9

    error('Calculated step amplitude is zero.');

end


%% ============================================================
% 4. INITIAL AND STEADY-STATE DISPLACEMENT
%% ============================================================

numberInitialSamples = min( ...
    50, ...
    stepIndex - 1);

initialStartIndex = ...
    stepIndex - numberInitialSamples;


%% ------------------------------------------------------------
% Initial displacement
%% ------------------------------------------------------------

yInitial = mean( ...
    y(initialStartIndex:stepIndex-1));


%% ------------------------------------------------------------
% Final steady-state displacement
%% ------------------------------------------------------------

numberFinalSamples = min( ...
    100, ...
    length(y));

ySS = median( ...
    y(end-numberFinalSamples+1:end));


%% ------------------------------------------------------------
% Output change
%% ------------------------------------------------------------

deltaY = ySS - yInitial;


%% ============================================================
% 5. DC GAIN
%% ============================================================

K = deltaY / deltaU;


%% ============================================================
% 6. SHIFT TIME AXIS
%% ============================================================

% Step occurs at relative t = 0
tRelative = t - stepTime;

% Displacement relative to initial value
yRelative = y - yInitial;


%% ============================================================
% 7. FIND FIRST PEAK
%% ============================================================

% Search for peak during first 10 seconds after step
peakRegion = find( ...
    tRelative >= 0 & ...
    tRelative <= 10);

if isempty(peakRegion)

    error('No data available after the step input.');

end


[yPeak, localPeakIndex] = ...
    max(y(peakRegion));

peakIndex = ...
    peakRegion(localPeakIndex);

peakTimeAbsolute = ...
    t(peakIndex);

peakTimeRelative = ...
    tRelative(peakIndex);


%% ------------------------------------------------------------
% Peak output change
%% ------------------------------------------------------------

deltaYPeak = ...
    yPeak - yInitial;


%% ============================================================
% 8. PERCENTAGE OVERSHOOT
%% ============================================================

overshootAmount = ...
    yPeak - ySS;

Mp = ...
    overshootAmount / deltaY;

percentOvershoot = ...
    100 * Mp;


%% ============================================================
% 9. DAMPING RATIO
%% ============================================================

if Mp > 0 && Mp < 1

    zeta = ...
        -log(Mp) / ...
        sqrt(pi^2 + log(Mp)^2);

else

    error(['A valid positive overshoot was not found. ' ...
           'Damping ratio cannot be calculated ' ...
           'using the overshoot formula.']);

end


%% ============================================================
% 10. DAMPED NATURAL FREQUENCY
%% ============================================================

Tp = peakTimeRelative;

omegaD = pi / Tp;


%% ============================================================
% 11. NATURAL FREQUENCY
%% ============================================================

omegaN = ...
    omegaD / ...
    sqrt(1 - zeta^2);


%% ============================================================
% 12. SECOND-ORDER TRANSFER FUNCTION
%% ============================================================

% Standard second-order form:
%
%                  K*wn^2
% G(s) = -----------------------------
%         s^2 + 2*zeta*wn*s + wn^2


numerator = ...
    K * omegaN^2;

denS = ...
    2 * zeta * omegaN;

denConstant = ...
    omegaN^2;


Gstep = tf( ...
    numerator, ...
    [1 denS denConstant]);


%% ============================================================
% 13. CALCULATE POLES
%% ============================================================

systemPoles = ...
    pole(Gstep);


%% ============================================================
% 14. ESTIMATE CORNER FREQUENCY
%% ============================================================

% For this second-order complex pole pair,
% use natural frequency as approximate corner region.

omegaCorner = omegaN;

frequencyHz = ...
    omegaCorner / (2*pi);


%% ============================================================
% 15. 2% SETTLING TIME FROM EXPERIMENTAL DATA
%% ============================================================

postStepMask = ...
    tRelative >= 0;

postTime = ...
    tRelative(postStepMask);

postOutput = ...
    y(postStepMask);


settlingBand = ...
    0.02 * abs(deltaY);

settlingTime = NaN;


for k = 1:length(postOutput)

    remainingError = ...
        abs(postOutput(k:end) - ySS);

    if all(remainingError <= settlingBand)

        settlingTime = postTime(k);
        break;

    end

end


%% ============================================================
% 16. PRINT RESULTS
%% ============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('STEP TEST MEASUREMENTS\n');
fprintf('=============================================\n\n');

fprintf('Step applied at                = %.3f s\n', ...
    stepTime);

fprintf('Initial input                  = %.3f\n', ...
    uInitial);

fprintf('Final input                    = %.3f\n', ...
    uFinal);

fprintf('Input change                   = %.3f\n', ...
    deltaU);

fprintf('\n');

fprintf('Initial displacement           = %.3f\n', ...
    yInitial);

fprintf('Steady-state displacement      = %.3f\n', ...
    ySS);

fprintf('Steady-state output change     = %.3f\n', ...
    deltaY);

fprintf('Peak displacement              = %.3f\n', ...
    yPeak);

fprintf('Peak time (absolute)           = %.3f s\n', ...
    peakTimeAbsolute);

fprintf('Peak time after step           = %.3f s\n', ...
    Tp);


fprintf('\n');
fprintf('=============================================\n');
fprintf('SYSTEM IDENTIFICATION RESULTS\n');
fprintf('=============================================\n\n');


fprintf('DC gain K                      = %.4f\n', ...
    K);

fprintf('Percentage overshoot           = %.3f %%\n', ...
    percentOvershoot);

fprintf('Damping ratio zeta             = %.4f\n', ...
    zeta);

fprintf('Damped frequency wd            = %.4f rad/s\n', ...
    omegaD);

fprintf('Natural frequency wn           = %.4f rad/s\n', ...
    omegaN);

fprintf('Approx. corner frequency       = %.4f rad/s\n', ...
    omegaCorner);

fprintf('Approx. corner frequency       = %.4f Hz\n', ...
    frequencyHz);


if ~isnan(settlingTime)

    fprintf('Experimental 2%% settling time  = %.3f s\n', ...
        settlingTime);

end


fprintf('\n');
fprintf('Transfer-function coefficients:\n');

fprintf('Numerator                      = %.4f\n', ...
    numerator);

fprintf('Coefficient of s               = %.4f\n', ...
    denS);

fprintf('Constant denominator term      = %.4f\n', ...
    denConstant);


fprintf('\nEstimated transfer function:\n\n');

Gstep


fprintf('System poles:\n\n');

disp(systemPoles);


%% ============================================================
% 17. MODEL RESPONSE TO ACTUAL LAB STEP
%% ============================================================

maximumModelTime = ...
    min(12, max(tRelative));

modelTime = ...
    (0:0.01:maximumModelTime)';


% The actual laboratory step had amplitude deltaU
modelInput = ...
    deltaU * ones(size(modelTime));


% Simulated change in displacement
modelChange = ...
    lsim(Gstep, modelInput, modelTime);


% Add initial simulator displacement back
modelAbsolute = ...
    yInitial + modelChange;


%% ============================================================
% 18. EXPERIMENTAL DATA AFTER STEP
%% ============================================================

experimentalMask = ...
    tRelative >= 0 & ...
    tRelative <= maximumModelTime;

experimentalTime = ...
    tRelative(experimentalMask);

experimentalOutput = ...
    y(experimentalMask);


%% ============================================================
% 19. CREATE FIGURES FOLDER
%% ============================================================

figureFolder = ...
    fullfile(repoFolder, 'figures');

if ~exist(figureFolder, 'dir')

    mkdir(figureFolder);

end


%% ============================================================
% 20. FIGURE 1 - STEP INPUT
%% ============================================================

figure('Name', 'Measured Step Input');

plot( ...
    tRelative, ...
    u, ...
    'LineWidth', ...
    1.8);

hold on;

xline( ...
    0, ...
    '--', ...
    'Step applied');

grid on;

xlabel('Time relative to step (s)');
ylabel('Input');
title('Measured Step Input');

xlim([-2 12]);


%% ------------------------------------------------------------
% Save Step Input Figure
%% ------------------------------------------------------------

stepInputFile = ...
    fullfile(figureFolder, ...
    'step_input_matlab.png');

try

    exportgraphics( ...
        gcf, ...
        stepInputFile, ...
        'Resolution', ...
        300);

catch

    saveas( ...
        gcf, ...
        stepInputFile);

end


%% ============================================================
% 21. FIGURE 2 - MEASURED STEP RESPONSE
%% ============================================================

figure('Name', 'Measured Step Response');

plot( ...
    experimentalTime, ...
    experimentalOutput, ...
    'LineWidth', ...
    1.8);

hold on;


yline( ...
    ySS, ...
    '--', ...
    sprintf('Steady state = %.3f', ySS));


plot( ...
    Tp, ...
    yPeak, ...
    'o', ...
    'MarkerSize', ...
    8, ...
    'LineWidth', ...
    1.5);


grid on;

xlabel('Time after step (s)');
ylabel('Displacement');
title('Measured Step Response');


legend( ...
    'Experimental response', ...
    'Steady-state value', ...
    'First peak', ...
    'Location', ...
    'best');

xlim([0 maximumModelTime]);


%% ------------------------------------------------------------
% Add annotation
%% ------------------------------------------------------------

text( ...
    Tp + 0.3, ...
    yPeak, ...
    sprintf([ ...
    'Peak = %.3f\n' ...
    'T_p = %.2f s\n' ...
    'OS = %.2f%%'], ...
    yPeak, ...
    Tp, ...
    percentOvershoot));


%% ------------------------------------------------------------
% Save Measured Step Figure
%% ------------------------------------------------------------

stepResponseFile = ...
    fullfile(figureFolder, ...
    'step_response_matlab.png');

try

    exportgraphics( ...
        gcf, ...
        stepResponseFile, ...
        'Resolution', ...
        300);

catch

    saveas( ...
        gcf, ...
        stepResponseFile);

end


%% ============================================================
% 22. FIGURE 3 - MODEL VALIDATION
%% ============================================================

figure('Name', 'Step Response Validation');

plot( ...
    experimentalTime, ...
    experimentalOutput, ...
    'LineWidth', ...
    1.8);

hold on;


plot( ...
    modelTime, ...
    modelAbsolute, ...
    '--', ...
    'LineWidth', ...
    1.8);


yline( ...
    ySS, ...
    ':', ...
    sprintf('Steady state = %.3f', ySS));


plot( ...
    Tp, ...
    yPeak, ...
    'o', ...
    'MarkerSize', ...
    7, ...
    'LineWidth', ...
    1.5);


grid on;

xlabel('Time after step (s)');
ylabel('Displacement');

title( ...
    'Experimental vs Identified Step Response');


legend( ...
    'Experimental response', ...
    'Identified model', ...
    'Steady-state value', ...
    'Experimental peak', ...
    'Location', ...
    'best');

xlim([0 maximumModelTime]);


%% ------------------------------------------------------------
% Save Validation Figure
%% ------------------------------------------------------------

validationFile = ...
    fullfile(figureFolder, ...
    'step_validation_matlab.png');

try

    exportgraphics( ...
        gcf, ...
        validationFile, ...
        'Resolution', ...
        300);

catch

    saveas( ...
        gcf, ...
        validationFile);

end


%% ============================================================
% 23. SAVE CALCULATED RESULTS TO CSV
%% ============================================================

resultNames = { ...
    'DC Gain'
    'Percentage Overshoot'
    'Damping Ratio'
    'Damped Frequency (rad/s)'
    'Natural Frequency (rad/s)'
    'Corner Frequency (rad/s)'
    'Pole Real Part'
    'Pole Imaginary Part'
    'Numerator'
    'Denominator s coefficient'
    'Denominator constant'
    };


resultValues = [ ...
    K
    percentOvershoot
    zeta
    omegaD
    omegaN
    omegaCorner
    real(systemPoles(1))
    abs(imag(systemPoles(1)))
    numerator
    denS
    denConstant
    ];


resultsTable = table( ...
    resultNames, ...
    resultValues, ...
    'VariableNames', ...
    {'Parameter', 'Value'});


resultsFile = ...
    fullfile( ...
    repoFolder, ...
    'data', ...
    'step_test', ...
    'step_identification_results.csv');


% Make folder if necessary
resultsFolder = fileparts(resultsFile);

if ~exist(resultsFolder, 'dir')
    mkdir(resultsFolder);
end


writetable( ...
    resultsTable, ...
    resultsFile);


%% ============================================================
% 24. FINISHED
%% ============================================================

fprintf('\n');
fprintf('=============================================\n');
fprintf('ANALYSIS COMPLETE\n');
fprintf('=============================================\n\n');

fprintf('Generated figures:\n\n');

fprintf('%s\n', stepInputFile);
fprintf('%s\n', stepResponseFile);
fprintf('%s\n', validationFile);


fprintf('\nCalculated results saved to:\n');
fprintf('%s\n\n', resultsFile);


fprintf('For your experimental data, the results should be close to:\n\n');

fprintf('K       approximately 0.638\n');
fprintf('OS      approximately 2.98 %%\n');
fprintf('zeta    approximately 0.745\n');
fprintf('wd      approximately 1.21 rad/s\n');
fprintf('wn      approximately 1.81 rad/s\n');
fprintf('poles   approximately -1.35 +/- j1.21\n\n');

fprintf('Expected step-test transfer function:\n\n');

fprintf('                2.10\n');
fprintf('G(s) = --------------------------\n');
fprintf('        s^2 + 2.70s + 3.29\n\n');