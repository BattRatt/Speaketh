# Speaketh Addon API

Speaketh 1.2.0 exposes a versioned API for chat splitters, listeners, and roleplay
tools. Check `Speaketh.API.VERSION` before using it. Version 1 is additive: new
methods may be added without changing the version, while incompatible signature
changes require a version bump.

Do not use `Speaketh.Internal`. It exists only to connect Speaketh's files and
may change in any release.

## Availability

Declare Speaketh as an optional dependency if your addon can integrate with it:

```toc
## OptionalDeps: Speaketh
```

Then feature-detect the API:

```lua
local API = Speaketh and Speaketh.API
if API and API.VERSION >= 1 then
    -- Integration is available.
end
```

## Splitter workflow

Split the original text first, then call `TranslateChunk` once for every source
chunk. This keeps each visible chunk paired with its original for fluency-based
decoding.

```lua
if Speaketh.API:WouldTranslate(chatType) then
    Speaketh.API:SetSplitterBypassing(true)
    local translated = Speaketh.API:TranslateChunk(sourceChunk, chatType, target)
    Speaketh.API:SetSplitterBypassing(false)
    -- Send translated through the splitter's normal queue.
end
```

For an edit-box callback, keep bypassing enabled until the current callback
chain has completed, usually by clearing it with `C_Timer.After(0, ...)`.

### `API:SetSplitterBypassing(active)`

Enables or clears external splitter ownership for the current send.
`API:IsSplitterBypassing()` returns the current state. EmoteScribe 1.1.8 still
uses the legacy field directly, which remains supported for compatibility.

### `API:WouldTranslate(chatType)`

Returns whether Speaketh would currently transform that chat type. It respects
the enabled state, per-channel settings, selected language, fluency, dialect,
and speech effect.

### `API:GetTagOverhead(chatType)`

Returns the byte count added by Speaketh's visible language tag. Splitters can
reserve this amount before chunking. Language and effect expansion still need a
safety margin.

### `API:TranslateChunk(text, chatType, target)`

Translates one already-split source chunk and performs the matching original
cache and addon-payload operation. `target` is required for whispers. Returns a
non-empty string and falls back to the input on failure.

### `API:Translate(text, options)`

Lower-level transform that does not send anything. Returns:

```text
translatedText, languageKey, status
```

Options include `chatType`, `langKey`, `ignoreChannelToggle`, and
`ignoreLockdown`. If a non-nil language key is returned, the caller must invoke
`API:BroadcastOriginal` after arranging the corresponding visible send.

### `API:BroadcastOriginal(original, languageKey, chatType, target)`

Sends the original-text payload through Speaketh's route for the visible chat
type. Prefer `TranslateChunk` for splitters because it performs this step
automatically and preserves FIFO ordering.

## Listener helpers

### `API:Decode(sender, message, languageTag)`

Returns a non-destructive decoded view when a matching original is currently in
Speaketh's short-lived cache:

```text
decodedText, languageKey, fluency, originalText
```

It does not consume the cache entry used by Speaketh's own chat filter.

### Introspection

- `API:GetCurrentLanguage()`
- `API:GetLanguageDisplayName(languageKey)`
- `API:GetFluency(languageKey)`
- `API:GetKnownLanguages()`
- `API:GetAllLanguages()`
- `API:IsCustomLanguage(languageKey)`
- `API:IsLocked()`

## Callback dispatcher

The versioned callback registration surface is available for future additive
events:

```lua
Speaketh.API.RegisterCallback(owner, eventName, handler)
Speaketh.API.UnregisterCallback(owner, eventName)
Speaketh.API.UnregisterAllCallbacks(owner)
```

No callback event is guaranteed in API version 1 unless documented in a future
revision of this file. Consumers should use the direct methods above today.

## Chattery and EmoteScribe

Chattery 0.8.4 uses LibChatFilter v1. Speaketh consumes its public pre-send
context, but LibChatFilter v1 does not expose final split chunks. A guarded
Chattery adapter is therefore still required to maintain source-to-translation
pairing.

EmoteScribe 1.1.8 includes its own Speaketh module and translates each Enscriber
chunk through `TranslateChunk`. Speaketh recognizes ownership using Enscriber's
public version API and does not access `LibEnscriber.Internal`.
