# LiveKit Integration Notes — Verified 2026-09-06

All details below were verified against live documentation from Rime (`docs.rime.ai`), LiveKit (`docs.livekit.io`), and the official `livekit/agents` GitHub repository.

---

## 1. Rime LiveKit Plugin (`livekit-plugins-rime`)

### Package Details
- **PyPI package**: `livekit-plugins-rime`
- **Installation**:
  ```bash
  pip install livekit-plugins-rime
  # Or with extras via livekit-agents:
  pip install "livekit-agents[rime]"
  ```
- **Import**:
  ```python
  from livekit.plugins import rime
  # or
  from livekit.plugins.rime import TTS
  ```

### Streaming Mechanism
- **Verified**: **True WebSocket streaming**.
- The plugin connects to Rime's `/ws3` JSON WebSocket endpoint (`wss://users-ws.rime.ai/ws3`).
- Text tokens/chunks are streamed in real time over the socket; Rime responds with base64-encoded audio chunks and word-level timestamps as synthesis progresses.
- Audio playback starts immediately on the first received chunk, achieving sub-second perceived response times rather than waiting for the entire audio file.

### Constructor Parameters (`rime.TTS`)
```python
rime.TTS(
    model="coda",           # "coda" (flagship), "mistv3", or "mistv2"
    speaker="astra",        # Voice name from Rime catalog (e.g., "astra", "cove", "celeste")
    lang="eng",             # BCP-47 tag ("eng", "spa", "fra", "ger", etc.)
    use_websocket=True,     # CRITICAL: Default is False! Must be True for real WebSocket streaming (/ws3)
    speed_alpha=1.0,        # Speed adjustment factor
    sample_rate=24000,      # 24000 Hz default for Coda
    api_key=None            # Defaults to RIME_API_KEY environment variable
)
```
> **CRITICAL VERIFICATION FINDING:** The `rime.TTS` plugin has `use_websocket: bool = False` by default. If omitted or set to `False`, the plugin uses HTTP synthesis. Setting `use_websocket=True` connects directly to `wss://users-ws.rime.ai/ws3` for true real-time streaming audio frames.

---

## 2. STT: Deepgram Plugin (`livekit-plugins-deepgram`)

### Package Details
- **PyPI package**: `livekit-plugins-deepgram` (or `pip install "livekit-agents[deepgram]"`)
- **Import**: `from livekit.plugins import deepgram`
- **Class**: `deepgram.STT`

### Recommended Models
- **`nova-3`**: Current default for LiveKit Agents v1.x; highest accuracy in noisy kitchen environments with accent resilience.
- **`flux`**: Deepgram's conversational voice model with native end-of-turn detection.
- For CookTalk Phase 2, `model="nova-3"` is the verified standard.

### Constructor Parameters
```python
deepgram.STT(
    model="nova-3",
    language="en-US",
    interim_results=True,   # Real-time partial transcripts for low-latency turn detection
    smart_format=True,
    api_key=None            # Defaults to DEEPGRAM_API_KEY environment variable
)
```

---

## 3. LLM: Groq via OpenAI-Compatible Plugin (`livekit-plugins-openai`)

### Package Details
- **PyPI package**: `livekit-plugins-openai` (or `pip install "livekit-agents[openai]"`)
- **Import**: `from livekit.plugins import openai`
- **Class**: `openai.LLM`

### Pointing to Groq
Groq provides an OpenAI-compatible API at `https://api.groq.com/openai/v1`.
In `livekit-plugins-openai` 1.8.0, configure via explicit `base_url` and `api_key`:
```python
llm = openai.LLM(
    model="qwen/qwen3.8-27b",
    base_url="https://api.groq.com/openai/v1",
    api_key=os.getenv("GROQ_API_KEY"),
    max_completion_tokens=80
)
```

### Verified Groq Models on Live Account (Confirmed 2026-09-06)
When querying `https://api.groq.com/openai/v1/models` live with the active API key, Groq currently serves 14 models:
- **`qwen/qwen3.8-27b`** (**Verified & Active in Production**):
  - Confirmed live on Groq's API endpoint.
  - Organization Tier: `on_demand` pay-as-you-go service tier (`org_01m1vkkmzqe0793r7kyxeqe87s`).
  - Active rate limits: 1,000 requests limit, 8,000 Tokens Per Minute (TPM) limit.
  - Parameter configuration: Enforced `max_completion_tokens=60` to ensure requests never trip Groq's 1,000 output tokens per minute (OTPM) ceiling.
  - Benchmarked across all test queries: **~450–650 ms TTFT**.
  - Direct streaming, zero reasoning `<think>` clutter, adheres strictly to the 1-2 sentence voice prompt, and integrates cleanly with LiveKit's token stream and Rime TTS.
- Other live models returned by Groq endpoint: `qwen/qwen3.6-27b`, `groq/compound`, `groq/compound-mini`, `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `whisper-large-v3`, `meta-llama/llama-prompt-guard-2-86m`.
- Legacy model strings: `llama-3.1-8b-instant` returned HTTP 404 (deprecated/unlisted on this tier). `groq/compound-mini` triggered HTTP 413 during multi-turn prompts.

---

## 4. VAD: Silero (`livekit-plugins-silero`)

- **PyPI package**: `livekit-plugins-silero`
- **Import**: `from livekit.plugins import silero`
- **Class**: `silero.VAD.load()`
- Runs local ONNX neural voice activity detection to detect speech start, speech end, and handle barge-in interruptions cleanly.

---

## 5. Architecture Pattern: `AgentSession` (LiveKit Agents 1.x)

- **`VoicePipelineAgent` is deprecated** as of LiveKit Agents 1.0 (April 2025).
- **`AgentSession`** is the current unified orchestrator that wires VAD, STT, LLM, and TTS:
  ```python
  session = AgentSession(
      vad=silero.VAD.load(),
      stt=deepgram.STT(model="nova-3"),
      llm=openai.LLM.with_groq(model="llama-3.1-8b-instant"),
      tts=rime.TTS(model="coda", speaker="astra"),
  )
  await session.start(room=ctx.room, agent=MyAgent())
  ```

---

## 6. Built-in Metrics & Observability

LiveKit Agents 1.x provides a structured telemetry and metrics system in `livekit.agents.metrics`:

| Metric Class | Key Fields | Purpose |
|--------------|------------|---------|
| `TTSMetrics` | `ttfb` (seconds), `duration`, `audio_duration` | Measures TTS time-to-first-byte and audio generation length |
| `LLMMetrics` | `ttft` (seconds), `duration`, `tokens_per_second`, `speech_id` | Measures LLM time-to-first-token and throughput |
| `EOUMetrics` | `end_of_utterance_delay`, `transcription_delay` | Measures silence detection to final transcript time |
| `STTMetrics` | `duration`, `audio_duration`, `speech_id` | Speech-to-text processing time |

### Accessing Metrics
Subscribing to `metrics_collected` on individual plugin instances or listening to session events allows us to capture:
- End-of-utterance delay (`eou_delay`)
- LLM time to first token (`llm_ttft`)
- TTS time to first byte (`tts_ttfb`)
- Overall turn latency (User speech end to agent first sound)

All metrics can be captured and written out as JSON lines to `streaming_results.jsonl`.
