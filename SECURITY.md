# Security

## Supported versions

The `0.2.x` line receives security fixes. `0.1.x` no longer does.

## Reporting a problem

Do not file a report that contains passwords, tokens, private URLs, window titles or real clipboard text. Use a minimal synthetic payload and describe:

- the OmaPlain and Omarchy versions;
- the MIME types observed, without content;
- the application and its version;
- the expected and the observed result;
- whether the content was marked as sensitive.

The repository lives at <https://github.com/r-bart/omaplain>. For a security problem use GitHub's private vulnerability reporting on that repository, not a public issue. If that path is not available, open an issue that says only that there is a security problem and how to reach you, with no detail, and the maintainer will answer through a private channel.

## Guarantees and boundary

OmaPlain has no network, no telemetry and no persistence of content of its own. It bypasses secrets when Wayland or the MIME type marks them. An application that publishes a password as ordinary text, with no signal at all, cannot be told apart from any other text; give it a *never read* rule by application class.

One precision about "without reading". The watcher is `wl-paste --type text --watch`, and `wl-paste` pipes the content of every text copy, the one marked as sensitive included, into the short-lived process that notifies the daemon. That process does not read its input: it only forwards `CLIPBOARD_STATE`. The daemon, which does the classifying, never asks for the content of a sensitive copy. The bytes pass through a kernel pipe between `wl-paste` and a process that discards them, and nowhere else.

## What is shown on screen

Since [`0005`](./docs/decisions/0005-previsualizacion-del-portapapeles.md) the
panel shows the clipboard content and what it would become. The content travels
over the local `0600` socket in `$XDG_RUNTIME_DIR`, lives in memory while the
panel is open, is forgotten when it closes, and is written nowhere: not state,
not configuration, not a log, not a notification, not an error trace.

Three limits, in order of importance:

- **Anything marked as sensitive is never shown.** The refusal lives in the
  helper, not in the interface: `peek` on such content returns the reason and
  the MIME types, never the text, even when the panel asks. No setting changes
  that.
- **Content arrives covered.** The panel is a layer-shell surface and opens on
  top of whatever you are sharing or recording. Uncovering is an explicit act,
  per element, and a new copy covers it again. While covered, the text is not
  in the accessibility tree either.
- **Screen sharing is the new risk.** If you uncover the content during a call
  or a recording, you are showing it. The cover-by-default reduces the
  accident; it cannot prevent the decision.

A secret that its application publishes as ordinary text, with no mark, is
indistinguishable from any other text and can end up visible in the panel.
Exclude that application by class.
