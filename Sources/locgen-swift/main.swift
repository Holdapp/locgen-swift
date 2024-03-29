import ArgumentParser
import Darwin

struct LocgenOptions: ParsableArguments {
    static let shared = LocgenOptions.parseOrExit()
    
    @Option(name: .long, help: "URL or path to xlsx file")
    var input: String
    
    @Option(name: .long, parsing: .upToNextOption, help: "XLSX sheet name[s] with translations. If not specified, the first sheet will be used.")
    var sheets: [String]
    
    @Option(name: .long, help: "Map (yml) for XLSX file")
    var map: String
}

let options = LocgenOptions.shared

let parser = LocgenTask(arguments: options)
do {
    try parser.run()
} catch {
    if let internalError = error as? InternalError {
        print("[Error] \(internalError.message)")
        if internalError.showHelp {
            print(LocgenOptions.helpMessage())
        }
    } else {
        print("[Error] \(error)")
    }
}
