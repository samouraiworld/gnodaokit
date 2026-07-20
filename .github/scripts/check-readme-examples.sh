#!/usr/bin/env bash
# The READMEs ship with the frozen package, so a sample that does not build is as
# permanent as a wrong signature — and both "Complete Example" blocks did not
# build. gno/r/readme_*_example compile them and run their init, but that only
# means anything while they still say what the README says. This re-extracts each
# block and diffs it, so the two cannot drift apart silently.
set -euo pipefail

extract() { # <markdown> <package>
    python3 -c '
import re, sys
md, pkg = sys.argv[1], sys.argv[2]
for b in re.findall(r"```go\n(.*?)```", open(md).read(), re.S):
    if "func init(cur realm)" in b and "basedao.New" in b:
        sys.stdout.write(b.replace("package my_dao", "package " + pkg))
        break
else:
    sys.exit("no Complete Example block found in " + md)
' "$1" "$2"
}

check() { # <markdown> <fixture> <package>
    local md="$1" fixture="$2" pkg="$3"
    extract "$md" "$pkg" > /tmp/readme-extracted.gno
    if [[ ! -s /tmp/readme-extracted.gno ]]; then
        echo "ERROR: extracted nothing from $md — the block markers changed"
        return 1
    fi
    # The fixture carries a header comment the README does not; drop everything
    # before its package clause. Done in python because BSD and GNU sed disagree
    # about the range-with-block form.
    python3 -c '
import sys
lines = open(sys.argv[1]).read().split("\n")
for i, l in enumerate(lines):
    if l.startswith("package "):
        sys.stdout.write("\n".join(lines[i:]))
        break
else:
    sys.exit("no package clause in " + sys.argv[1])
' "$fixture" > /tmp/readme-fixture.gno
    if ! diff -u /tmp/readme-extracted.gno /tmp/readme-fixture.gno; then
        echo "ERROR: $md's Complete Example no longer matches $fixture."
        echo "They are compiled together on purpose. Update both."
        return 1
    fi
    echo "OK: $md matches $fixture"
}

check README.md                gno/r/readme_root_example/sample.gno    readme_root_example
check gno/p/basedao/README.md  gno/r/readme_basedao_example/sample.gno readme_basedao_example
