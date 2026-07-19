# 69shuba Parser Improvements

## Issues Fixed

### 1. Cluttered Content with HTML/Ads
**Problem**: Fetched chapters contained full HTML including navigation, ads, scripts, and metadata.

**Solution**:
- Enhanced `_removeNoise()` to remove more ad elements (contentadv, bottom-ad, ad iframes, SSP ads)
- Changed `_extractFromTxtnav()` to use innerHTML parsing instead of DOM walking
- Added `_decodeHtmlEntities()` to handle escaped HTML characters
- Improved `_cleanContent()` to remove JavaScript variables, dates, author lines, and watermarks
- Filter out empty lines during cleanup

### 2. Next Button Greyed Out
**Problem**: Next chapter button disabled because `nextChapterUrl` wasn't being extracted.

**Solution**: The `_findNextChapterLink()` method already has 3 fallback strategies:
1. Look for links with "下一章" text in `.page1` navigation
2. Parse JavaScript `bookinfo` object for `next_page` property
3. Scan all links for "下一章" or "下一页" text

This should work correctly. If still failing, the issue may be:
- The manual WebView extraction not preserving `nextChapterUrl`
- Database not storing the field properly

## Content Cleaning Rules

The parser now removes:
- All HTML tags after converting `<br>` to newlines
- Scripts, styles, iframes, ad containers
- Site watermarks (69书吧, www.69shuba.com)
- JavaScript code blocks
- Date/time stamps
- "作者：" (author) lines
- Chapter title repeats
- Multiple consecutive blank lines
- Common noise phrases ("小贴士", "请记住", etc.)

## Testing

To test the improved parser:
1. Rebuild app: `flutter build apk --release`
2. Install on device
3. Try fetching a 69shuba chapter using manual extraction
4. Verify:
   - Chapter content is clean (no HTML/ads)
   - Text is properly formatted with paragraph breaks
   - Next button is enabled
   - Can navigate to next chapter

## Known Limitations

- The parser assumes content is in `.txtnav` element
- If 69shuba changes their HTML structure, parser may need updates
- Manual extraction via WebView should work even if anti-bot protection blocks HTTP fetching
