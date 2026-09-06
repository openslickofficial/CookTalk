# Rime TTS API Notes — Verified 2026-09-06

All information below was fetched from Rime's **live documentation** at
[docs.rime.ai](https://docs.rime.ai) and the public voice catalog API.
Nothing is guessed or memorized.

---

## Models

| Model ID | Name | Released | Status | Notes |
|----------|------|----------|--------|-------|
| `coda` | **Coda** (flagship) | May 2026 | ✅ Active, recommended | LLM backbone + speech engine. Highest quality scores. Sub-100 ms model latency. 253 voices, 9 languages. |
| `mistv3` | Mist v3 | March 2026 | ✅ Active | Low-latency (~37 ms P50 TTFB). 78 voices, 4 languages (en/fr/de/es). No inline pronunciation control. |
| `mistv2` | Mist v2 | Feb 2025 | ✅ Active | 138 voices, 4 languages. Supports inline pronunciation control & custom pauses. |
| `mist` | Mist legacy | Apr 2023 | ⚠️ Legacy | Alias for older Mist. |
| `arcana` | Arcana | — | ❌ Deprecated Aug 15, 2026 | Do NOT use. |
| (model v1) | — | Apr 2022 | ❌ Deprecated | — |

> **⚠️ Default model warning**: Requests that omit `modelId` or send an unrecognized
> value are served by **Mist v3**, NOT Coda. Always set `modelId` explicitly.

### Recommendation for CookTalk
- **Baseline (Phase 1)**: Use `coda` with the streaming HTTP endpoint (accept `audio/mpeg`) to match the "fetch whole audio then play" pattern. This gives us the flagship model's quality as the baseline.
- **Optimized (Phase 2)**: Use `coda` or `mistv3` via WebSocket `/ws3` for lowest TTFB.

---

## Authentication

- **Method**: Bearer token in `Authorization` header
- **Header**: `Authorization: Bearer YOUR_API_KEY`
- **Key source**: https://app.rime.ai dashboard
- ✅ Confirmed — this is the only auth method.

---

## Endpoints

### HTTP (Streaming)

| Endpoint | Region |
|----------|--------|
| `https://users.rime.ai/v1/rime-tts` | US West (default) |
| `https://users-west.rime.ai/v1/rime-tts` | US West (us-west-2) |
| `https://users-east.rime.ai/v1/rime-tts` | US East (us-east-1) |

All models share the same HTTP endpoint. The `modelId` field in the JSON body selects the model.

### WebSocket (Streaming)

| Endpoint | Protocol | Region |
|----------|----------|--------|
| `wss://users-ws.rime.ai/ws3` | JSON (recommended) | US West |
| `wss://users-east-ws.rime.ai/ws3` | JSON (recommended) | US East |
| `wss://users-ws.rime.ai/ws` | Raw binary | US West |
| `wss://users-east-ws.rime.ai/ws` | Raw binary | US East |

> `/ws3` is Rime's **recommended** WebSocket endpoint — structured JSON events
> with base64 audio chunks and word-level timestamps.

### Metadata (Public, no auth)

| Endpoint | Purpose |
|----------|--------|
| `GET https://users.rime.ai/data/voices/all-v2.json` | List all voices by model & language |
| `GET https://users.rime.ai/data/voices/voice_details.json` | Voice metadata (gender, age, accent) |

---

## Audio Formats

### Streaming HTTP (Coda / Mist v3)

Set via the `Accept` header:

| Format | Accept Header | Notes |
|--------|---------------|-------|
| Opus (WebM) | `audio/webm;codecs=opus` | **Recommended.** Smallest files, native browser streaming. |
| Opus (OGG) | `audio/ogg;codecs=opus` | Good compression. |
| MP3 | `audio/mpeg` | Highest compatibility. |
| WAV | `audio/wav` | Uncompressed 16-bit PCM. Native browser streaming. |
| PCM | `audio/L16` | Headerless 16-bit LE PCM. |
| G.711 μ-law | `audio/PCMU` | Headerless μ-law. |

Deprecated aliases still accepted: `audio/mp3` → `audio/mpeg`, `audio/pcm` → `audio/L16`, `audio/x-mulaw` → `audio/PCMU`.

### Non-Streaming (Mist v2 only)

Set via `audioFormat` field in JSON body. Returns base64-encoded audio in a JSON envelope.

| Format | `audioFormat` value |
|--------|-------------------|
| MP3 | `mp3` |
| WAV | `wav` |
| OGG | `ogg` |
| μ-law | `mulaw` |

---

## HTTP Request Body (Coda Streaming)

```json
{
  "text": "Hello from Rime!",
  "modelId": "coda",
  "speaker": "astra",
  "lang": "en",
  "samplingRate": 24000,
  "timeScaleFactor": 1.0
}
```

- `speaker` (required): voice name from catalog
- `text` (required): up to 1,000 chars
- `modelId`: `coda`, `mistv3`, or `mistv2`
- `lang`: BCP 47 tag (`en`, `es`, `fr`, etc.) — 3-letter ISO codes also accepted
- `samplingRate`: default 24000 Hz for Coda
- `timeScaleFactor`: >1.0 slows, <1.0 speeds (Coda/Mist v3 convention)

---

## Voices (Starter picks for CookTalk)

- `astra` — Female, young adult, American Standard. Available on Coda and Mist v2. **Recommended for testing.**
- `cove` — Female, young adult. Available on Mist v3 and Mist v2.
- `grove` — Available across Mist v3/v2.
- `ember` — Available across Mist v3/v2.

Full catalog: `GET https://users.rime.ai/data/voices/all-v2.json`

> Note: The voices JSON is keyed by model → language → voice list. Coda voices
> are NOT listed under `mist` or `mistv2` keys — they have their own section.
> As of this fetch, the `coda` key was not present in the public JSON (voices
> may be listed on the dedicated Coda catalog page instead). The voice `astra`
> is confirmed in Rime's documentation as a Coda-compatible starter voice.

---

## Deprecation Notices

1. **Arcana** — Deprecated as of August 15, 2026. Do not use.
2. **Model v1** — Deprecated (April 2022).
3. **Accept header aliases** — `audio/mp3`, `audio/pcm`, `audio/x-mulaw` are deprecated
   but still accepted. Use RFC types (`audio/mpeg`, `audio/L16`, `audio/PCMU`).

---

## Contradictions / Gotchas Found

1. **Default model is NOT Coda**: Omitting `modelId` routes to Mist v3, not the flagship.
   Always set `modelId` explicitly.
2. **speedAlpha convention flipped on Mist v2**: On Mist v2, `speedAlpha < 1.0` = faster.
   On Coda/Mist v3, the field is `timeScaleFactor` and `< 1.0` = faster. Opposite naming.
3. **Coda voices not in public JSON**: The `/data/voices/all-v2.json` endpoint has
   keys for `mist`, `mistv2`, `arcana` but Coda voices appear to be documented
   separately. Use the docs catalog page or voice_details.json.
4. **Character limit**: 1,000 characters per request across all models.

---

*Last verified: 2026-09-06 from live Rime docs.*
