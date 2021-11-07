//

import Foundation

class InputParser: NSObject {
    private let queue = DispatchQueue(label: "com.holdapp.locgen.queue")
    private let semaphore = DispatchSemaphore(value: 0)
    private let downloadManager = DownloadManager()
    private let arguments: LocgenOptions
    private let inputPath: String
    private let map: String
    private let sheet: String
    private lazy var xlsxParser = ParserXLSX()
    
    init(arguments: LocgenOptions) {
        self.arguments = arguments
        self.inputPath = arguments.input?.removingPercentEncoding ?? ""
        self.map = arguments.map?.removingPercentEncoding ?? ""
        self.sheet = arguments.sheet ?? ""
    }
    
    func run() throws {
        guard !inputPath.isEmpty else {
            throw InternalError.omitedOption("`--input` option can't be empty")
        }
        
        guard !sheet.isEmpty else {
            throw InternalError.omitedOption("`--sheet` option can't be empty")
        }
        
        guard !map.isEmpty else {
            throw InternalError.omitedOption("`--map` option can't be empty")
        }
        
        var forwardedError: Error?
        var xlsxData: Data!
        var mapData: Data!
        
        let xlsxURL = try self.inputPath.replacingOccurrences(of: "\\", with: "").asURL()
        if try xlsxURL.isWeb() {
            downloadManager.enqueue(url: xlsxURL, id: "xlsx")
        } else {
            xlsxData = try Data(contentsOf: try self.inputPath.asFileURL())
        }
        
        let mapURL = try self.map.replacingOccurrences(of: "\\", with: "").asURL()
        if try mapURL.isWeb() {
            downloadManager.enqueue(url: mapURL, id: "map")
        } else {
            mapData = try Data(contentsOf: try self.map.asFileURL())
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
       
        try xlsxParser.parse(xlsxData: xlsxData, mapData: mapData)
    }
}

