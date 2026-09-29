#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="${1:-$ROOT_DIR/MarkdownDemo/MarkdownDemo/Info-macOS.plist}"

expect() {
    local actual
    actual="$(/usr/libexec/PlistBuddy -c "Print :$1" "$PLIST")"
    if [[ "$actual" != "$2" ]]; then
        echo "error: $1 expected '$2', got '$actual'" >&2
        exit 1
    fi
}

expect CFBundleDocumentTypes:0:CFBundleTypeRole Editor
expect CFBundleDocumentTypes:0:LSHandlerRank Alternate
expect CFBundleDocumentTypes:0:LSItemContentTypes:0 net.daringfireball.markdown
expect UTImportedTypeDeclarations:0:UTTypeIdentifier net.daringfireball.markdown
expect UTImportedTypeDeclarations:0:UTTypeConformsTo:0 public.plain-text
expect UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:0 md
expect UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:1 markdown
expect UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.mime-type text/markdown
echo "Markdown document declarations verified."
