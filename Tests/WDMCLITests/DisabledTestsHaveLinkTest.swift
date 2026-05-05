import Testing
import Foundation

/// Enforces the CLAUDE.md rule:
///   "No `@disabled` without an issue link in a comment."
///
/// Because Arthur-Ficial repos do not use GitHub Actions (quota
/// exhausted), the canonical tracking surface is `docs/known-flakes.md`.
/// Every `@Test(.disabled("…"))` reason string must reference an anchor
/// in that file: `(see docs/known-flakes.md#<anchor>)`.
@Suite("Disabled tests are linked to docs/known-flakes.md")
struct DisabledTestsHaveLinkTest {
    @Test("every @Test(.disabled) reason in Tests/ links to docs/known-flakes.md#<anchor>")
    func projectTreeIsCompliant() throws {
        let testsRoot = try projectTestsRoot()
        let violators = try DisabledLinkScanner.scan(under: testsRoot, excluding: ["DisabledTestsHaveLinkTest.swift"])
        if !violators.isEmpty {
            Issue.record(
                """
                Every @Test(.disabled("…")) must reference docs/known-flakes.md#<anchor>. Violations:
                \(violators.map { "  - \($0)" }.joined(separator: "\n"))
                """
            )
        }
    }

    /// Anchor-existence check — every `docs/known-flakes.md#<anchor>` referenced
    /// from a real Swift file must resolve to a `## <slug>` heading in the doc.
    /// Catches typos like `#headed-settings-paralel` that the link-presence
    /// rule alone would silently accept.
    @Test("every referenced known-flakes anchor resolves to a real heading")
    func referencedAnchorsExist() throws {
        let testsRoot = try projectTestsRoot()
        let docPath = testsRoot.deletingLastPathComponent()
            .appendingPathComponent("docs/known-flakes.md")
        let docHeadings = try KnownFlakesDoc.headingSlugs(at: docPath)
        let dangling = try DisabledLinkScanner.referencedAnchors(under: testsRoot,
                                                                 excluding: ["DisabledTestsHaveLinkTest.swift"])
            .filter { !docHeadings.contains($0.anchor) }
        if !dangling.isEmpty {
            Issue.record(
                """
                Anchors referenced from .disabled reasons but missing in docs/known-flakes.md:
                \(dangling.map { "  - \($0.location): #\($0.anchor)" }.joined(separator: "\n"))
                Known headings: \(docHeadings.sorted())
                """
            )
        }
    }

    /// Negative-path fixture — proves the scanner *detects* a missing link.
    /// Without this, the rule could silently degrade if the detector were
    /// refactored incorrectly.
    @Test("scanner reports an unlinked .disabled call in a synthesized fixture")
    func scannerCatchesUnlinkedDisable() throws {
        let dir = try makeTempFixtureDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let linked = """
            @Test(.disabled("benign reason (see docs/known-flakes.md#anchor)"))
            func ok() {}
            """
        let unlinked = """
            @Test(.disabled("no link here"))
            func bad() {}
            """
        let multiline = """
            @Test(.disabled(
                "spread across lines, no link"
            ))
            func multi() {}
            """
        let inComment = """
            // explains how to use .disabled("…") — must be ignored
            func legit() {}
            """

        try writeFixture(name: "Linked.swift", body: linked, in: dir)
        try writeFixture(name: "Unlinked.swift", body: unlinked, in: dir)
        try writeFixture(name: "Multiline.swift", body: multiline, in: dir)
        try writeFixture(name: "Comment.swift", body: inComment, in: dir)

        let violators = try DisabledLinkScanner.scan(under: dir, excluding: [])
        #expect(violators.contains(where: { $0.contains("Unlinked.swift") }),
                "single-line unlinked .disabled must be flagged; got \(violators)")
        #expect(violators.contains(where: { $0.contains("Multiline.swift") }),
                "multi-line unlinked .disabled must be flagged; got \(violators)")
        #expect(!violators.contains(where: { $0.contains("Linked.swift") }),
                "linked .disabled must NOT be flagged; got \(violators)")
        #expect(!violators.contains(where: { $0.contains("Comment.swift") }),
                "comment-only mention must NOT be flagged; got \(violators)")
    }

    private func projectTestsRoot(file: StaticString = #filePath) throws -> URL {
        URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
    }

    private func makeTempFixtureDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("disabled-link-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFixture(name: String, body: String, in dir: URL) throws {
        try body.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
}

/// One referenced anchor from a `.disabled` reason in a Swift test file.
struct AnchorReference: Hashable {
    let location: String   // "<rel-path>:<line>"
    let anchor: String     // the slug after `docs/known-flakes.md#`
}

/// Whole-file scanner. Captures every `.disabled("…")` invocation
/// regardless of line layout, ignoring those that appear inside `//`
/// or `///` comment lines. Returns sorted "<rel-path>:<line>" entries.
enum DisabledLinkScanner {
    static func scan(under root: URL, excluding excludedNames: Set<String>) throws -> [String] {
        let fm = FileManager.default
        let opts: FileManager.DirectoryEnumerationOptions = [
            .skipsHiddenFiles, .skipsPackageDescendants
        ]
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: opts) else {
            return []
        }
        var violators: [String] = []
        let pattern = #/\.disabled\s*\(\s*"((?:[^"\\]|\\.)*?)"\s*\)/#
        for case let url as URL in walker
            where url.pathExtension == "swift" && !excludedNames.contains(url.lastPathComponent) {
            let source = try String(contentsOf: url, encoding: .utf8)
            let stripped = stripCommentLines(source)
            for match in stripped.matches(of: pattern) {
                let reason = String(match.output.1)
                if reason.contains("docs/known-flakes.md#") { continue }
                let line = lineNumber(of: match.range.lowerBound, in: stripped)
                let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
                violators.append("\(rel):\(line)")
            }
        }
        return violators.sorted()
    }

    /// Replaces every `//`-prefixed comment line with whitespace of equal
    /// length so line numbers stay aligned but the regex doesn't see the
    /// comment text.
    private static func stripCommentLines(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                line.trimmingCharacters(in: .whitespaces).hasPrefix("//")
                    ? Substring(String(repeating: " ", count: line.count))
                    : line
            }
            .joined(separator: "\n")
    }

    private static func lineNumber(of index: String.Index, in source: String) -> Int {
        source[..<index].reduce(into: 1) { count, ch in if ch == "\n" { count += 1 } }
    }

    /// All `docs/known-flakes.md#<anchor>` references found in `.disabled` reasons.
    static func referencedAnchors(under root: URL,
                                  excluding excludedNames: Set<String>) throws -> [AnchorReference] {
        let fm = FileManager.default
        let opts: FileManager.DirectoryEnumerationOptions = [
            .skipsHiddenFiles, .skipsPackageDescendants
        ]
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: opts) else {
            return []
        }
        var refs: [AnchorReference] = []
        let pattern = #/\.disabled\s*\(\s*"((?:[^"\\]|\\.)*?)"\s*\)/#
        let anchorPattern = #/docs/known-flakes\.md#([A-Za-z0-9_-]+)/#
        for case let url as URL in walker
            where url.pathExtension == "swift" && !excludedNames.contains(url.lastPathComponent) {
            let source = try String(contentsOf: url, encoding: .utf8)
            let stripped = stripCommentLines(source)
            for match in stripped.matches(of: pattern) {
                let reason = String(match.output.1)
                guard let anchorMatch = reason.firstMatch(of: anchorPattern) else { continue }
                let line = lineNumber(of: match.range.lowerBound, in: stripped)
                let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
                refs.append(AnchorReference(location: "\(rel):\(line)",
                                            anchor: String(anchorMatch.output.1)))
            }
        }
        return refs.sorted { $0.location < $1.location }
    }
}

/// Reads `## <heading>` lines out of `docs/known-flakes.md` and returns
/// each as a kebab-case slug suitable for matching `#<anchor>` links.
enum KnownFlakesDoc {
    static func headingSlugs(at url: URL) throws -> Set<String> {
        let body = try String(contentsOf: url, encoding: .utf8)
        var slugs: Set<String> = []
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.hasPrefix("## ") else { continue }
            let title = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
            slugs.insert(slugify(title))
        }
        return slugs
    }

    /// Lowercase, replace runs of non-alphanumeric chars with single '-',
    /// trim leading/trailing '-'. Matches the slug format used by GitHub
    /// and most Markdown renderers.
    static func slugify(_ s: String) -> String {
        let lower = s.lowercased()
        var out = ""
        var lastWasDash = false
        for ch in lower {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastWasDash = false
            } else if !lastWasDash {
                out.append("-")
                lastWasDash = true
            }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
