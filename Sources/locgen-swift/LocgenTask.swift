//

import Foundation
import Yams

struct LocgenTask {
    private let queue = DispatchQueue(label: "com.holdapp.locgen.queue")
    private let semaphore = DispatchSemaphore(value: 0)
    private let downloadManager = DownloadManager()
    private let inputPath: String
    private let mapPath: String
    private let sheets: [String]
    
    init(arguments: LocgenOptions) {
        self.inputPath = arguments.input
        self.mapPath = arguments.map
        self.sheets = arguments.sheets
    }
    
    func run() throws {
        guard let mapPath = mapPath.removingPercentEncoding else {
            fatalError()
        }
        
        guard let inputPath = inputPath.removingPercentEncoding else {
            fatalError()
        }
        
        var forwardedError: Error?
        var xlsxData: Data!
        var mapData: Data!
        
        let xlsxURL = try inputPath.replacingOccurrences(of: "\\", with: "").asURL()
        if try xlsxURL.isWeb() {
            downloadManager.enqueue(url: xlsxURL, id: "xlsx")
        } else {
            xlsxData = try Data(contentsOf: try self.inputPath.asFileURL())
        }
        
        let mapURL = try mapPath.replacingOccurrences(of: "\\", with: "").asURL()
        if try mapURL.isWeb() {
            downloadManager.enqueue(url: mapURL, id: "map")
        } else {
            mapData = try Data(contentsOf: try self.mapPath.asFileURL())
        }
        
        downloadManager.execute { responses in
            if let xlsxResponse = responses.filter({ $0.id == "xlsx" }).first {
                forwardedError = xlsxResponse.error
                if let data = xlsxResponse.data {
                    xlsxData = data
                }
            }
            
            if let mapResponse = responses.filter({ $0.id == "map" }).first {
                forwardedError = mapResponse.error
                if let data = mapResponse.data {
                    mapData = data
                }
            }
        }
        
        guard forwardedError == nil else {
            throw forwardedError!
        }
        
        let config = try YAMLDecoder().decode(Config.self, from: mapData)
        let xlsxParser = ParserXLSX(sheets: sheets)
        try xlsxParser.parse(xlsxData: xlsxData, config: config)
    }
}

