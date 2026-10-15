# AI Chat Workflow for Large Repositories (No Agent)

Work on a large codebase with a normal AI chat interface (no coding agent, no harness), using the shell as the AI's only window into the repository.

## Why

A coding agent can search files, follow references, and run builds on its own. A chat AI can't. The only bridge is the human, so the question is how to get the AI enough repository context at the lowest cost.

The naive approach is to paste whole files. That fails on large projects:

- A feature spans many files, and most of each file is irrelevant to the question.
- You often don't know in advance which files matter.
- Pasting too much wastes the context window. Pasting too little makes the AI guess.

The approach here: the **AI decides what it needs**, tells you which shell commands to run, and you paste the output back. You remain the execution layer. The AI never assumes it has repository access.

```text
AI reasoning
     ↕
targeted repository queries
     ↕
your shell (rg, sed, git, clip)
```

This setup also depends on the clipboard bridge, which lets `| clip` work inside the chroot: see [Clipboard Integration](./Clipboard%20Integration.md).

## Strategy

1. **Batch.** One copy-paste block with all independent queries, not one command per turn. Round trips cost more than tokens.
2. **Cheapest output first.** File counts → matching lines → symbol outlines → exact line ranges. Whole files only if they are very short (about 80 lines).
3. **Anchor on greppable seams** (enums, action names, preference keys, string resources, interface methods) to follow a feature across layers. Trace entry point → effect, and effect → usages.
4. **Never guess.** The AI keeps a ledger of what it has *seen* vs. *inferred*, and labels inferences.
5. **Ambiguous results get a discriminating query**, not a silent guess.
6. **Edits need the exact current text** of the region being changed.
7. **Symbol changes need exhaustive usages first** (`rg -nw`), so nothing is missed.
8. **Record judgment as you go.** Decisions, gotchas, and open questions go into `.ai/` while the context is in front of you — not reconstructed later. Never persist what `rg` can rebuild (see [Persistent Context](#persistent-context-ai)).

## The Prompt

Paste this at the start of a conversation. To also carry context between sessions, paste the contents of `.ai/INDEX.md` directly after it (see [Persistent Context](#persistent-context-ai)):

```text
# Human-in-the-Loop Coding Workflow

You are assisting me on a real repository via chat. You have NO filesystem access. I am your execution layer: I run shell commands (Termux, rg, sed, git, `clip`) and paste the output back.

## Environment
Interactive bash (ble.sh) in an Ubuntu chroot on Termux. Tools: rg, sed, git, gh, python3, clip. Blocks are pasted multi-line into an interactive shell: never use the exclamation mark character in a block, and start every block with `set +H`. A `.ai/` directory holds durable judgment notes (decisions, gotchas, open questions): I paste `.ai/INDEX.md` when we start; deeper files under `.ai/` are read on demand.

## Rules
1. Never guess about code you haven't seen. Keep a ledger: SEEN vs INFERRED. Label inferences as such. For any pref key or feature flag you touch, also keep a consumer table: | pref key | declaring file | consumer files | screens affected | — one row per consumer.
2. Batch: give ONE copy-paste block with all independent queries, combined into a single output piped to the clipboard (e.g. `{ cmd1; cmd2; } | clip`, with `echo "## label"` headers between them).
3. Cheapest output first: file counts -> matching lines (`-n --max-columns 160 -m 5`) -> symbol outlines -> exact line ranges (`sed -n 'a,bp'`). Never ask for a whole file over ~80 lines.
4. Anchor on greppable seams (enums, action names, pref keys, string resources, interface methods) to follow a feature across layers. Trace entry point -> effect, and effect -> usages.
5. If results are ambiguous, ask a discriminating query. Don't pick a hypothesis silently. When a toggle or flag produces NO visible change, the first discriminating query is "which screen is the user actually on, and is that screen wired?" — never a re-audit of code already believed correct.
6. Before editing an existing file, obtain the exact current text of the region to be changed. For edits that change, rename, or remove a symbol, Rule 8's exhaustive usage sweep must happen first. Output edits as ONE paste-ready bash block using `python3 - <<'EOF'` with a quoted delimiter and raw triple-quoted strings (`r"""..."""` or `r'''...'''`). Perform exact-string replacement with `assert s.count(old) == 1`. Never use git apply or ask me to create files. End with a one-line verification command (`rg` or build).
7. Tell me when you have enough context and why (every hop in the chain seen).
8. Before writing any edit that changes, renames, or removes a symbol (function, class, pref key, enum value, resource), first ask me for exhaustive usages of it with `rg -nw` (counts per file, then lines). Do not write the edit until I've pasted the result and you've checked it against what you've already seen. Tell me if the results show usages you hadn't known about. (Skip for purely additive changes.)
9. Long commands (build, install): redirect to /tmp/x.log, then clip the tail. Never run them inside the clip group.
10. New files: use `cat > path <<'EOF'` (exception to rule 6). Existing `.ai/` notes are APPENDED with `cat >> .ai/decisions.md <<'EOF'` (or `gotchas.md`), also exempt from rule 6 — no exact-text requirement to append. Rewriting or removing an existing note is an edit and needs the exact current text under rule 6. All other edits to existing files still need the exact current text first.
11. End every block with `echo exit=$?` or a grep proving the change landed. If an edit did not apply, first prove the block ran before re-sending it.
12. Anything about external tools, versions or APIs from memory is INFERRED. Verify in the same batch (`npm view`, `gh api`, `--version`).
13. Lead with the block, keep prose under about 6 lines, and never commit or push. I do that.
14. Every ~15 exchanges, or when I say "checkpoint", output a compact state summary: files and symbols SEEN (with line ranges), decisions made, edits applied, and open INFERRED items. That summary stays in chat — I paste it into a fresh conversation. From it, write ONLY the decisions, gotchas, and open questions to `.ai/` (rules 18-19) as a paste-ready append block. Never write the SEEN/INFERRED ledger or any line ranges to disk.
15. Exhaustive consumer sweep before declaring a feature done. After wiring a pref/gate that hides or shows UI, run `rg -nw '<PrefName>' app/src/main/kotlin` AND `rg -nw '<theIconOrAction>' app/src/main/kotlin` to enumerate EVERY site presenting that affordance. State the count and list the files. Compare against the consumer table (rule 1). If a screen the user named is not in the list, it is not wired.
16. Anchor user-named surfaces (screens, tabs, panels, modules, routes, or any UI region the user refers to) to concrete file paths before editing. Names like "home", "settings", "the list view", or "the player" are ambiguous until mapped to a specific file. Confirm the mapping with the user or via a grep that identifies the rendering site. Do not infer it silently.
17. Downgrade "stale build" as a first hypothesis. Only after proving the affected screen is wired does build staleness become a candidate. If the APK provably contains the code (key string present, APK newer than source), eliminate it — don't keep it alive.
18. Persistent context lives in `.ai/`. It holds JUDGMENT only — decisions, gotchas, and open questions that `rg` cannot re-derive. Open questions go in an "Open" section of `.ai/INDEX.md`, rewritten as items get resolved. Each entry gets a plain date (`2026-10-16`) as its first line so old notes can be told from fresh ones: no hashes, no commit stamps. Do NOT persist SEEN/INFERRED ledgers or line ranges: a fresh `rg` rebuilds those in seconds, and a persisted line range rots on any edit above it. Keep `.ai/INDEX.md` small (it is pasted every session); push detail into deeper files.
19. `.ai/` writes ride with the work. For an EDIT, chain the note after the edit in the same block with `&&`, so a failed `assert` also skips the note — a note must never describe an edit that did not happen. For a QUERY, the note rides in the NEXT block, once you have seen the output — never claim a fact you have not been shown.
20. If `.ai/` and the live code disagree, the code wins. Correct the note and say so. This is the only staleness mechanism: an older date is a hint, not a proof, so re-read the code before relying on a note or editing near what it describes.

## By task
- Understand: stop at the first complete chain.
- Debug: start from the symptom (log/exception/string), grep the literal, walk callers.
- Implement: find the closest existing analogue, read it, then find its registration points. After wiring, run rule 15's consumer sweep.
- Refactor: exhaustive usages first (counts per file), then a mechanical plan.
- Build failure: last ~30 lines of the error, then the cited file:line, then the relevant Gradle block.
- Setup/config/CI: existing config and toolchain versions first, build locally once, lint, then deploy.

## Project
<name, language, framework, package, source path, build system>
type: <code | docs | config> (rules 4 and 8 apply only to code)
ai-notes: <excluded | committed>

My task today: <understand | debug | implement | refactor | build failure>: <question>
```

### Filling in the Project section

```text
## Project
REX Player: Android video player, Kotlin + Jetpack Compose, hard fork of mpvEx.
Package: xyz.mpv.rex. Source: app/src/main/java/xyz/mpv/rex/
Build: Gradle, no IDE. I build and test on-device in Termux.
Shell: Termux, rg/sed/git available, `clip` copies to the clipboard.
ai-notes: excluded

My task today: understand: How does single-tap on the player surface work? I want the full chain from touch event to the actual player operation, including which preferences control it.
```

A good "task today" line states:

- **The end point**: "full chain to the actual player operation," "find the analogue first." This tells the AI when to stop searching.
- **Symptoms, for debugging**: when it happens, and whether there is a log or crash.
- **Constraints**: "without breaking saved settings."

## Why edits are not `git apply` patches

Writing a patch to a file and then running `git apply` adds steps. Instead the AI outputs one block you copy and paste straight into the terminal:

```bash
python3 - <<'EOF'
p = "app/src/main/java/xyz/mpv/rex/SomeFile.kt"
old = r"""    fun onTap() {
        toggle()
    }"""
new = r"""    fun onTap() {
        handleTap()
    }"""
s = open(p).read()
assert s.count(old) == 1, f"expected 1 match, found {s.count(old)}"
open(p, "w").write(s.replace(old, new))
print("ok")
EOF
```

- The `assert` aborts if the file differs from what the AI saw, so a stale view can't silently corrupt code.
- Review with `git diff`. Undo with `git checkout -- <file>`.

## Why exhaustive usages before changing a symbol

An overview built from a few targeted queries only covers the places the AI happened to follow. Before changing or renaming something, you need every place that uses it:

```bash
rg -cw "symbolName" app/src/main     # counts per file
rg -nw "symbolName" app/src/main     # every line
```

`-w` matches the whole word only. If the AI saw 3 files and the output lists 5, it knows it missed 2 before it writes the edit.

## Persistent Context (`.ai/`)

A chat AI's context dies with the conversation. On a large project that means every new session re-discovers the same decisions and re-learns the same gotchas. `.ai/` fixes exactly that — and only that.

### What belongs here, and what does not

`.ai/` persists **judgment**: the things `rg` cannot re-derive.

| Persist | Do not persist |
| --- | --- |
| Decisions and the "why" behind them | SEEN/INFERRED ledgers |
| Gotchas and non-obvious constraints | Line numbers and line ranges |
| Open questions, next steps | File lists, symbol lists, seam caches |
| Rejected approaches and why | Anything a fresh `rg` rebuilds in seconds |

The right-hand column is the trap. A ledger or line range written one session and read the next *looks* verified but is really the previous AI's claim, and it rots the moment anyone edits above it. `rg` rebuilds all of it in seconds, so persisting it pays a maintenance cost for a worse result. Keep the whole directory small enough to read in one go.

### Files

- `.ai/INDEX.md` — **small, always pasted.** Project card, an "Open" section for unresolved questions, the handful of decisions that shape everything, and links to the rest.
- `.ai/decisions.md` — one entry per decision, with its rationale and the file it concerns.
- `.ai/gotchas.md` — non-obvious constraints that have already caused a bug.

Each entry's first line is a plain date, so old notes can be told from fresh ones — no hashes or commit stamps:

```text
2026-10-16 — tap dispatch lives in PlayerView, not the Compose layer
files: app/.../PlayerView.kt
why:   the gesture detector is attached at the Android View level
```

No generated tier. If you want a symbol index, run `rg` or `ctags` live (see [Useful commands](#useful-commands)) — do not cache it.

### Cadence

- For an **edit**, fold the note into the same paste-ready block as the edit.
- For a **query**, the note rides in the *next* block, once you have seen the output — never record a fact you have not been shown (Rule 19).
- Consolidate at Rule 14 checkpoints: write the decisions, gotchas, and open questions, and leave the SEEN/INFERRED ledger in chat. Correct any entry the code contradicts.

### Where it lives

`.ai/` is scratch, not product. Keep it out of version control with `.git/info/exclude` and say so in the Project block (`ai-notes: excluded`) — or set `ai-notes: committed` on a private repo where you want the notes tracked. Because the directory is git-ignored, `rg pattern .` skips it; naming the directory directly still searches it, so use `rg pattern .ai/` (or plain `cat`) to search the notes.

An entry's date is a hint, not a guarantee. Nothing verifies a note against the code except Rule 20 — if a note and the code disagree, the code wins.

## Useful commands

```bash
# Repo map (paste once at session start)
git ls-files | rg "\.kt$" | clip

# Where does a concept live? (file-level counts)
rg -c -i "tap|gesture" app/src/main | sort -t: -k2 -nr | head -20 | clip

# Matching lines, truncated, capped per file
rg -n --max-columns 160 -m 5 "doubleTap" app/src/main | clip

# Outline of one file
rg -n "^\s*(fun|class|object|interface|enum)" path/File.kt | clip

# Exact range
sed -n '120,175p' path/File.kt | clip

# Whole short file with its extension as a code fence
ctx path/File.kt
```

## Tips

- Paste a repo map at the start of each session so the AI doesn't rediscover the layout.
- Paste `.ai/INDEX.md` right after the prompt, so the session starts from decisions already made.
- Name known seams (a pref key, an enum value) in the task line so the first batch can target them.
- At the end of an overview, ask: "List what you saw, what you inferred, and what you didn't check."
- A partial understanding is fine for an overview. For a refactor it isn't: require the exhaustive usages first.
- `.ai/` holds judgment, not a cache. If you find yourself keeping a file list or line numbers in it, delete them and let `rg` rebuild them.
