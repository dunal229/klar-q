# The Record — a living memoir

Raw, ongoing, honest. Voice memos + written entries that accumulate over time
into the source material for a book.

## The two halves

1. **The app** — [`memoir/index.html`](./index.html). Open it on your phone or
   laptop (it's a single file, no install). Hit the red button to record a voice
   memo, or just type. Everything auto-saves in that browser. Pick a mood, write
   one true line about what shifted, dump the rest.

2. **The archive** — [`memoir/entries/`](./entries/). The permanent, version-
   controlled copy. The app's data lives only in one browser; the archive is
   forever. Use **Export for book (.md)** in the app, then commit the file here.

## The loop (do this however often feels right)

1. Talk / write in the app. Save the entry. (Audio clip attaches automatically.)
2. For any voice memo you want kept forever, tap **Save file** to download the
   audio, and drop it in `entries/audio/`.
3. Tap **Export for book (.md)** → save into `entries/` → commit + push.
4. When we talk, point me at the latest export. I'll help find the threads,
   the arc, the change over time — and shape it toward a book when you're ready.

## Why it's built this way

- **No backend, no account, nothing leaves your devices** unless you commit it.
  That's what lets it be raw.
- **Markdown export** because a book wants plain, portable text — not a database.
- **Git history** becomes its own quiet record: when each entry landed, how the
  story changed as you changed.

## Working with Claude on this

Each session, hand me the newest `.md` export (or just talk to me and I'll write
the entry down for you). I can:
- transcribe / clean up what you dictate into a dated entry,
- track recurring themes, people, turning points across months,
- surface the throughline you can't see from inside it,
- and eventually help you draft the actual book from the raw record.
