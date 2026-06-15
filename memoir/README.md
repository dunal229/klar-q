# The Record — a living memoir

Raw, ongoing, honest. Voice memos + written entries that accumulate over time
into the source material for a book.

## The two halves

1. **The app** — [`memoir/index.html`](./index.html). Open it on your phone or
   laptop (it's a single file, no install). Choose **🎙️ Voice** or **🎥 Video**,
   hit the red button to record, or just type. Everything auto-saves in that
   browser. Pick a mood, write one true line about what shifted, dump the rest.

2. **The archive** — [`memoir/entries/`](./entries/). The permanent, version-
   controlled copy. The app's data lives only in one browser; the archive is
   forever. Captured audio/video files live in [`entries/media/`](./entries/media/);
   written entries come from the app's **Export for book (.md)**.

## The loop (do this however often feels right)

1. In the app, pick Voice or Video, record, and/or write. Save the entry.
   (The take attaches to the entry automatically for in-app playback.)
2. For every take you want kept forever, tap **Save file**. It downloads with a
   name like `video-2026-06-15-ab12c.webm`. Drop it in `entries/media/`.
3. Tap **Export for book (.md)** → save into `entries/`. The export links each
   entry to its media filename, so text and footage stay matched.
4. Commit + push `entries/` and `entries/media/`.
5. When we talk, point me at the latest export. I'll help find the threads,
   the arc, the change over time — and shape it toward a book, or a cut, when
   you're ready.

## Note on storage

Recording happens entirely in your browser — nothing is uploaded. That's what
keeps it raw and private. The trade-off: the only durable copies are the files
you **Save file** + commit, and the `.md`/`.json` you export. Browser data can be
cleared, so export often. (Video files get large fast; Git is fine for a memoir's
worth, but if footage volume explodes we can move media to Git LFS or cloud.)

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
