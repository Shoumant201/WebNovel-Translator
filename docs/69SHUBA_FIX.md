# Fix for HTTP 403 Error on 69shuba

## Problem
When attempting to fetch chapters from 69shuba.com, the app was receiving HTTP 403 (Forbidden) errors. This is due to anti-bot protection on the 69shuba website.

## Solution
I've implemented the following changes to fix the HTTP 403 error:

### 1. Created a dedicated 69shuba parser
**File: `lib/services/scrapers/shuba69_parser.dart`**

This new parser:
- Specifically handles 69shuba.com and its variants (www.69shu.com, m.69shu.com)
- Extracts chapter content using common 69shuba HTML selectors
- Finds "next chapter" links using Chinese text patterns (下一章, 下一页)
- Cleans up site-specific advertisements and noise from the content
- Uses multiple fallback strategies to find content if primary selectors fail

### 2. Enhanced HTTP headers to bypass anti-bot protection
**File: `lib/services/chapter_fetch_service.dart`**

Added the `_buildHeaders()` method that:
- Includes comprehensive browser-like headers (Accept-Language, Accept-Encoding, etc.)
- Adds site-specific headers for 69shuba:
  - `Referer: https://www.69shu.com/`
  - `Origin: https://www.69shu.com`
- Uses security-related headers (Sec-Fetch-*) that modern browsers send

### 3. Added FetchStrategy enum value
**File: `lib/models/enums.dart`**

Added `shuba69` to the `FetchStrategy` enum to track when the 69shuba parser is used.

### 4. Registered the new parser
The Shuba69Parser is now registered in the `_parsers` list in `ChapterFetchService`.

## How the Fix Works

The HTTP 403 error typically occurs when:
1. The website detects non-browser User-Agent headers
2. Missing standard browser headers (Referer, Origin)
3. Missing security headers that modern browsers send

Our fix addresses all these issues by:
- Using a realistic Chrome User-Agent
- Adding all standard browser headers
- Including 69shuba-specific Referer and Origin headers
- Adding modern security headers (Sec-Fetch-*)

## Testing

To test the fix:

1. Make sure dependencies are up to date:
   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```

2. Run the app:
   ```bash
   flutter run
   ```

3. Try fetching a chapter from 69shuba.com:
   - Paste a 69shuba chapter URL
   - The app should now successfully fetch the content without HTTP 403 errors

## Expected Behavior

- **Before**: HTTP 403 error when fetching from 69shuba
- **After**: Successfully fetches chapter content with proper title, body text, and next chapter link

## Additional Notes

- The parser handles multiple 69shuba domain variants automatically
- Content cleaning removes common 69shuba advertisements and site-specific text
- The parser falls back to generic content extraction if specific selectors fail
- Chinese text patterns are used for finding "next chapter" links (下一章, 下一页)

## If Issues Persist

If you still experience HTTP 403 errors, you can use the **Manual Extraction** feature:

### Manual Extraction Fallback

1. When a chapter fails with HTTP 403, click the **web icon** button (or "Manual Extract" in reader)
2. The chapter URL will open in a built-in browser
3. Navigate as needed (handle cookies, redirects, etc.)
4. Click the **"Extract Chapter"** button at the bottom
5. Content will be automatically extracted and translated

This works because the WebView acts like a real browser with cookies and JavaScript support, bypassing anti-bot protection. See [MANUAL_EXTRACT_FEATURE.md](MANUAL_EXTRACT_FEATURE.md) for full details.

### Other Options if Both Methods Fail

If automatic fetch AND manual extraction both fail, it might be due to:

1. **IP-based rate limiting**: Try waiting a few minutes between requests
2. **Additional anti-bot measures**: The site may have added new protections
3. **Cloudflare or similar CDN protection**: May require more advanced bypass techniques

In these cases, you might need to:
- Add delays between requests
- Implement cookie handling
- Use a proxy service
- Consider using a headless browser approach (Selenium/Puppeteer)

## Technical Details

### Header Strategy
```dart
'User-Agent': Standard Chrome UA
'Accept': HTML content types
'Accept-Language': English + Chinese
'Accept-Encoding': gzip, deflate, br
'Referer': https://www.69shu.com/ (for 69shuba)
'Origin': https://www.69shu.com (for 69shuba)
'Sec-Fetch-*': Modern browser security headers
```

### Content Extraction Strategy
1. Try specific 69shuba selectors (.txtnav, #content, etc.)
2. Look for paragraph tags within containers
3. Fall back to finding largest text block with low link density
4. Clean extracted content of ads and site-specific noise
5. Extract "next chapter" links using Chinese text patterns

