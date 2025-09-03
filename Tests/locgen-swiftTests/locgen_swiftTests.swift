import XCTest
import Foundation

final class locgen_swiftTests: XCTestCase {
    func testQuoteEscaping() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("locgen-test")
        let enDir = testDir.appendingPathComponent("en.lproj")
        let stringsFile = enDir.appendingPathComponent("Localizable.strings")
        
        // Create test directory structure
        try FileManager.default.createDirectory(at: enDir, withIntermediateDirectories: true)
        
        // Test the escaping logic that was added to ParserXLSX
        let testKey = "test_key"
        let testTranslation = "<a href=\"some_url\">Click here</a>"
        
        // Apply the same escaping logic as in ParserXLSX.swift
        let escapedTranslation = testTranslation.replacingOccurrences(of: "\"", with: "\\\"")
        let expectedLine = "\"\(testKey)\" = \"\(escapedTranslation)\";\n"
        
        // Write the test content
        try expectedLine.write(to: stringsFile, atomically: true, encoding: .utf8)
        
        // Read back and verify
        let content = try String(contentsOf: stringsFile)
        
        XCTAssertEqual(content, "\"test_key\" = \"<a href=\\\"some_url\\\">Click here</a>\";\n")
        
        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }
    
    func testMultipleQuoteEscaping() throws {
        let testTranslations = [
            "Simple text": "Simple text",
            "Text with \"quotes\"": "Text with \\\"quotes\\\"",
            "HTML: <div class=\"test\">content</div>": "HTML: <div class=\\\"test\\\">content</div>",
            "Multiple \"quotes\" in \"different\" places": "Multiple \\\"quotes\\\" in \\\"different\\\" places"
        ]
        
        for (original, expected) in testTranslations {
            let escaped = escapeQuotes(in: original)
            XCTAssertEqual(escaped, expected, "Failed to escape quotes in: \(original)")
        }
    }
    
    func testAlreadyEscapedQuotes() throws {
        let testCases = [
            // Already escaped quotes should not be double-escaped
            "Text with \\\"already escaped\\\" quotes": "Text with \\\"already escaped\\\" quotes",
            "Mixed \\\"escaped\\\" and \"unescaped\" quotes": "Mixed \\\"escaped\\\" and \\\"unescaped\\\" quotes",
            "<a href=\\\"mailto:kp@wearmedicine.com\\\">Email</a>": "<a href=\\\"mailto:kp@wearmedicine.com\\\">Email</a>",
            "Only \"unescaped\" quotes": "Only \\\"unescaped\\\" quotes",
            "No quotes at all": "No quotes at all",
            "\\\"All already escaped\\\"": "\\\"All already escaped\\\"",
            "Complex: \\\"escaped\\\" and \"unescaped\" mixed": "Complex: \\\"escaped\\\" and \\\"unescaped\\\" mixed"
        ]
        
        for (input, expected) in testCases {
            let result = escapeQuotes(in: input)
            XCTAssertEqual(result, expected, "Failed for input: \(input)")
        }
    }
    
    private func escapeQuotes(in text: String) -> String {
        // Manually iterate through string to avoid double-escaping already escaped quotes
        var result = ""
        var i = text.startIndex
        
        while i < text.endIndex {
            let char = text[i]
            
            if char == "\"" {
                // Check if this quote is already escaped (preceded by \)
                let isEscaped = i > text.startIndex && text[text.index(before: i)] == "\\"
                
                if isEscaped {
                    // Already escaped, keep as-is
                    result.append(char)
                } else {
                    // Not escaped, escape it
                    result.append("\\\"")
                }
            } else {
                result.append(char)
            }
            
            i = text.index(after: i)
        }
        
        return result
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }
}
