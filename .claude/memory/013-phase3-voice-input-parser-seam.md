Date: 2026-06-12
Phase 3 voice input wiring.
- Dep: speech_to_text 7.4.0. Only new package.
- TaskParser seam (deferred since 005): lib/services/task_parser.dart — abstract TaskParser + PlainParser(title=rawText.trim()). LLM impl swaps in here without touching callers.
- UX: mic IconButton on HomeScreen AppBar → showVoiceCaptureSheet() → PlainParser.parse() → store.add(). Graceful fallback on init()=false / denied / no_match.
- Permission: RECORD_AUDIO in manifest; plugin's initialize() drives the contextual prompt.
- Manifest <queries> gotcha (sibling of v22 receiver bug, mem 009): Android 11+ needs <intent><action android:name='android.speech.RecognitionService'/></intent> plus googlequicksearchbox package visibility, or initialize() returns false.
Rule: any freeform-text entry path (voice now, LLM later) routes through TaskParser.parse() — never store.add() with raw text directly.
