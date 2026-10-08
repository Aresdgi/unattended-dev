#!/usr/bin/env python3
"""Release notes for one version, taken from both changelogs.

Usage: release_notes.py <version> <notes-file>
Prints the release title and writes the notes (English, then Spanish
folded) to <notes-file>. Exits 1 if the version has no entry.
"""
import re
import sys

REPO = "https://github.com/Aresdgi/unattended-dev/blob/main"


def entry(path, version):
    text = open(path, encoding="utf-8").read()
    for part in re.split(r"^## ", text, flags=re.M)[1:]:
        head, _, body = part.partition("\n")
        if head.startswith(f"[{version}]"):
            body = re.sub(r"^\[\d[^\]]*\]: .*$", "", body, flags=re.M).strip()
            return unwrap(re.sub(r"^### ", "#### ", body, flags=re.M))
    return None


def unwrap(body):
    # GitHub keeps line breaks in release notes, so join wrapped lines.
    out = []
    for line in body.split("\n"):
        prev = out[-1] if out else ""
        joins = (
            prev.strip()
            and line.strip()
            and not re.match(r"\s*(- |#|<)", line)
            and not prev.startswith(("#", "<"))
        )
        if joins:
            out[-1] = prev.rstrip() + " " + line.strip()
        else:
            out.append(line)
    return "\n".join(out)


version, notes_file = sys.argv[1], sys.argv[2]
en = entry("CHANGELOG.md", version)
es = entry("CHANGELOG.es.md", version)
if not en or not es:
    sys.exit(f"no changelog entry for {version}")

summary = re.split(r"\.(\s|$)", en.split("\n")[0])[0]
with open(notes_file, "w", encoding="utf-8") as f:
    f.write(
        f"{en}\n\n<details>\n<summary>Español</summary>\n\n{es}\n\n</details>\n\n"
        f"**Full changelog:** [English]({REPO}/CHANGELOG.md) · "
        f"[Español]({REPO}/CHANGELOG.es.md)\n"
    )
print(f"{version}: {summary}")
