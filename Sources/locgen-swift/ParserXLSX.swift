//

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
        for i in 1..<data.rows.count {
            let row = data.rows[i]
            let keyCell = row.cells.first(where: { cell in return cell.reference.column.value == mainKeyRef.value })
            guard let keyvalue = extractValue(from: keyCell, sharedStrings: sharedStrings), !keyvalue.isEmpty else {
                continue
            }
            
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
        }
        
        writeData()
    }
    
    private func extractValue(from cell: Cell?, sharedStrings: SharedStrings?) -> String? {
        guard let cell = cell else {
            return nil
        }
        
        columns.insert(cell.reference.column.value)
        if let cellValue = cell.value, Int(cellValue) == nil {
            return cell.value
        } else if let sharedStrings = sharedStrings, cell.stringValue(sharedStrings) != nil {
            return cell.stringValue(sharedStrings)
        } else {
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
            guard
                let cell = row.cells.first(where: { cell in return cell.reference.column.value == columnRef.value }),
                let translation = extractValue(from: cell, sharedStrings: sharedStrings)
            else {
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
            
            let textLine = "\"\(key)\" = \"\(translation)\";\n"
            
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
}
