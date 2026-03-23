# Open Issues Backlog

This file mirrors high-priority pending work that is already tracked in GitHub Issues.

## Active pending areas

1. Native audio backend parity for non-Android platforms
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/1
   - Current state: iOS, macOS, Linux, and Windows return stub/no-op results.

2. PDF export currently renders placeholders, not full notation
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/2
   - Current state: metadata page is real, score pages are placeholder lines.

3. Staff group brace still uses custom path instead of SMuFL workflow
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/3

4. Stem/flag primitive constants need full engraving-default parameterization
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/4

5. `repeatBoth` must have robust fallback without combined glyph dependency
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/5

## Update policy

- Every pending feature/bug must have a GitHub issue.
- This file is a quick local index only; GitHub issues are the source of truth.
- When an issue is closed, update this file in the same commit.
