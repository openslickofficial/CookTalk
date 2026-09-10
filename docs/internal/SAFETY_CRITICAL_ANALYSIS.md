# CookTalk Safety-Critical Analysis & Fixes

## TASK 1: ORPHANED MONITOR FIX

### Current Code Analysis (Lines 457-492)

```python
async def _idle_monitor_loop():
    logger.info(f"[IDLE MONITOR] Started. Timeout: {self._idle_timeout_seconds}s (no speech + no timers).")
    while True:
        try:
            await asyncio.sleep(30.0)  # Check every 30 seconds
            
            # If active timers running, NOT idle (even if no speech)
            if self.active_timers:
                continue
            
            # Calculate idle duration since last user speech
            idle_duration = time.time() - self._last_user_speech_time
            
            # If exceeded threshold with no timers, disconnect
            if idle_duration >= self._idle_timeout_seconds:
                logger.warning(f"[IDLE MONITOR] Session idle for {idle_duration:.1f}s with no active timers. Ending session.")
                
                if self.session:
                    try:
                        await self.session.say(
                            "Hey Chef, you've been quiet for a while and no timers are running. I'm closing this session to save resources. Come back anytime!",
                            allow_interruptions=False,
                            add_to_chat_ctx=True,
                        )
                        await asyncio.sleep(2.0)  # Let message finish
                    except Exception as e:
                        logger.debug(f"[IDLE MONITOR] Could not speak goodbye: {e}")
                
                await self.broadcast({
                    "type": "session_ended",
                    "message": "Session ended due to inactivity",
                    "reason": "idle_timeout"
                })
                
                # Signal session should close
                break  # ← EXITS WHILE LOOP
                
        except asyncio.CancelledError:
            logger.info("[IDLE MONITOR] Monitor cancelled.")
            break  # ← EXITS WHILE LOOP
        except Exception as e:
            logger.debug(f"[IDLE MONITOR] Check error: {e}")
            # ← NO BREAK - CONTINUES LOOPING
```

### Critical Question: Does Loop Terminate After Failed `session.say()`?

**ANSWER: YES, the loop DOES terminate correctly.**

**Traced execution path:**

1. At 5-minute mark, `idle_duration >= 300.0` evaluates to True
2. Enters the disconnect block (line 471)
3. Attempts `await self.session.say(...)`
4. **If `session.say()` raises exception:**
   - Inner try/except catches it (line 483)
   - Logs debug message
   - **Execution continues to line 485** (outside inner try/except)
5. **Executes `await self.broadcast({...})` at line 485** (may also fail, but not caught)
6. **Executes `break` at line 491**
7. **Loop terminates**

**Key insight**: The `try/except` wrapping `session.say()` is INSIDE the disconnect block. The `break` statement at line 491 is OUTSIDE that inner try/except, so it ALWAYS executes regardless of whether the speech succeeded or failed.

**Therefore: The orphaned monitor concern does NOT manifest in this code path. The monitor will terminate cleanly.**

### Real Problem: Ungraceful Disconnects

**However**, the monitor is NOT stopped on ungraceful disconnect (connection drop, app force-quit).

Current code (line 1860):
```python
await session.start(room=ctx.room, agent=agent)
logger.info("CookTalk AgentSession started and ready for speech.")

# TASK 2: Start idle session monitor
copilot.start_idle_monitor()
```

If session dies due to connection drop:
- `stop_idle_monitor()` is ONLY called in `end_session()` tool (explicit user goodbye)
- NOT called on connection failure
- Orphaned task may attempt `session.say()` on dead session → exception logged but no crash

**Risk Level: LOW** - Exception is caught, task will eventually exit, no memory leak or crash. But cleanup is delayed.

---

## TASK 2: ALLERGY FILTERING ON FALLBACK PATH

### Code Analysis: `suggest_substitution()` (Lines ~695-743)

```python
@llm.function_tool
@track_tool
async def suggest_substitution(ingredient_name: str) -> str:
    """Suggest substitution for an ingredient in active recipe or any general culinary ingredient."""
    recipe = copilot.active_recipe
    target = ingredient_name.strip().lower()
    
    # Build list of candidate substitutions
    candidates = []
    substitutions = recipe.get("substitutions", {})
    for ing_key, sub_val in substitutions.items():
        if target in ing_key.lower() or ing_key.lower() in target:
            # Parse multiple options if comma-separated
            candidates.extend([s.strip() for s in sub_val.split(",")])
            break
    
    # If no preset, check other recipes
    if not candidates:
        for r_id, r in copilot.recipes.items():
            for ing_key, sub_val in r.get("substitutions", {}).items():
                if target in ing_key.lower() or ing_key.lower() in target:
                    candidates.extend([s.strip() for s in sub_val.split(",")])
                    break
            if candidates:
                break
    
    # Apply Allergy Safeguard filter
    if copilot.user_allergies and candidates:
        safe_options, blocked = copilot.filter_substitutions(candidates)
        
        if not safe_options:
            # All options blocked - immediate safety warning
            warning_msg = f"All substitutions for {ingredient_name} contain allergens from your profile. Recommend alternatives: use olive oil, vegetable oil, or water-based substitutes depending on the recipe."
            logger.warning(f"[ALLERGY SAFEGUARD] All {ingredient_name} substitutions blocked")
            return warning_msg
        
        if blocked:
            # Some options blocked - return only safe ones
            logger.info(f"[ALLERGY SAFEGUARD] Filtered substitutions for {ingredient_name}: Safe={safe_options}, Blocked={blocked}")
            candidates = safe_options
    
    # Return filtered safe substitutions
    if candidates:
        options_str = " or ".join(candidates[:3])  # Limit to 3 options for voice clarity
        return f"For {ingredient_name}: try {options_str}"
    
    # ← FALLBACK PATH: No grounded data, delegates to LLM
    return f"No preset substitution found for {ingredient_name}. You can suggest general culinary alternatives if appropriate."
```

### Critical Issue: ALLERGY FILTER BYPASSED ON FALLBACK

**ANSWER: YES, allergy filter is COMPLETELY BYPASSED when falling back to LLM knowledge.**

**Execution trace when ingredient NOT in catalog:**

1. `candidates` remains empty (line 700, 707, 716 all fail to match)
2. Allergy filter block (line 719) checks `if copilot.user_allergies and candidates:`
3. **`candidates` is empty**, so filter is SKIPPED entirely
4. Executes fallback return at line 743: `"No preset substitution found..."`
5. **This string is returned to LLM**
6. **LLM improvises substitution using general knowledge**
7. **LLM's improvised answer goes directly to TTS → spoken to user**
8. **NO ALLERGEN CHECK OCCURS**

### Real-World Risk Scenario

**User**: "What can I substitute for butter in my brownies?"
- User profile: Severe milk allergy
- "brownies" not in recipe catalog
- `suggest_substitution("butter")` finds no candidates
- Returns to LLM: "No preset substitution found for butter. You can suggest general culinary alternatives if appropriate."
- LLM responds: "Try ghee, yogurt, or cream cheese"
- **ALL THREE CONTAIN MILK**
- **User with milk allergy is told to use milk products**

**THIS IS THE EXACT SAFETY FAILURE THE SAFEGUARD WAS DESIGNED TO PREVENT.**

---

## TASK 3: GROUNDING SIGNAL MISSING ON FALLBACK

### Current Fallback Returns (No Uncertainty Disclosure)

**`get_ingredient_quantity()` - Line ~692:**
```python
return f"{ingredient_name.title()} is not in the active recipe. Feel free to answer with general culinary proportions if the chef asks."
```
- Delegates to LLM
- LLM answers with confidence
- NO signal that answer is ungrounded

**`suggest_substitution()` - Line ~743:**
```python
return f"No preset substitution found for {ingredient_name}. You can suggest general culinary alternatives if appropriate."
```
- Delegates to LLM
- LLM improvises substitution
- NO safety check (see Task 2)
- NO uncertainty disclosure

**`get_recipe_ingredients()` - Line ~1263:**
```python
return f"Dish '{recipe_name_or_id}' is not in the preset card catalog. You can list the 2-3 most essential ingredients conversationally if you know them."
```
- Delegates to LLM
- LLM answers with confidence
- NO signal that answer is ungrounded

### Comparison with Grounded Answers

**When recipe IS in catalog:**
```python
return f"For {recipe['name']}, you need {ing['quantity']} {ing['unit']} of {ing['name']}."
```
- Confident, factual
- Backed by structured data

**When recipe is NOT in catalog:**
```python
return f"Feel free to answer with general culinary proportions if the chef asks."
```
- NO epistemic marker
- LLM answers with same confidence level
- User cannot distinguish grounded from improvised

### Why This Matters

The project ALREADY uses disclosure patterns elsewhere:
- Timer confirmations for critical values (Task 5)
- Safety warnings with disclaimers ("best-effort check")
- Connection issue notices (Task 7)

**These three tools are the ONLY place where ungrounded answers are delivered with the same confidence as grounded facts.**

---

## FIXES REQUIRED

### Fix 1: Wrap Entrypoint in try/finally

**Location**: Line 1854
**Change**: Ensure `stop_idle_monitor()` runs on ALL exit paths

### Fix 2: Apply Allergy Filter to LLM-Generated Substitutions

**Location**: `suggest_substitution()`, after LLM generates response
**Change**: Parse LLM response, extract ingredient names, run through `check_ingredient_safety()`

### Fix 3: Add Uncertainty Disclosure to Fallback Responses

**Location**: All three fallback return statements
**Change**: Prepend uncertainty marker like "I don't have that one saved, but generally..."

---

**Status**: Analysis complete. Ready to implement fixes.
