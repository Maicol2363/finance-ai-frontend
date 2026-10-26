# Performance scope

No latency or recognition-accuracy benchmark is claimed. Acoustic speech was played through Linux speakers and recorded by the phone's actual microphone; eSpeak produced inaccurate amount words. A natural synthetic voice produced Spanish words, and the user separately confirmed human dictation. A 25-second screen recording and screenshots are private local evidence, not public logs.

Bound preparation/opening/finalization in Dart and native startup/no-progress callbacks. Native device callbacks now replay preparation if the event sink subscribes late, rearm idle deadlines on partials, bound empty-result retries, reset retry counts after valid words and preserve words for review if terminal callbacks stall. Vosk decoding remains off the UI thread and in RAM.

Widget tests cover widths 320/360/390/430 dp, light/dark and enlarged text; phone checks cover portrait/landscape, font scale 1.5, gestures and three-button navigation. Original font scale 1.0, rotation 0, accelerometer_rotation 0 and gesture overlay were restored.
