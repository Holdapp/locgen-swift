//

import Foundation
import CoreXLSX
import Yams

class ParserXLSX {
    
    private let mainKey = "key-ios"
    private let commentKey = "comment"
    private let languagesKey = "languages"
    private let dirsKey = "dirs"
    private let namesKey = "names"
    
    private var fileContent: [URL: String] = [:]
    private var columns: Set<String> = []
    
    func parse(xlsxData: Data, mapData: Data) throws {
        let map = try processMap(mapData: mapData)
        let file = try  XLSXFile(data: xlsxData)
        
        try proceed(file: file, map: map)
    }
    
    private func processMap(mapData: Data) throws -> [String: Any] {
        if let yamlString = String(bytes: mapData, encoding: .utf8) {
            if let yaml = try Yams.load(yaml: yamlString) as? [String: Any] {
                return yaml
            } else {
                throw InternalError.cantConvert("\n\(yamlString)\n")
            }
        } else {
            throw InternalError.cantConvert("Map data")
        }
    }
    
    private func proceed(file: XLSXFile, map: [String: Any]) throws {
        let workbooks = try file.parseWorkbooks()
        
        guard !workbooks.isEmpty else {
            throw InternalError.emptyArray("No workbooks in XLSX file")
        }
    
        var selectedWorksheet: Worksheet?
        for workbook in workbooks {
            for (name, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                if let selectedSheetName = LocgenOptions.shared.sheet {
                    if name == selectedSheetName {
                        selectedWorksheet = try file.parseWorksheet(at: path)
                    }
                    
                    break
                }
            }
        }
        
        guard let worksheet = selectedWorksheet else {
            throw InternalError.cantFind("Worksheet with name: `\(LocgenOptions.shared.sheet ?? "")`")
        }

        let strings =  try file.parseSharedStrings()
        
        try proceed(worksheet: worksheet, map: map, sharedStrings: strings)
    }
    
    private func proceed(worksheet: Worksheet, map: [String: Any], sharedStrings: SharedStrings?) throws {
        let workingDirectoryURL = try FileManager.default.currentDirectoryPath.asFileURL()
        
        guard let data = worksheet.data else {
            throw InternalError.emptyData("No data for worksheet `\(LocgenOptions.shared.sheet ?? "")`")
        }
        
        guard let headerRow = data.rows.first else {
            throw InternalError.emptyData("No rows to read in \(LocgenOptions.shared.sheet ?? "") sheet")
        }

        guard let mainKeyMap = map[mainKey] as? String else {
            throw InternalError.missingParam("Can't find `key-ios` key in map (yml) file")
        }
        
        guard let languagesMap = map[languagesKey] as? [String: String] else {
            throw InternalError.missingParam("Can't find `languages` key in map (yml) file")
        }
        
        guard !languagesMap.isEmpty else {
            throw InternalError.emptyArray("map (yml) `languages` can't be empty, should have at least one pair")
        }
        
        let dirsMap = map[dirsKey] as? [String: String]
        let namesMap = map[namesKey] as? [String: String]
   
        var mainKeyRef: ColumnReference? = nil
        var languageColumns: [String: ColumnReference] = [:]
        
        for cell in headerRow.cells {
            let value = extractValue(from: cell, sharedStrings: sharedStrings)
            
            if let value = value {
                if value == mainKeyMap {
                    mainKeyRef = cell.reference.column
                } else if let object = languagesMap.first(where: {_, val in return val == value }) {
                    languageColumns[object.key] = cell.reference.column
                }
            }
        }
        
        guard let mainKeyRef = mainKeyRef else {
            throw InternalError.cantFind("Can't find column named `\(mainKeyMap)` in xlsx file")
        }
        
        let languagesDiff = Set(languagesMap.keys).symmetricDifference(Set(languageColumns.keys))
        guard languagesDiff.count == .zero else {
            let missingValues = languagesDiff.compactMap { languagesMap[$0] }
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
                dirsMap: dirsMap,
                namesMap: namesMap,
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
