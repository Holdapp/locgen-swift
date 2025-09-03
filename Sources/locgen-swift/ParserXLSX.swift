import Foundation
import CoreXLSX
import Yams

class ParserXLSX {
    private let sheets: [String]
    private var fileContent: [URL: String] = [:]
    private var columns: Set<String> = []
    
    init(sheets: [String]) {
        self.sheets = sheets
    }
    
    func parse(xlsxData: Data, config: Config) throws {
        let file = try  XLSXFile(data: xlsxData)
        
        try proceed(file: file, config: config)
    }
    
    private func proceed(file: XLSXFile, config: Config) throws {
        let workbooks = try file.parseWorkbooks()
        
        guard !workbooks.isEmpty else {
            throw InternalError.emptyArray("No workbooks in XLSX file")
        }

        let sheetNames = Set(sheets)
        var selectedWorksheets: [(String, Worksheet)] = []
        for workbook in workbooks {
            for (name, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                guard let name = name else {
                    continue
                }
                
                guard sheetNames.contains(name) || sheetNames.isEmpty else {
                    continue
                }
                
                selectedWorksheets.append((name, try file.parseWorksheet(at: path)))
                if sheetNames.isEmpty {
                    break
                }
            }
        }
        
        if sheetNames.isEmpty && selectedWorksheets.isEmpty {
            throw InternalError.cantFind("Any worksheet")
        } else if !sheetNames.isEmpty && selectedWorksheets.count != sheetNames.count {
            throw InternalError.cantFind("Worksheets with names: `\(sheets)`")
        }

        let strings =  try file.parseSharedStrings()
        
        for (sheetName, worksheet) in selectedWorksheets {
            try proceed(worksheet: worksheet, worksheetName: sheetName, config: config, sharedStrings: strings)
        }
    }
    
    private func proceed(worksheet: Worksheet, worksheetName: String, config: Config, sharedStrings: SharedStrings?) throws {
        let workingDirectoryURL = try FileManager.default.currentDirectoryPath.asFileURL()
        
        guard let data = worksheet.data else {
            throw InternalError.emptyData("No data for worksheet `\(worksheetName)`")
        }
        
        guard let headerRow = data.rows.first else {
            throw InternalError.emptyData("No rows to read in \(worksheetName) sheet")
        }

        guard !config.languages.isEmpty else {
            throw InternalError.emptyArray("map (yml) `languages` can't be empty, should have at least one pair")
        }
   
        var mainKeyRef: ColumnReference? = nil
        var languageColumns: [String: ColumnReference] = [:]
        
        for cell in headerRow.cells {
            let value = extractValue(from: cell, sharedStrings: sharedStrings)
            
            if let value = value {
                if value == config.key {
                    mainKeyRef = cell.reference.column
                } else if let object = config.languages.first(where: {_, val in return val == value }) {
                    languageColumns[object.key] = cell.reference.column
                }
            }
        }
        
        guard let mainKeyRef = mainKeyRef else {
            throw InternalError.cantFind("Can't find column named `\(config.key)` in xlsx file")
        }
        
        let languagesDiff = Set(config.languages.keys).symmetricDifference(Set(languageColumns.keys))
        guard languagesDiff.count == .zero else {
            let missingValues = languagesDiff.compactMap { config.languages[$0] }
            throw InternalError.cantFind("Can't find languages `\(missingValues)` in xlsx file")
        }
        
        var isFirstRow = true
        var processedKeys: [String] = []
        var skippedRows = 0
        
        print("🔍 Processing \(data.rows.count - 1) data rows...")
        
        for i in 1..<data.rows.count {
            let row = data.rows[i]
            let keyCell = row.cells.first(where: { cell in return cell.reference.column.value == mainKeyRef.value })
            
            if let keyvalue = extractValue(from: keyCell, sharedStrings: sharedStrings), !keyvalue.isEmpty {
                print("✅ Processing key: '\(keyvalue)'")
                processedKeys.append(keyvalue)
                
                try updateStrings(
                    key: keyvalue,
                    row: row,
                    sharedStrings: sharedStrings,
                    languageMap: languageColumns,
                    isFirstRow: isFirstRow,
                    dirsMap: config.dirs,
                    namesMap: config.filenames,
                    workingDir: workingDirectoryURL
                )
                
                isFirstRow = false
            } else {
                skippedRows += 1
                let keyValue = keyCell?.value ?? "nil"
                print("⏭️ Skipping row \(i): key cell value = '\(keyValue)' (empty or nil)")
            }
        }
        
        print("📊 Summary: Processed \(processedKeys.count) keys, skipped \(skippedRows) rows")
        
        writeData()
    }
    
    private func extractValue(from cell: Cell?, sharedStrings: SharedStrings?) -> String? {
        guard let cell = cell else {
            return nil
        }
        
        columns.insert(cell.reference.column.value)
        
        // For shared string cells (type 's'), try cell.stringValue first, then direct lookup
        if cell.type == .sharedString, let sharedStrings = sharedStrings {
            if let stringValue = cell.stringValue(sharedStrings) {
                // Debug specific indices
                if cell.value == "6396" || cell.value == "6413" {
                    print("🐛 cell.stringValue result for index \(cell.value ?? "nil"): '\(stringValue)'")
                }
                return stringValue
            }
            
            // Fallback: direct lookup in shared strings
            if let cellValue = cell.value,
               let index = Int(cellValue),
               index < sharedStrings.items.count {
                let item = sharedStrings.items[index]
                
                // Check if text is available directly
                if let text = item.text {
                    return text
                }
                
                // If text is nil, try to extract from richText runs
                let mirror = Mirror(reflecting: item)
                for child in mirror.children {
                    if child.label == "richText", let richTextRuns = child.value as? [Any] {
                        var combinedText = ""
                        
                        for run in richTextRuns {
                            let runMirror = Mirror(reflecting: run)
                            for runChild in runMirror.children {
                                if runChild.label == "text", let text = runChild.value as? String? {
                                    if let text = text {
                                        combinedText += text
                                    }
                                }
                            }
                        }
                        
                        if !combinedText.isEmpty {
                            return combinedText
                        }
                    }
                }
                
                return nil
            }
            
            // If shared string lookup fails, return nil
            return nil
        }
        // For other cells with shared strings available, try stringValue method
        else if let sharedStrings = sharedStrings, let stringValue = cell.stringValue(sharedStrings) {
            return stringValue
        }
        // For direct value cells, return the value if it's not numeric or if it's text
        else if let cellValue = cell.value, Int(cellValue) == nil {
            return cellValue
        }
        // For numeric cells, return as string
        else if let cellValue = cell.value {
            return cellValue
        }
        else {
            return nil
        }
    }
    
    private func updateStrings(
        key: String,
        row: Row,
        sharedStrings: SharedStrings?,
        languageMap: [String: ColumnReference],
        isFirstRow: Bool,
        dirsMap: [String: String]?,
        namesMap: [String: String]?,
        workingDir: URL
    ) throws {
        for (lang, columnRef) in languageMap {
            let cell = row.cells.first(where: { cell in return cell.reference.column.value == columnRef.value })
            let translation = extractValue(from: cell, sharedStrings: sharedStrings)
            
            guard cell != nil, let translation = translation, !translation.isEmpty else {
                continue
            }
            
            let fileURL = fileURL(
                workingDirectory: workingDir,
                fileDir: dirsMap?[lang] ?? "\(lang).lproj",
                fileName: namesMap?[lang] ?? "Localizable.strings"
            )
            
            if isFirstRow {
                try createDirectoryIfNeeded(for: fileURL)
                try deleteFile(at: fileURL)
            }
            
            let escapedTranslation = escapeQuotes(in: translation)
            let textLine = "\"\(key)\" = \"\(escapedTranslation)\";\n"
            
            
            try append(line: textLine, to: fileURL)
        }
    }
    
    private func fileURL(workingDirectory url: URL, fileDir: String, fileName: String) -> URL {
        url.appendingPathComponent(fileDir).appendingPathComponent(fileName)
    }
    
    private func deleteFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        try FileManager.default.removeItem(at: url)
    }
    
    private func createDirectoryIfNeeded(for fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
    }
    
    private func append(line: String, to file: URL) throws {
        if fileContent[file] == nil {
            fileContent[file] = line
        } else {
            var newContent = fileContent[file]
            newContent?.append(line)
            fileContent[file] = newContent
        }
    }

    private func writeData() {
        for(fileURL, content) in fileContent {
            FileManager.default.createFile(atPath: fileURL.path, contents: content.data(using: .utf8), attributes: nil)
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
}
