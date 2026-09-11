#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build --quiet
check_dir=$(mktemp -d "${TMPDIR:-/tmp/}notic-motion-check.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
cat > "$check_dir/main.swift" <<'SWIFT'
import AppKit
import SwiftUI
import NoticCore

let app = NSApplication.shared
for reduced in [false, true] {
    assert(Motion.press(isPressed: false, reduceMotion: reduced) == nil)
    assert(Motion.press(isPressed: true, reduceMotion: reduced) != nil)
    assert((Motion.settle(reduceMotion: reduced) == nil) == reduced)
    assert((Motion.handoff(relativeVelocity: 2, reduceMotion: reduced) == nil) == reduced)
}
let panel = EditorPanel(noteID: UUID(), content: EmptyView(), onResize: { _ in }, onLiveResizeEnded: {}, onMove: { _ in }, onClose: {})
let target = CGRect(x: 200, y: 200, width: 400, height: 300)
for _ in 0..<10 {
    panel.present(at: target)
    assert(panel.isVisible && panel.alphaValue == 1 && panel.frame == target)
    var completed = false
    panel.dismiss { completed = true }
    assert(completed && !panel.isVisible)
}
RunLoop.main.run(until: Date().addingTimeInterval(0.4))
assert(!panel.isVisible, "No delayed animation completion may reopen the panel")
print("PASS: immediate repeated panel presentation/dismissal, reduced-motion reflow/handoff, asymmetric press feedback")
SWIFT
build_dir=$(swift build --show-bin-path)
swiftc -swift-version 6 -default-isolation MainActor \
  -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -I "$build_dir/Modules" \
  app/Notic/Sources/Panels/EditorPanel.swift \
  app/Notic/Sources/Views/Motion.swift \
  "$check_dir/main.swift" "$build_dir"/NoticCore.build/*.o \
  -o "$check_dir/check"
"$check_dir/check"
