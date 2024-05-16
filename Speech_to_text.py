import speech_recognition as sr
import sys

def main(audio_file):
    recognizer = sr.Recognizer()
    audio_file = sr.AudioFile(audio_file)
    with audio_file as source:
        audio = recognizer.record(source)
    try:
        text = recognizer.recognize_google(audio)
        print(text)
    except sr.UnknownValueError:
        print("Speech recognition could not understand audio")
    except sr.RequestError as e:
        print(f"Could not request results; {e}")

if __name__ == "__main__":
    main(sys.argv[1])
