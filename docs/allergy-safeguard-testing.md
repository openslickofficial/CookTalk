# Allergy Safeguard Testing Guide

**Purpose**: Verify that the Dietary & Pantry Allergy Safeguard system is correctly filtering dangerous ingredients in live cooking sessions.

---

## 🧪 **Pre-Test Setup**

### **Step 1: Configure User Allergies**

1. Open CookTalk mobile app
2. Navigate to **Profile** tab
3. Tap **"Allergy Safeguard"**
4. Select test allergies:
   - ✅ **Dairy** (for testing cream/butter substitutions)
   - ✅ **Peanuts** (for testing explicit safety checks)
   - ✅ **Tree Nuts** (for testing almond/cashew filtering)
5. Tap **"Save 3 Allergies"**

### **Step 2: Verify Profile Saved**

- Profile screen should show: **"3 allergies configured"**
- Check Supabase dashboard: `profiles` table should have `allergies` column populated

---

## ✅ **Test Suite**

### **Test 1: Profile Transmission (Session Start)**

**Objective**: Verify allergies are sent to agent on connection

**Steps**:
1. Select any recipe (e.g., "Cacio e Pepe")
2. Tap **"Start Cooking Assistant"**
3. Wait for connection
4. Check debug logs

**Expected Output (Mobile)**:
```
[InSession] ⚠️ ALLERGY SAFEGUARD ACTIVE: 3 allergies configured: Dairy, Peanuts, Tree Nuts
```

**Expected Output (Agent Logs)**:
```bash
lk agent logs --log-type=runtime | Select-String "ALLERGY"
```
Should show:
```
[ALLERGY SAFEGUARD] Loaded dietary profile: Allergies=['dairy', 'peanuts', 'tree nuts']
```

**Status**: ⬜ Pass / ⬜ Fail

---

### **Test 2: Visual Indicator in Live Session**

**Objective**: Verify UI shows allergy safeguard badge

**Steps**:
1. In live cooking session
2. Look below status line ("Agent connected • Speak naturally...")

**Expected**:
- Red badge visible: 🛡️ **"Allergy Safeguard Active (3)"**
- Border: Light red
- Icon: health_and_safety_rounded

**Status**: ⬜ Pass / ⬜ Fail

---

### **Test 3: Substitution Filtering (Automatic)**

**Objective**: Verify dangerous substitutions are filtered out

**Test Query**: *"I don't have heavy cream, what can I use?"*

**Setup**:
- User Profile: Dairy allergy, Tree Nut allergy
- Expected Candidates: Coconut cream, Oat milk, Almond milk, Cashew cream

**Expected Agent Response**:
- ✅ Suggests: "For heavy cream, try coconut cream or oat milk"
- ❌ Does NOT suggest: Almond milk, Cashew cream (tree nut allergy)
- ❌ Does NOT suggest: Regular cream, Milk (dairy allergy)

**Agent Logs Should Show**:
```
[ALLERGY SAFEGUARD] Filtered substitutions for heavy cream: 
  Safe=['coconut cream', 'oat milk'], 
  Blocked=['almond milk (blocked: allergy)', 'cashew cream (blocked: allergy)']
```

**Status**: ⬜ Pass / ⬜ Fail

---

### **Test 4: Explicit Safety Check (User Proposes Danger)**

**Objective**: Verify immediate warning when user suggests allergen

**Test Query**: *"Can I use peanut butter instead?"*

**Setup**:
- User Profile: Peanut allergy

**Expected Agent Response**:
- 🚨 Immediate voice warning
- Text: *"Caution: Your profile lists a severe peanut allergy. Do NOT use peanut butter."*
- Spoken via Rime TTS with urgency

**Agent Logs Should Show**:
```
[ALLERGY SAFEGUARD] 🚨 USER PROPOSED DANGEROUS INGREDIENT: peanut butter
[ALLERGY SAFEGUARD] ⚠️ BLOCKED dangerous ingredient: peanut butter (allergen: peanuts)
```

**Status**: ⬜ Pass / ⬜ Fail

---

### **Test 5: All Options Blocked (Fail-Safe)**

**Objective**: Verify graceful handling when all substitutions are allergens

**Test Query**: *"What can I use instead of butter?"*

**Setup**:
- User Profile: Dairy allergy, Soy allergy
- Common butter substitutes: Ghee (dairy), Margarine (dairy/soy), Vegan butter (soy)

**Expected Agent Response**:
- ✅ Suggests generic safe alternatives
- Text: *"All standard butter substitutes contain allergens. Use olive oil or coconut oil."*

**Agent Logs Should Show**:
```
[ALLERGY SAFEGUARD] All butter substitutions blocked
```

**Status**: ⬜ Pass / ⬜ Fail

---

### **Test 6: No Allergies Configured (Control)**

**Objective**: Verify system works normally without allergies

**Setup**:
1. Go to Profile → Allergy Safeguard
2. Deselect all allergies
3. Tap "Skip (No Allergies)"

**Test Query**: *"What can I use instead of heavy cream?"*

**Expected Agent Response**:
- ✅ Suggests full range of options
- Text: *"For heavy cream, try almond milk, coconut cream, or oat milk"*
- No filtering applied

**Mobile Logs Should Show**:
```
[InSession] No allergies configured for this user
```

**Agent Logs Should Show**:
```
[ALLERGY SAFEGUARD] Loaded dietary profile: Allergies=[]
```

**Live Session UI**:
- ❌ No allergy safeguard badge visible

**Status**: ⬜ Pass / ⬜ Fail

---

### **Test 7: Partial Matching (Edge Case)**

**Objective**: Verify allergen matching works with partial names

**Test Queries**:
- *"Can I use almond extract?"* (should catch "almond" in "Tree Nuts")
- *"What about dairy-free milk?"* (should NOT catch "dairy" in "dairy-free")
- *"Can I use peanut oil?"* (should catch "peanut" in "Peanuts")

**Setup**:
- User Profile: Peanuts, Tree Nuts, Dairy

**Expected Behavior**:
- "almond extract" → ⚠️ WARNING (tree nut allergen detected)
- "dairy-free milk" → ✅ SAFE (negative match, not actual dairy)
- "peanut oil" → ⚠️ WARNING (peanut allergen detected)

**Status**: ⬜ Pass / ⬜ Fail

---

### **Test 8: Case Insensitivity**

**Objective**: Verify matching works regardless of case

**Test Queries**:
- *"Can I use PEANUT butter?"* (uppercase)
- *"What about Almond Milk?"* (title case)
- *"Can I use dairy?"* (lowercase)

**Setup**:
- User Profile: Peanuts, Tree Nuts, Dairy

**Expected**:
- All queries should trigger warnings
- Case should not affect allergen detection

**Status**: ⬜ Pass / ⬜ Fail

---

## 🔍 **Debug Commands**

### **Check Mobile Logs**
```bash
# Android Studio Logcat
adb logcat -s flutter

# Filter for allergy-related logs
adb logcat | grep -i "allergy\|safeguard"
```

### **Check Agent Logs**
```powershell
# Real-time agent logs
lk agent logs --log-type=runtime

# Filter for allergy safeguard
lk agent logs --log-type=runtime | Select-String "ALLERGY"
```

### **Verify Profile in Supabase**
```sql
SELECT full_name, allergies FROM profiles WHERE id = '<user_id>';
```

---

## 📊 **Test Results Summary**

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | Profile Transmission | ⬜ | |
| 2 | Visual Indicator | ⬜ | |
| 3 | Substitution Filtering | ⬜ | |
| 4 | Explicit Safety Check | ⬜ | |
| 5 | All Options Blocked | ⬜ | |
| 6 | No Allergies Control | ⬜ | |
| 7 | Partial Matching | ⬜ | |
| 8 | Case Insensitivity | ⬜ | |

---

## 🐛 **Known Issues / Limitations**

1. **False Negatives**: Complex ingredient names might not match (e.g., "milk solids" vs "dairy")
2. **Cross-Contamination**: System doesn't warn about "may contain traces"
3. **Cultural Variations**: Ingredient names vary by region
4. **Compound Ingredients**: "Butter extract" might not catch "dairy"

---

## ✅ **Acceptance Criteria**

System is considered **production-ready** if:
- ✅ All 8 tests pass
- ✅ No false positives (safe ingredients blocked)
- ✅ No false negatives (dangerous ingredients allowed)
- ✅ Visual indicator displays correctly
- ✅ Agent logs show filtering activity
- ✅ User receives voice warnings for explicit dangers

---

## 🚀 **Performance Benchmarks**

- **Profile Load Time**: < 50ms
- **Filter Execution**: < 1ms (in-memory string matching)
- **Warning Latency**: < 100ms (from detection to Rime synthesis)
- **Memory Overhead**: < 1KB per session

---

**Test Date**: _____________  
**Tester**: _____________  
**Agent Version**: _____________  
**Mobile App Version**: _____________  
**Overall Result**: ⬜ PASS / ⬜ FAIL
