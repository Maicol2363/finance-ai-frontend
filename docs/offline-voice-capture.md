# Local voice input

Voice is input assistance for the existing Gastos chat. It never saves a
financial movement or sends audio to the API. Accepted words call the same
`TextCaptureController.send` as typed messages; the existing proposal, correction,
retry and confirmation flow remains authoritative. The backend therefore uses
the existing `/api/v1/capture/text/proposals` contract and `text_ai` capture source.

## Interaction

- Android: hold the composer microphone; recognized words replace the current
  hypothesis in the existing editor. Release stops recognition and submits the
  final transcript once. A typed draft is retained as the prefix.
- Move the microphone upward into the visible edit zone to stop and enter
  review. The microphone follows the pointer, the zone highlights on approach,
  and zone entry gives a single haptic cue. Entry is latched: moving back or
  releasing cannot submit. Edit in the same composer and use its Send action.
- Windows: click to start. Click again, or use Detener y revisar, to finish in
  review. The existing Send action can finish and analyze explicitly.
- Keyboard and accessibility activation use start/stop-to-review; Escape stops
  without sending. Backgrounding, switching capture methods, navigation, pointer
  cancellation and disposal close recognition while preserving visible words.
- Slow finalization switches to review after two seconds. Late results are
  rejected and cannot replace edits. No partial hypothesis triggers an API call.
- The existing 1000-character text limit also applies to voice. Excess words are
  retained for editing, rather than silently truncated or automatically sent.

The controls use `AppPalette`, the existing composer, and Flutter Material icons.
Light/dark appearance, reduced motion and enlarged text are supported.

## Native bridge and locality

Both targets implement `finance_ai/speech` and `finance_ai/speech/events`.
Methods are initialize, prepare, start, stop, cancel, download and settings.
Recognition operations carry a unique session identifier. Events are ready,
listening, partial, final and error. Partial/final text is the complete hypothesis
for that session, rather than a new fragment to append in Dart.

Android requires an on-device recognizer on API 31+. There is no fallback to
`createSpeechRecognizer`. API 33+ checks installed local models and offers an
explicit model download when supported. Related Spanish or English locales are
selected only within the chosen language. API 31/32 can report missing languages
when recognition starts, because they lack the model-query API. Older devices or
missing on-device services retain ordinary text entry.

Android endpointers may close an utterance during a pause. The bridge retains
completed phrases and rearms only after a terminal result/error while the user
continues holding. Rearming can introduce short gaps, and recognition providers
may omit partial callbacks. Physical-device testing remains necessary.

Windows uses an in-process SAPI recognizer on a worker thread. It explicitly
selects a matching installed Microsoft Desktop recognition token and does not
substitute a shared recognizer, OneCore/TTS voice, or arbitrary provider. The
grammar is warmed without opening audio input. Start opens the microphone; stop
closes input and finishes buffered words. Hypotheses and completed phrases update
the shared editor; a completed phrase does not stop the entire session.

A Windows display language or TTS voice does not establish recognition support.
Missing local Spanish/English recognition produces the shared copyable failure
and a settings action. No application recording, audio upload, transcript logging
or transcript diagnostic fields are introduced. AI still needs its normal network
connection; downloading a missing local model is a separate explicit setup step.

## Reference and verification

The read-only reference was
`D:/ProgrammingEnvironment/Todo-List/docs/SPEECH_REUSE_HANDOFF.md` and its focused
native speech sections. Adaptations remove the reference's online fallback,
hard-coded English, Windows first-result auto-submit, fixed recording timeout,
and callbacks without session guards.

Relevant platform contracts:

- [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer)
- [Android local model support](https://developer.android.com/reference/android/speech/RecognitionSupport)
- [Windows recognizer input](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ms718864(v=vs.85))
- [Windows recognizer state](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ms718870(v=vs.85))

Automated verification covers hypothesis revisions, one accepted submission,
swipe entry/release, fast swept hit testing, editing, cancellation/restart,
background/disposal, missing native bridges, language selection, setup actions,
timeouts, the length limit, and safe diagnostics for every published failure.
Windows smoke verification also prepares local recognition without recording.

Verified locally on 2026-10-05: 442 Flutter tests passed with 83.64% line
coverage; the Android debug APK and Windows debug application built successfully.
All five native Windows smoke tests passed. Preparing the installed English
recognizer took 415 ms on the development PC, without opening the microphone;
this measures preparation only, not recognition or end-to-end response time.
The current backend integration passed 408 tests with 89.04% combined coverage
against an isolated test database. Spanish recognition was unavailable on the
development PC, so its missing-engine path was checked rather than its accuracy.

On each target device, test both languages with networking disabled, permissions
denied, missing models, microphone contention, long held input with pauses, and
rapid stop/restart. Then restore networking and confirm that recognition leads to
the existing AI proposal and still requires the normal financial confirmation.
Measure first visible words, release-to-final-text, and text-API response time
separately. One-second recognition feedback is a target, not a measured guarantee;
the native engine's behavior and the actual microphone/device must be checked.
