clear all;
close all;
clc;

% Load AFINN lexicon from text file
afinn_file = 'AFINN-111.txt';
afinn = containers.Map();

fid = fopen(afinn_file, 'r');
while ~feof(fid)
    line = fgetl(fid);
    parts = strsplit(line, '\t');
    word = lower(parts{1});
    score = str2double(parts{2});
    afinn(word) = score;
end
fclose(fid);

main(afinn);

% Function to record audio and save to file with noise cancellation
function record_audio(file_name)
    recObj = audiorecorder(44100, 16, 1);
    disp('Start speaking.');
    recordblocking(recObj, 5); % Record for 5 seconds
    disp('End of recording.');
    audio_data = getaudiodata(recObj);
    
%     figure;
%     subplot(2,1,1);
%     plot(audio_data);
%     title('Original Audio Data');
%     xlabel('Sample Number');
%     ylabel('Amplitude');

    % Save original recorded audio data to file
    audiowrite(strcat('original_', file_name), audio_data, 44100);
    
    % Noise cancellation using spectral gating
    clean_audio = noise_reduction(audio_data, 44100);
    
%     subplot(2,1,2);
%     plot(clean_audio);
%     title('Filtered Audio Data');
%     xlabel('Sample Number');
%     ylabel('Amplitude');
    
    % Save filtered audio data to file
    audiowrite(file_name, clean_audio, 44100);
    
    
    
    
end


% Function for noise reduction using spectral gating
function clean_audio = noise_reduction(audio_data, fs)
    % Parameters
    noise_gate_threshold = 0.02; % Adjust this threshold based on your noise level

    % Perform short-time Fourier transform (STFT)
    win_len = round(0.025 * fs); % 25 ms window
    overlap = round(0.015 * fs); % 15 ms overlap
    nfft = 2^nextpow2(win_len);
    [S, F, T] = spectrogram(audio_data, win_len, overlap, nfft, fs);

    % Estimate noise spectrum
    noise_est = mean(abs(S(:, 1:10)), 2); % Assume first 10 frames are noise

    % Apply spectral gating
    S_clean = S;
    for i = 1:size(S, 2)
        S_clean(:, i) = S(:, i) .* (abs(S(:, i)) > noise_gate_threshold * noise_est);
    end

    % Perform inverse STFT
    clean_audio = istft(S_clean, win_len, overlap, nfft, fs);
end

% Inverse Short-Time Fourier Transform function
function x = istft(S, win_len, overlap, nfft, fs)
    win = hamming(win_len, 'periodic');
    step = win_len - overlap;
    x = zeros((size(S, 2)-1) * step + win_len, 1);
    x_window_sum = zeros(size(x));
    for i = 1:size(S, 2)
        start_index = (i-1) * step + 1;
        x_segment = real(ifft(S(:, i), nfft));
        x(start_index:start_index + win_len - 1) = x(start_index:start_index + win_len - 1) + x_segment(1:win_len) .* win;
        x_window_sum(start_index:start_index + win_len - 1) = x_window_sum(start_index:start_index + win_len - 1) + win;
    end
    % Normalize to correct the amplitude
    x = x ./ max(abs(x_window_sum));
end

% Function to convert audio file to text using Python script
function text = speech_to_text(file_name)
    % Call the Python script using system command
    [status, cmdout] = system(sprintf('python speech_to_text.py %s', file_name));
    if status == 0
        text = strtrim(cmdout);
    else
        error('Error calling Python script: %s', cmdout);
    end
end

% Function to identify gender using Python script
function gender = identify_gender(audio_file)
    % Call Python script to predict gender using pre-trained model
    [status, cmdout] = system(sprintf('python identify_gender.py %s', audio_file));
    if status == 0
        gender = strtrim(cmdout);
    else
        error('Error calling Python script: %s', cmdout);
    end
end

% Function to detect emotion in text
function emotion = detect_emotion(text, afinn)
    % Tokenize the input text into words
    words = strsplit(lower(text), ' ');

    % Initialize sentiment score
    sentiment_score = 0;
    
    % Flag to track negation
    negation_flag = false;

    % List of common negation words
    negations = {'no', 'not', 'never', 'none', 'nobody', 'nothing', 'neither', 'nowhere', 'hardly', 'scarcely', 'barely'};

    % Calculate sentiment score for each word
    for i = 1:length(words)
        word = regexprep(words{i}, '[^a-zA-Z]', ''); % Remove non-alphabetic characters
        
        % Check for negation
        if ismember(word, negations)
            negation_flag = true;
            continue; % Skip to the next word
        end
        
        % Handle negation
        if negation_flag
            if isKey(afinn, word)
                sentiment_score = sentiment_score - afinn(word);
            end
            negation_flag = false; % Reset negation flag
        else
            if isKey(afinn, word)
                sentiment_score = sentiment_score + afinn(word);
            end
        end
    end

    % Determine emotion based on sentiment score
    if sentiment_score > 0
        emotion = 'Positive';
    elseif sentiment_score < 0
        emotion = 'Negative';
    else
        emotion = 'Neutral';
    end
end

% Main function
function main(afinn)
    fprintf('\nWelcome to Sentiment Analysis Application\n');
    while true
        % Ask for user permission to continue
        user_input = input('To Start Recording: Press Enter\n To Exit: Type ''1''\n\n', 's');
        if strcmpi(user_input, '1')
            break;
        end
        
        % Record audio from user
        audio_file = 'user_input.wav';
        record_audio(audio_file);
        
        % Convert audio to text
        user_input = speech_to_text(audio_file);
        
        % Gender identification
        gender = identify_gender(audio_file);
        disp(['Detected Gender: ' gender]);
        NET.addAssembly('System.Speech');
        mySpeaker = System.Speech.Synthesis.SpeechSynthesizer;
        mySpeaker.Rate = 1;
        mySpeaker.Volume = 100;
        Speak(mySpeaker, ['Detected Gender: ' gender]);
        
        % Detect emotion
        emotion = detect_emotion(user_input, afinn);
        
        % Display result
        fprintf('''%s'' is a %s emotion\n\n', user_input, emotion);
        Speak(mySpeaker, ['The detected emotion is ' emotion]);
    end
end
