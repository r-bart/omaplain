# OmaPlain 1.0.0

Paste clean text by default, and keep everything else exactly as you copied it.

This is the first release that makes a promise rather than an offer. It is
written in English, along with the changelog from here on
([`0014`](decisions/0014-el-idioma-del-repositorio.md)).

## What a 1.0 means here

**What OmaPlain does not touch today, it will not touch tomorrow, and your
settings survive an update.**

That is the whole of it. It is not a claim that there will be no new features,
and it is not a claim that the platform underneath has settled — Omarchy is
itself alpha, and this release says so out loud. It is a claim about behaviour:
the boundaries below are now fixed, and moving one is a breaking change with a
version number to match.

- Images, files, and anything an application marks sensitive are **never read**.
  When in doubt, OmaPlain does nothing.
- The clipboard's **contents are never persisted** — not in state, not in
  configuration, not in a log, not in a notification, not in an error trace.
  They cross a `0600` socket to an open panel and die when you close it.
- **No network. Ever.** There is no telemetry, no update check, no sync between
  devices, and no code path that opens a socket to anywhere but your own machine.
- **At most one rewrite per copy event**, and only after comparing.
- It does not modify your Hyprland configuration and it never claims a global
  shortcut, `Super+V` included.

## What is new since 0.2.0

- **The panel's illustrations demonstrate rather than describe.** The welcome
  shows an address losing its tracking parameters; the tour shows a queue of
  copies passing untouched through a check, real characters falling out of a
  real URL, and the five actual settings at their factory values. With **Reduce
  motion** on, every one of them paints its final state and none loses
  information.
- **One mark, in all three places** — bar, launcher and panel header — drawn
  from a single path so the bar and the header take your theme's ink and accent
  ([`0020`](decisions/0020-la-marca-se-dibuja.md)). An optional `theme-set` hook
  repaints the launcher icon to match the theme you just applied.
- **A screenshot now reaches the daemon.** A pure image produced no event at
  all, so an open panel went on showing the previous copy. Fixed with a second,
  typeless watcher that fires only when the offer carries no text.
- **The frequent screen no longer offers a dead button**, the fog finishes
  itself once you have cleared a quarter of it, and the preview follows the
  clipboard instead of freezing at the moment the panel opened.
- **Right-clicking the bar icon does nothing, permanently**
  ([`0021`](decisions/0021-el-clic-derecho-de-la-barra-queda-libre.md)).
  `pasteClean` rewrites your clipboard and destroys the original; a gesture that
  fires by accident cannot carry that.
- **Dimmed text carries a contrast floor**
  ([`0022`](decisions/0022-la-tinta-atenuada-lleva-suelo.md)). Secondary ink used
  a fixed alpha, which cannot promise a contrast ratio because it never looks at
  the background. Measured across thirty themes it fell below WCAG AA on light
  ones; it no longer can.

The [changelog](../CHANGELOG.md) has the rest, including the twenty-two fixes that
came out of a full review of helper, QML, docs and tests.

## Which Omarchy

Built and tested against **Omarchy 4.x** — the `4.0.1-1` package, whose shell
reports itself as `4.0.0.alpha`.

Outside 4.x nothing is promised, and nothing is blocked: there is no version
gate and there will not be one
([`0023`](decisions/0023-a-que-omarchy-se-ata-la-1.0.md)). What stands between
you and a shell that has moved underneath is a set of tests that read the
installed shell rather than trusting our memory of it. They have already earned
it once — a change to where the shell stores a plugin's settings made every
setting in this panel fail to save, silently and with no error at all.

## Limits you should know about

- **Source attribution on Wayland is best effort.** Wayland does not say who
  copied; the daemon infers it from the focused window at the instant of the
  event. Per-application rules block when they recognise the application, and
  the interface promises no more than that. MIME types and the sensitivity flag
  are the safety gates; the application class is not
  ([`0009`](decisions/0009-privacidad-por-aplicacion.md)).
- **Omarchy's own clipboard history may keep both versions** of anything whose
  characters changed, until you clear it. That persistence belongs to Omarchy,
  and every rule except *rich formatting* changes characters — line endings
  included.
- **A secret published as ordinary text cannot be told apart from text.** If an
  application does not mark its secrets, give it a *never read* rule.
- **Screen sharing.** The panel shows your clipboard as soon as you open it.
  The fog is there so a shoulder or a shared screen does not read it by
  accident, but it comes off with one drag — do not open the panel on a call you
  would not read your clipboard aloud on.
- **LibreOffice is bypassed conservatively**, the primary selection is not
  processed, devices are never synchronised, and support targets the default
  seat.

The [compatibility matrix](COMPATIBILITY.md) has the per-application detail, and
a test now checks it against the classifier rather than leaving it to age.

## Verification

`tests/run.sh` is the whole suite in one command: 409 unit tests with
`ResourceWarning` treated as an error, a benchmark, a soak of 28,800 events,
`qmllint` over 24 QML files against the installed shell, 68 checks of that QML
**executed** inside a real Quickshell in a nested Hyprland, and Omarchy's own
`plugin validate`. The last three skip themselves with no Omarchy in front, so
CI runs the same list.

Helper line coverage sits at 96 %, with all nine CLI subcommands — the boundary
the panel actually uses — tested end to end against a live daemon.
