#!/usr/bin/env python3
"""Assert on synthetic packages what the DOCX comment threading owes its reader.

`_extensions/hebstr-doc/scripts/thread-docx-comments.py` runs after the zip is
closed, so no Quarto render reaches it and the luaunit suite cannot cover it.
This probe builds the smallest package carrying a comment thread, drives the
script over it, and asserts the parent relation it writes, the idempotency of a
further pass, and the three refusals that must leave the deliverable alone.
"""

import hashlib
import os
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "_extensions" / "hebstr-doc" / "scripts" / "thread-docx-comments.py"

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
W15 = "http://schemas.microsoft.com/office/word/2012/wordml"

MAIN_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"
COMMENTS_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"

TYPES = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="xml" ContentType="application/xml"/>'
    f'<Override PartName="/word/document.xml" ContentType="{MAIN_TYPE}"/>'
    f'<Override PartName="/word/comments.xml" ContentType="{COMMENTS_TYPE}"/>'
    "</Types>"
)

RELS = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Target="comments.xml" Type="http://schemas.openxmlformats.org'
    '/officeDocument/2006/relationships/comments"/>'
    "</Relationships>"
)

DOCUMENT = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    f'<w:document xmlns:w="{W}"><w:body>'
    '<w:p><w:commentRangeStart w:id="0"/><w:commentRangeStart w:id="1"/>'
    "<w:r><w:t>anchored</w:t></w:r>"
    '<w:commentRangeEnd w:id="0"/><w:commentRangeEnd w:id="1"/></w:p>'
    '<w:p><w:commentRangeStart w:id="2"/><w:r><w:t>alone</w:t></w:r>'
    '<w:commentRangeEnd w:id="2"/></w:p>'
    "</w:body></w:document>"
)

COMMENTS = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    f'<w:comments xmlns:w="{W}">'
    '<w:comment w:id="0" w:author="A"><w:p><w:r><w:t>opening</w:t></w:r></w:p></w:comment>'
    '<w:comment w:id="1" w:author="B"><w:p><w:r><w:t>reply</w:t></w:r></w:p></w:comment>'
    '<w:comment w:id="2" w:author="A"><w:p><w:r><w:t>lone</w:t></w:r></w:p></w:comment>'
    "</w:comments>"
)

PADDING = "<a>" + "padding " * 400 + "</a>"

passed = 0
failures = []


def check(condition, message):
    global passed
    if condition:
        passed += 1
    else:
        failures.append(message)


def build(path, extra=None):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as package:
        package.writestr("[Content_Types].xml", TYPES)
        package.writestr("word/_rels/document.xml.rels", RELS)
        package.writestr("word/document.xml", DOCUMENT)
        package.writestr("word/comments.xml", COMMENTS)
        for name, data in (extra or {}).items():
            package.writestr(name, data)


def corrupt_one_stream(path, name):
    with zipfile.ZipFile(path) as package:
        entry = package.getinfo(name)
    start = entry.header_offset + 30 + len(entry.filename.encode()) + len(entry.extra)
    raw = bytearray(path.read_bytes())
    for offset in range(start + 12, start + 24):
        raw[offset] ^= 0xFF
    path.write_bytes(bytes(raw))


def run(*arguments, environment=None):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *arguments],
        capture_output=True,
        text=True,
        env=environment,
        check=False,
    )


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def leftovers(room):
    return sorted(path.name for path in room.glob("*.threading"))


def threads_a_reply(room):
    path = room / "thread.docx"
    build(path)
    done = run(str(path))
    check(done.returncode == 0, f"threading exited {done.returncode}")
    with zipfile.ZipFile(path) as package:
        names = package.namelist()
        present = "word/commentsExtended.xml" in names
        check(present, "the extended part is missing from the threaded package")
        if not present:
            return
        extended = package.read("word/commentsExtended.xml").decode("utf-8")
        comments = package.read("word/comments.xml").decode("utf-8")
        types = package.read("[Content_Types].xml").decode("utf-8")
        rels = package.read("word/_rels/document.xml.rels").decode("utf-8")
    check(
        extended.count("w15:paraIdParent=") == 1,
        f"expected one parent relation, found {extended.count('w15:paraIdParent=')}",
    )
    check(
        extended.count("<w15:commentEx ") == 3,
        f"expected three commentEx, found {extended.count('<w15:commentEx ')}",
    )
    check(
        comments.count("w14:paraId=") == 3,
        f"expected three paraId, found {comments.count('w14:paraId=')}",
    )
    check(
        "commentsExtended.xml" in types and "commentsExtended.xml" in rels,
        "the content-type override or the relationship is missing",
    )
    check(
        all(
            part.startswith('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
            for part in (comments, types, rels)
        ),
        "a rewritten part lost the standalone declaration",
    )
    check(leftovers(room) == [], f"threading left {leftovers(room)} behind")


def repeats_without_changing_the_package(room):
    path = room / "repeat.docx"
    build(path)
    run(str(path))
    once = digest(path)
    run(str(path))
    twice = digest(path)
    run(str(path))
    check(once == twice == digest(path), "a further pass changed the package")


def leaves_a_word_threaded_package_alone(room):
    path = room / "worded.docx"
    build(
        path,
        {
            "word/commentsIds.xml": '<?xml version="1.0" encoding="UTF-8"?><w16cid:commentsIds/>',
            "word/commentsExtended.xml": f'<w15:commentsEx xmlns:w15="{W15}"/>',
        },
    )
    before = digest(path)
    done = run(str(path))
    check(done.returncode == 0, f"a Word-threaded package exited {done.returncode}")
    check(before == digest(path), "a Word-threaded package was rewritten")
    check(
        "Word already threads" in done.stderr,
        "the refusal of a Word-threaded package is unnamed",
    )


def survives_a_corrupt_entry(room):
    bad = room / "bad.docx"
    good = room / "good.docx"
    build(bad, {"word/theme/theme1.xml": PADDING})
    corrupt_one_stream(bad, "word/theme/theme1.xml")
    build(good)
    done = run(str(bad), str(good))
    check(done.returncode == 0, f"a corrupt entry exited {done.returncode}")
    check("Traceback" not in done.stderr, "a corrupt entry raised a traceback")
    check(
        "decompressing" in done.stderr,
        "the corrupt entry is not named on stderr",
    )
    with zipfile.ZipFile(good) as package:
        check(
            "word/commentsExtended.xml" in package.namelist(),
            "a failing output stopped its sibling from being threaded",
        )
    check(leftovers(room) == [], f"a corrupt entry left {leftovers(room)} behind")


def names_a_missing_output_listing(room):
    environment = dict(os.environ)
    environment.pop("QUARTO_PROJECT_OUTPUT_FILES", None)
    environment["QUARTO_USE_FILE_FOR_PROJECT_OUTPUT_FILES"] = str(room / "absent.txt")
    done = run(environment=environment)
    check(done.returncode == 1, f"a missing listing exited {done.returncode}")
    check("Traceback" not in done.stderr, "a missing listing raised a traceback")
    check("absent.txt" in done.stderr, "the missing listing is not named on stderr")


def main():
    if not SCRIPT.is_file():
        print(f"[thread-docx] {SCRIPT} not found", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory() as directory:
        room = Path(directory)
        threads_a_reply(room)
        repeats_without_changing_the_package(room)
        leaves_a_word_threaded_package_alone(room)
        survives_a_corrupt_entry(room)
        names_a_missing_output_listing(room)
    for failure in failures:
        print(f"[thread-docx] {failure}", file=sys.stderr)
    if failures:
        print(f"[thread-docx] {len(failures)} of {passed + len(failures)} failed", file=sys.stderr)
        return 1
    print(f"[thread-docx] {passed} assertions passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
