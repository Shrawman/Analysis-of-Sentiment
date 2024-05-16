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

% Function to record audio and save to file
function record_audio(file_name)
    recObj = audiorecorder(44100, 16, 1);
    disp('Start speaking.');
    recordblocking(recObj, 5); % Record for 5 seconds
    disp('End of recording.');
    audio_data = getaudiodata(recObj);
    audiowrite(file_name, audio_data, 44100);
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
        
        % Detect emotion
        emotion = detect_emotion(user_input, afinn);
        
        % Display result
        fprintf('''%s'' is a %s emotion\n\n', user_input, emotion);
        NET.addAssembly('System.Speech');

        mySpeaker = System.Speech.Synthesis.SpeechSynthesizer;
        mySpeaker.Rate = 1;
        mySpeaker.Volume = 100;
        Speak(mySpeaker,emotion);
    end
end


