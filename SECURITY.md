# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 2.7.x | ✅ |
| 2.6.x | ⚠️ security fixes only |
| < 2.6 | ❌ |

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Report it privately through GitHub's
[private vulnerability reporting](https://github.com/alessonqueirozdev-hub/flutter_notemus/security/advisories/new).
You should get an acknowledgement within a few days. If the report is confirmed,
the fix and the advisory will be published together.

Useful things to include: the input that triggers it, the version, the platform,
and — if you have one — a minimal Dart snippet that reproduces it.

## What this package's attack surface actually is

This is a rendering and interchange library. It has no network access, opens no
sockets, and executes nothing it reads. The realistic surface is **untrusted
score files**, so that is where the auditing has gone.

Verified by execution, most recently for 2.7.0:

| Vector | Result |
|---|---|
| XXE — `<!ENTITY xxe SYSTEM "file:///…">` in MusicXML | **Not vulnerable.** The entity is not resolved; the reference survives as the literal text `&xxe;`. Tested against a real file containing a canary string: nothing leaked. |
| Billion laughs — four levels of nested entity expansion | **Not vulnerable.** Parsed in ~5 ms; entities are not expanded. |
| Malformed XML, empty input, truncated documents | Typed exceptions (`XmlParserException`, `FormatException`), never a crash or a hang. |
| Malformed *values* (bad `<divisions>`, negative `<duration>`, out-of-range `<octave>`, `<backup>` past the barline) | Either rejected with a `FormatException` or accepted with an entry in the importer's `warnings` list. |

The underlying `xml` package does not resolve external entities and this library
does not implement its own entity resolution.

## Robustness is not the same as security

A malformed score that imports as *different music* is a data-integrity bug, not
a vulnerability — please report those as normal issues. The importers now carry a
`warnings` channel for exactly this class of problem:

```dart
final warnings = <String>[];
final staff = MusicXMLParser.parseMusicXML(xml, warnings: warnings);
if (warnings.isNotEmpty) {
  // the file imported, but something in it was not what it claimed
}
```

Four kinds of malformed MusicXML are still known to import silently and are
tracked in `CHANGELOG.md` under *Known limitations*.

## Dependencies

Runtime dependencies are `collection`, `xml`, `pdf`, `printing` and the Flutter
SDK packages. `printing` brings platform channels, used only for printing under
an explicit user action. Dependency updates are watched by Dependabot.
