import wave
import math
import struct
import os

def generate_beep(output_path):
    # Ensure directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    sample_rate = 44100
    duration = 3.0  # seconds
    frequency = 880.0  # Clear high beep (880Hz)
    num_samples = int(duration * sample_rate)
    
    # 0.5s sound, 0.5s silence pattern
    with wave.open(output_path, 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = i / sample_rate
            # Play beep for first 0.5s of every second
            if (t % 1.0) < 0.5:
                # Fade in and fade out slightly to prevent clicking
                envelope = 1.0
                beep_time = t % 1.0
                if beep_time < 0.05:
                    envelope = beep_time / 0.05
                elif beep_time > 0.45:
                    envelope = (0.5 - beep_time) / 0.05
                    
                value = int(math.sin(2.0 * math.pi * frequency * t) * 16384.0 * envelope)
            else:
                value = 0
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)
    print(f"Generated beep sound at: {output_path}")

# Paths to generate
paths = [
    '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/assets/sounds/alarm_beep.wav',
    '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/android/app/src/main/res/raw/alarm_beep.wav',
    '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/ios/Runner/alarm_beep.wav',
    '/Users/almanimation/Downloads/Caixa Remedios/medicaixa_app/macos/Runner/alarm_beep.wav',
]

for p in paths:
    generate_beep(p)
