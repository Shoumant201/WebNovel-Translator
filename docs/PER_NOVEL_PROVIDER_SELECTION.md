# Per-Novel Translation Provider Selection

## Overview

You can now choose which translation provider to use for each novel individually! This lets you:
- Use **DeepL** for your favorite novels (best quality)
- Use **Microsoft** for regular reading (great quality, huge quota)
- Use **Google** or **LibreTranslate** for specific needs
- Let the system **auto-select** (smart fallback) for most novels

## How It Works

### Step 1: Configure Your Providers

First, set up your API keys in **Settings** (see [MULTI_PROVIDER_TRANSLATION_SETUP.md](MULTI_PROVIDER_TRANSLATION_SETUP.md)):

1. Open Settings (gear icon)
2. Configure Microsoft Translator
3. Configure DeepL
4. (Optional) Configure Google Translate

### Step 2: Choose Provider Per Novel

For each novel, you can now select which provider to use:

1. **Open a novel** from your library
2. Scroll to the **"Translation Provider"** dropdown
3. **Select your preferred provider**:
   - **Auto (Smart Fallback)** - Default, tries Microsoft → Google → DeepL → LibreTranslate
   - **Microsoft Translator** - Always use Microsoft (2M chars/month)
   - **Google Translate** - Always use Google (500K chars/month)
   - **DeepL (Best Quality)** - Always use DeepL (500K chars/month, highest quality)
   - **LibreTranslate** - Use public LibreTranslate instances
4. **Done!** All future chapters will use your selected provider

## Use Cases

### Use Case 1: Favorite Novel with Best Quality

**Scenario**: You're reading "Reverend Insanity" and want the absolute best translation.

**Solution**:
1. Open the novel
2. Select **"DeepL (Best Quality)"**
3. All chapters now use DeepL (9.5/10 quality)

**Result**: Maximum translation quality for your favorite novel!

### Use Case 2: Multiple Novels, Different Priorities

**Scenario**: You're reading 3 novels simultaneously.

**Setup**:
- **Novel A** (favorite): DeepL
- **Novel B** (good): Microsoft
- **Novel C** (casual): Auto

**Result**: 
- Best quality for your favorite
- Balanced quality/quota for others
- Maximum flexibility

### Use Case 3: Maximize Quota

**Scenario**: You read 800+ chapters/month and need to spread across providers.

**Strategy**:
- **Novels 1-3**: Microsoft (uses 2M quota)
- **Novels 4-5**: DeepL (uses 500K quota)
- **Novels 6-7**: Google (uses 500K quota)
- **Others**: Auto (LibreTranslate fallback)

**Result**: 3M+ chars/month = 600-1000 chapters!

### Use Case 4: Testing Providers

**Scenario**: You want to compare translation quality.

**Method**:
1. Add same novel twice (from chapter 1)
2. Set Novel A to Microsoft
3. Set Novel B to DeepL
4. Compare translations side-by-side

**Result**: See which provider you prefer!

## Provider Comparison Quick Reference

| Provider | When to Use | Pros | Cons |
|----------|-------------|------|------|
| **Auto** | Default, most novels | Smart fallback, never fails | Not predictable |
| **Microsoft** | Regular reading, large quota | 2M/month, good quality (8.5/10) | Not quite as natural as DeepL |
| **Google** | Backup, specific needs | Reliable, 500K/month | Medium quota |
| **DeepL** | Favorites, best quality | Highest quality (9.5/10) | Smaller quota (500K/month) |
| **LibreTranslate** | No API keys, or testing | Free, unlimited | Lower quality, unreliable |

## How Provider Selection Works

### Auto Mode (Default)

```
Chapter needs translation
    ↓
Try Microsoft (if configured)
    ↓ Failed or not configured?
Try Google (if configured)
    ↓ Failed or not configured?
Try DeepL (if configured)
    ↓ Failed or not configured?
Try LibreTranslate (public instances)
    ↓ All failed?
Show error
```

### Specific Provider Selected

```
Chapter needs translation
    ↓
Try SELECTED provider (e.g., DeepL)
    ↓ Success? → Done! ✅
    ↓ Failed?
Fall back to Auto mode
```

**Note**: If your selected provider fails (quota exceeded, API error, etc.), the system will automatically fall back to other providers to ensure your chapter still gets translated.

## Visual Guide

### What You'll See

In the novel detail screen, below the "Auto-fetch" toggle:

```
┌─────────────────────────────────────┐
│ Translation Provider                 │
│ Choose which translation service to  │
│ use for this novel                   │
│                                      │
│ ┌────────────────────────────────┐ │
│ │ 🔵 Microsoft Translator      ▼│ │
│ └────────────────────────────────┘ │
└─────────────────────────────────────┘
```

When you click the dropdown:

```
┌────────────────────────────────────┐
│ ⚙️  Auto (Smart Fallback)         │
│ 🔵 Microsoft Translator           │
│ 🔴 Google Translate               │
│ 🟣 DeepL (Best Quality)           │
│ 🟢 LibreTranslate                 │
└────────────────────────────────────┘
```

## Strategies for Different Reading Habits

### Light Reader (< 200 chapters/month)

**Recommendation**: Set all novels to **DeepL**
- Highest quality
- Won't exceed 500K quota
- Best experience

### Medium Reader (200-600 chapters/month)

**Recommendation**: 
- Important novels: **DeepL**
- Regular novels: **Microsoft**
- Casual novels: **Auto**

**Result**: Balanced quality and quota

### Heavy Reader (600+ chapters/month)

**Recommendation**:
- First 400 chapters: **Microsoft** (2M quota)
- Next 100 chapters: **DeepL** (500K quota)
- Next 100 chapters: **Google** (500K quota)
- Extra: **Auto** (LibreTranslate)

**Result**: Maximum capacity

## Technical Details

### Database Schema

Each novel now has a `preferredTranslationProvider` field:
- `null` - Auto mode (default)
- `'microsoft'` - Microsoft Translator
- `'google'` - Google Translate
- `'deepl'` - DeepL
- `'libretranslate'` - LibreTranslate

### Migration

The database automatically migrates to add this field:
- Existing novels default to `null` (Auto mode)
- No data loss
- Works seamlessly

### Priority Logic

When translating with a specific provider:

1. **Try selected provider first**
2. **If fails**, fall back to Auto mode
3. **Ensure translation always succeeds** (if any provider works)

## Benefits

### For Users

✅ **Full control** over translation quality per novel
✅ **Optimize quota usage** across multiple novels
✅ **Best quality for favorites** using DeepL
✅ **Maximize capacity** by spreading across providers
✅ **Flexibility** to change anytime

### For the App

✅ **Better user experience** with customization
✅ **Smart resource management** 
✅ **Quota optimization** across novels
✅ **Graceful fallback** ensures reliability

## FAQ

### Q: What happens if I select DeepL but don't have a DeepL API key?

**A**: The system will automatically fall back to Auto mode and try other providers. You'll still get a translation.

### Q: Can I change the provider mid-novel?

**A**: Yes! Change anytime. Future chapters use the new provider, already-translated chapters stay as-is.

### Q: Does this affect already-translated chapters?

**A**: No. Only new chapters use the selected provider. Already-translated chapters remain unchanged.

### Q: What if I select Microsoft but it hits quota limit?

**A**: The system automatically falls back to other providers (Google → DeepL → LibreTranslate) to ensure translation succeeds.

### Q: Which should I choose for Chinese novels?

**A**: 
- **Best quality**: DeepL
- **Best balance**: Microsoft
- **Most quota**: Microsoft
- **My recommendation**: Microsoft for most, DeepL for favorites

### Q: Can I use different providers for different chapters of the same novel?

**A**: The provider setting is per-novel, not per-chapter. All future chapters use the current setting, but you can change it anytime.

## Example Setups

### Setup 1: Quality-Focused

```
Novel: "Lord of the Mysteries" → DeepL
Novel: "Reverend Insanity" → DeepL
Novel: "Warlock of the Magus World" → DeepL
Others → Auto
```

**Good for**: 3-5 favorite novels, prioritizing quality

### Setup 2: Quantity-Focused

```
All novels → Microsoft
(Use 2M quota across all)
When Microsoft exhausted → Auto
```

**Good for**: Reading many novels, want consistent quality

### Setup 3: Hybrid

```
Top 3 novels → DeepL
Next 5 novels → Microsoft
Others → Google or Auto
```

**Good for**: Balanced approach, mix of quality and capacity

## Troubleshooting

### Provider not working

1. **Check Settings**: Verify API key is configured
2. **Test Connection**: Use "Save & Test" in Settings
3. **Check Quota**: You may have exhausted monthly limit
4. **Try Auto**: System will find working provider

### Dropdown not showing

1. **Update app**: Make sure you have latest version
2. **Restart app**: Close and reopen
3. **Check novel screen**: Should be below "Auto-fetch" toggle

### Translation fails even with provider selected

1. **Check internet**: Verify connection
2. **Verify API keys**: Go to Settings and test
3. **Try Auto mode**: See if any provider works
4. **Check quotas**: Providers may be exhausted

## Summary

**Per-novel provider selection gives you**:

🎯 **Control**: Choose quality vs quota for each novel
💎 **Quality**: Use DeepL for favorites
⚡ **Capacity**: Spread across providers for 600+ chapters/month
🔄 **Flexibility**: Change anytime
🛡️ **Reliability**: Auto-fallback ensures success

**Bottom line**: Maximum flexibility to optimize translation quality and quota across all your novels! 🚀

---

See also:
- [MULTI_PROVIDER_TRANSLATION_SETUP.md](MULTI_PROVIDER_TRANSLATION_SETUP.md) - How to configure providers
- [TRANSLATION_ALTERNATIVES.md](TRANSLATION_ALTERNATIVES.md) - Provider comparison details
