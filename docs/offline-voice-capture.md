# Local voice input

Voice is input assistance for the existing Gastos chat. It never saves a
financial movement or sends audio to the API. Accepted words call the same
`TextCaptureController.send` as typed messages; the existing proposal, correction,
retry and confirmation flow remains authoritative. The backend therefore uses
the existing `/api/v1/capture/text/proposals` contract and `text_ai` capture source.

## Interaction

- Android and Windows: tap/click the composer microphone once to start hands-free
  dictation. Recognized hypotheses update the existing message field; no second
  transcript editor or message bubble is created before Send. A typed draft is
  retained as the prefix, and releasing or dragging a pointer does not submit.
- The Anchored Composer puts a compact recording toolbar above that same field.
  Pause uses the existing stop-to-review path and retains final buffered words.
  Tapping or keyboard-focusing the field interrupts capture immediately through
  the existing session guard, so late results cannot replace edits. Continue
  starts a new recognition session with the edited text as its prefix.
- Delete immediately invokes the existing discard action, restores the typed
  prefix and closes the toolbar. Close preserves all visible text. Neither action
  asks for confirmation or sends a financial proposal.
- The existing Send action explicitly finalizes and analyzes text once. Proposal
  review and financial confirmation remain separate and unchanged. The elapsed
  indicator is presentation only; it adds no recording deadline or native logic.
- Keyboard and accessibility activation use the same tap/pause/resume controls;
  Escape stops without sending. Backgrounding, switching capture methods,
  navigation and disposal close recognition while preserving visible words.
- Slow finalization switches to review after two seconds. Late results are
  rejected and cannot replace edits. No partial hypothesis triggers an API call.
- The existing 1000-character text limit also applies to voice. Excess words are
  retained for editing, rather than silently truncated or automatically sent.

The controls use `AppPalette`, the existing composer, and Flutter Material icons.
Light/dark appearance, reduced motion and enlarged text are supported.

## Phone report assessment

The connected Samsung A55 reports Android 16. The older phone's model/version
and the Xiaomi's version remain unknown; their screenshots establish failures,
but do not prove that Spanish or those Android versions are unsupported.

- A successful Spanish transcript followed by an empty/no-match result could
  leave the panel saying dictation was unavailable. Empty utterances now offer
  retry/review without declaring the language unavailable.
- Pending phone-model updates and silent support callbacks could block a usable
  phone recognizer. Support enumeration is now advisory; an unresponsive opening
  or incompatible native language/service switches to the integrated engine.
- Generic assistant/input-method settings did not configure the app's native
  recognizer. Recovery now offers the app's own model download, or this app's
  microphone permissions when the permission is the actual failure.
- The custom bottom tabs missed the system bottom inset, so Samsung's three
  navigation buttons covered labels. The shared navigation now applies SafeArea
  spacing for both buttons and gestures.
- The menu's duplicate voice action and an edit target left behind after failure
  confused recovery. Voice now uses one composer microphone, and failures clear
  its gesture state; setup panels scroll on smaller displays.

Server-side AI proposal configuration is separate and is outside these fixes.

## Native bridge and locality

Both targets implement `finance_ai/speech` and `finance_ai/speech/events`.
Methods are initialize, prepare, start, stop, cancel, download and settings.
Recognition operations carry a unique session identifier. Events are ready,
listening, partial, final, error and download. Partial/final text is the complete hypothesis
for that session, rather than a new fragment to append in Dart.

Android uses an explicitly on-device recognizer on API 31+ when it works.
Model enumeration is advisory and bounded to 1.5 seconds: a pending update or a
silent support callback must not block a recognizer that can already transcribe.
Related locales are selected only within the chosen Spanish or English language.
An unresponsive start is bounded to six seconds before attempting the integrated
offline engine. No path uses `createSpeechRecognizer` or uploads audio.

The integrated Vosk engine supports the app's existing API 24+ baseline, including
phones without the manufacturer/Google on-device service. Missing models offer
one explicit download per language, about 40 MB each. Pinned SHA-256 checksums,
archive size limits and contained extraction protect installation. Verified
models occupy approximately 60 MB (Spanish) or 71 MB (English), are kept in private
no-backup storage, and are reused after application updates. Loading and decoding
run on a worker; PCM buffers stay in RAM and are cleared when capture ends.

Setup events distinguish requesting, downloading with percentage, verifying and
installing, and loading. Completion updates readiness without opening the mic.
Users can type while downloading; cancellation interrupts the network request and
rejects late callbacks. Returning from permission settings or background setup
rechecks readiness without restarting capture. Only microphone failures link to
this app's permissions; keyboard and assistant configuration is unnecessary.

Unrecognized/empty utterances remain retryable, with any visible words available
for review. They do not classify the phone or Spanish language as unsupported.
Copyable failures contain bounded engine, stage, fallback-cause and Android API
metadata, never recognizer exception messages, audio or dictated text.

Voice is available from the composer microphone; the `+` menu offers photo, text
and manual capture. Error/setup panels scroll within the available space, and the
shared bottom navigation reserves Android's gesture or three-button system inset.

Android endpointers may close an utterance during a pause. The bridge retains
completed phrases and rearms only after a terminal result/error while the user
keeps dictation active. Rearming can introduce short gaps, and recognition providers
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
tap-to-start, anchored layout, pause/resume, immediate discard, editing, cancellation/restart,
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

## Model and runtime provenance

- Vosk Android 0.3.75 and JNA 5.18.1, pinned to the official Android demo versions.
- Spanish: `vosk-model-small-es-0.42.zip`, SHA-256
  `09b239888f633ef2f0b4e09736e3d9936acfd810bc65d53fad45261762c6511f`.
- English: `vosk-model-small-en-us-0.15.zip`, SHA-256
  `30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498`.
- Sources: [Vosk models](https://alphacephei.com/vosk/models),
  [official Android demo](https://github.com/alphacep/vosk-android-demo).
  Apache 2.0 license and dependency notices are included in the Android assets.

The small fallback models prioritize streaming and modest mobile resource use.
Their accuracy on Colombian amounts, merchant names and accents still requires
real utterance testing; the existing financial review/confirmation remains
authoritative. A public fixture can verify offline decoding without recording a
user, but cannot establish accuracy on every manufacturer.

The local JVM suite verifies archive integrity, containment, cancellation and
installation. `OfflineSpeechCompatibilityTest` loads both verified models, decodes
the Vosk project's public English WAV, and injects an unavailable phone recognizer
to check missing-model recovery and installed-model readiness without opening the
microphone or calling the finance API. Its public fixtures live only under the
ignored `build/voice-verification/assets` directory, never in the product APK.
The suite also checks release before queued audio activation, so a quick release
returns a retryable empty-utterance result without opening the microphone.

Verified on 2026-10-12: all 460 shared Flutter tests pass with 83.77% line
coverage, formatting and static analysis pass, and all five model-store JVM
tests pass. All four native compatibility assertions pass on the connected
Samsung SM-A556E running Android 16, using a disposable verification package.
Both fallback models load, the public WAV decodes locally, missing phone-service
recovery works with/without an installed model, and release before audio
activation does not open the microphone. The Android APK builds successfully;
its 64-bit native libraries and ZIP packaging pass 16 KB alignment checks.
These checks do not measure live microphone accuracy or certify the unknown
older phone and Xiaomi; both still need real-device utterance testing.

For a physical-phone test build:

```powershell
.\tool\build_android.ps1 -AudioTest -ApiBaseUrl http://127.0.0.1:8000
```

This creates the separate `Finance AI (audio test)` package for safe updates to
the installed test app. Use `adb reverse tcp:8000 tcp:8000` for the USB API route.
The server AI configuration is outside this Android voice reliability work.

The [Android voice/UI checkpoint](android-voice-ui-handoff.md) records the installed
APK, test-environment recovery, scope decisions and UI contracts for subsequent
design work.

## Anchored Composer UI verification

Verified on 2026-10-12 after integrating the agreed composer layout: all 475 shared
Flutter tests pass with 83.76% line coverage; formatting and static analysis pass.
Regression checks cover Android/Windows tap capture, the same persistent message
field, pause/edit/resume with late-result protection, immediate discard, explicit
single submission, Escape, one-tap recovery, setup/download controls and responsive
phone, landscape and desktop layouts with enlarged text in light/dark themes.

All five native Windows smoke tests pass, the normal Windows bundle was restored,
and both final Windows and Android audio-test debug builds succeed. The Android
build retains the existing audio-test package and loopback API configuration.
The controller, native engines, event bridge, repositories, dependencies, shared
theme and navigation are unchanged. Native live-microphone accuracy remains the
previous checkpoint's device-testing concern; this UI work does not remeasure it.

## Integration with develop for team review

On 2026-10-13, the branch was integrated with the current `develop` UI and
accessibility changes. The Anchored Composer uses the shared icon catalog,
preserves the global quick-capture sheet's voice/text entry modes, and keeps
explicit keyboard focus for microphone and pause/resume controls. Added checks
cover focused Enter/Space activation and both quick-capture modes.

All 521 shared Flutter tests pass with 84.70% line coverage; formatting and static
analysis pass. Integration also updates stale UI test labels/icon selectors,
scopes the logout scroll target, disposes a semantics handle before test-end
verification, and refreshes the visually reviewed dashboard golden to the
existing `develop` design. Accounts, authentication, dashboard, settings and
receipt production behavior remain exactly as supplied by `develop`.
