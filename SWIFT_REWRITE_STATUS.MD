# Bangumi Native iOS Rewrite Status

This workspace now boots into a native SwiftUI shell instead of the React Native root view.

Current implementation:

- Native `AppDelegate` entrypoint with a SwiftUI root controller
- Shared app container with auth, API, settings, timeline, rakuen, subject, discovery, and user repositories
- `ASWebAuthenticationSession` OAuth skeleton plus manual access token sign-in fallback
- Native tabs for Home, Discovery, Rakuen, and Me
- Home-first landing experience that replaces the old Timeline tab with a native progress homepage
- Authenticated home sections for anime / book / real / game progress, plus a guest-mode homepage backed by discovery calendar data
- Home sections use cover-driven horizontal rails inspired by the original `home/v2` screen
- Native search sheet and native subject detail / episode list
- Read-only native Timeline and Rakuen lists backed by lightweight HTML parsing
- Read-only native timeline detail / reply reader
- Read-only native Rakuen topic detail / comment reader
- Basic nested Rakuen sub-reply rendering
- Native rich text rendering for timeline and Rakuen detail bodies
- Inline quote blocks and image previews for parsed HTML content
- Full-screen native image preview for parsed inline images
- Internal Bangumi links now route to native subject, timeline, Rakuen, and user surfaces when available
- Read-only native user profile screen with profile header and watching collections
- Shared card styling and improved accessibility labels for toolbar actions
- WebView fallback for timeline replies, topic sub-replies, posting, and other complex community interactions
- Keychain-backed session storage
- URL cache cleanup and recent-search persistence

Deferred work:

- More original-home behaviors such as richer next-step actions and denser progress metadata
- Stronger Timeline / Rakuen parser coverage against more page variants
- Richer timeline-card rendering and better actor metadata extraction
- More complete Rakuen nested-reply parsing for edge-case layouts
- Richer media/embed rendering inside HTML content
- More native deep links for groups, persons, and characters
- Inline media actions such as share/save/open-in-browser from image preview
- More complete collection write-path validation against live Bangumi API behavior
- Richer persistence for offline cache and pagination snapshots
