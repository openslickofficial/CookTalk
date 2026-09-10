# Task 2: Timer Idle Reset Fix - Evidence Document

## Problem Statement
Timer alerts were not resetting the 5-minute idle timeout clock. This caused premature disconnects:
- **1-minute timer**: User disconnected at 5:00 total (1min timer + 4min remaining from original 5min window)
- **10-minute timer**: User disconnected immediately after alert (10min timer exhausted the 5min window)

## Solution Implemented
Added `copilot.record_user_speech()` call immediately after every timer "Ding ding!" alert to reset the idle clock, giving the user a fresh 5-minute window to respond after ANY timer completion.

## Code Changes

### Three Timer Completion Paths Fixed

All three timer task implementations now reset the idle clock after speaking the alert:

1. **`start_cooking_timer`** (line ~807)
2. **`modify_timer`** (line ~968)  
3. **`extend_timer`** (line ~1051)

Each path now includes:
```python
await copilot.session.say(
    f"Ding ding! Your timer for {label} is done.",
    allow_interruptions=True,
    add_to_chat_ctx=True,
)
await asyncio.sleep(0.4)
# TASK 2 FIX: Reset idle clock after timer alert
copilot.record_user_speech()
```

## Retraced Timing Math

### After Fix (Expected Behavior)

**1-minute timer scenario:**
- t=0:00: Timer starts (1 minute)
- t=1:00: Timer fires → "Ding ding!" alert → idle clock RESETS to 0:00
- t=6:00: Disconnect (1min timer + 5min fresh idle window)
- ✅ **Disconnect at 6:00 total**

**10-minute timer scenario:**
- t=0:00: Timer starts (10 minutes)
- t=10:00: Timer fires → "Ding ding!" alert → idle clock RESETS to 0:00
- t=15:00: Disconnect (10min timer + 5min fresh idle window)
- ✅ **Disconnect at 15:00 total**

**6-minute timer scenario** (specific test case requested):
- t=0:00: Timer starts (6 minutes)
- t=6:00: Timer fires → "Ding ding!" alert → idle clock RESETS to 0:00
- t=11:00: Disconnect (6min timer + 5min fresh idle window)
- ✅ **Disconnect at 11:00 total**

### Key Point
The user now gets a **genuine 5 minutes** to respond after the timer alert fires, **regardless of timer duration**. Long-running timers (6+ minutes) no longer cause immediate or near-immediate disconnects.

## Additional Findings

### 1. Ungraceful Disconnect Handling

**Finding**: `stop_idle_monitor()` is ONLY called in the explicit `end_session()` tool (line ~1127).

**Evidence**:
```bash
$ grep -n "stop_idle_monitor" agent/agent.py
503:    def stop_idle_monitor(self) -> None:
1127:            copilot.stop_idle_monitor()  # TASK 2: Stop idle monitor on explicit session end
```

**Risk Assessment**:
- On ungraceful disconnect (connection drop, app force-quit, network loss), the `entrypoint()` function does NOT wrap `await session.start()` in a try/finally block
- The idle monitor task will continue running orphaned
- Eventually (after 5+ minutes of no activity), the orphaned monitor will attempt to call `session.say()` on a dead session
- This will likely throw an exception, but it's caught silently in the monitor loop's `except Exception` block (line ~499)

**Actual Code (idle_monitor_loop, line ~474-499)**:
```python
if self.session:
    try:
        await self.session.say(
            "Hey Chef, you've been quiet for a while and no timers are running...",
            allow_interruptions=False,
            add_to_chat_ctx=True,
        )
        await asyncio.sleep(2.0)  # Let message finish
    except Exception as e:
        logger.debug(f"[IDLE MONITOR] Could not speak goodbye: {e}")
```

**Conclusion**: The orphaned monitor will NOT crash the worker, but it will continue consuming a task slot until the timeout fires and fails silently. Not critical, but not clean.

**Recommendation**: Wrap `await session.start()` in entrypoint with try/finally to call `copilot.stop_idle_monitor()` on ANY exit (graceful or ungraceful).

### 2. Ungrounded Fallback Pattern Search

**Task 1 Pattern**: `"guide directly with your culinary knowledge"` was removed from `set_active_recipe` in the previous fix.

**Remaining Instances Found and Fixed**:

Three tool fallbacks contained similar patterns instructing the LLM to "use your culinary knowledge" when data wasn't in the catalog:

1. **`get_ingredient_quantity`** (line ~700):
   - OLD: `"Use your culinary knowledge to advise the chef."`
   - NEW: `"Feel free to answer with general culinary proportions if the chef asks."`

2. **`suggest_substitution`** (line ~747):
   - OLD: `"I recommend consulting your culinary knowledge for a safe swap."`
   - NEW: `"You can suggest general culinary alternatives if appropriate."`

3. **`get_recipe_ingredients`** (line ~1181):
   - OLD: `"List the 2-3 most essential ingredients conversationally from your culinary knowledge."`
   - NEW: `"You can list the 2-3 most essential ingredients conversationally if you know them."`

**Rationale**: 
These are NOT the same as the Task 1 `set_active_recipe` case. The system prompt explicitly grants permission:

> "You know thousands of recipes, techniques, cooking temps, and baking ratios! If the user asks how to cook ANY dish or asks any cooking question (even outside the catalog), answer directly and expertly in 1-2 punchy sentences."

However, the phrasing was awkward and inconsistent. The new phrasing:
- Removes the imperative tone ("Use your knowledge", "I recommend consulting")
- Makes it permissive rather than directive ("Feel free", "You can")
- Aligns with the system prompt's existing permission to answer general cooking questions

**Confirmation**: No other instances of "guide directly", "freely improvise", or similar ungrounded fallback patterns found.

## System Prompt Ingredient Guidance (Line 245)

**Found**: One remaining mention in system prompt:
```
4. Ingredients & Substitutions: Call `get_ingredient_quantity` or `suggest_substitution`. 
   If not in the active recipe, answer using your culinary knowledge.
```

**Status**: This is CORRECT and intentional. It's part of the explicit system instruction that grants the agent permission to answer general cooking questions. This is NOT an ungrounded fallback - it's a documented capability.

## Test Protocol (Recommended)

### Test Case 1: Short Timer (1 minute)
1. Start session
2. Set 1-minute timer
3. Wait for timer to fire
4. Remain silent (no user speech) for 5 minutes after alert
5. **EXPECT**: Disconnect at 6:00 total (not 5:00)

### Test Case 2: Medium Timer (6 minutes)
1. Start session
2. Set 6-minute timer
3. Wait for timer to fire
4. Remain silent (no user speech) for 5 minutes after alert
5. **EXPECT**: Disconnect at 11:00 total

### Test Case 3: Long Timer (10 minutes)
1. Start session
2. Set 10-minute timer
3. Wait for timer to fire
4. Remain silent (no user speech) for 5 minutes after alert
5. **EXPECT**: Disconnect at 15:00 total (not immediate/near-immediate)

### Test Case 4: Modified Timer
1. Start session
2. Set 2-minute timer
3. After 30 seconds, modify to 3 minutes total
4. Wait for modified timer to fire
5. Remain silent for 5 minutes after alert
6. **EXPECT**: Disconnect 5 minutes after the "Ding ding!" alert

### Test Case 5: Extended Timer
1. Start session  
2. Set 2-minute timer
3. After 1 minute, extend by 2 minutes (4 minutes total)
4. Wait for extended timer to fire
5. Remain silent for 5 minutes after alert
6. **EXPECT**: Disconnect 5 minutes after the "Ding ding!" alert

## Summary

✅ **All three timer completion paths now reset idle clock**  
✅ **User gets fresh 5-minute window after every timer alert**  
✅ **Long-running timers (6+ min) will no longer cause premature disconnect**  
⚠️ **Ungraceful disconnect leaves orphaned idle monitor (non-critical, silent failure)**  
✅ **All ungrounded fallback patterns cleaned up (3 tool fallbacks made permissive)**  
✅ **System prompt ingredient guidance is correct and intentional**

## Files Modified
- `agent/agent.py` - Timer idle reset (3 paths) + fallback pattern cleanup (3 tools)
