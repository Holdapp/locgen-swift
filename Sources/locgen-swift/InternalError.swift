//

import Foundation

enum InternalError: Error {
    case omitedOption(String)
    case empty(String)
    case fileNotFound(String)
    case cantParsePath(String)
    case downloadFailed(String)
    case emptyData(String)
    case emptyArray(String)
    case cantFind(String)
    case cantConvert(String)
    case missingParam(String)
    
    var message: String {
        var defaultMessage = ""
        var additionalInfo = ""
        
        switch self {
        case .omitedOption(let info):
            defaultMessage = "Option required"
            additionalInfo = info
        case .empty(let info):
            defaultMessage = "Empty value"
            additionalInfo = info
        case .fileNotFound(let info):
            defaultMessage = "File not found"
            additionalInfo = info
        case .cantParsePath(let info):
            defaultMessage = "Can't parse input path"
            additionalInfo = info
        case .downloadFailed(let info):
            defaultMessage = "Downloading failed."
            additionalInfo = info
        case .emptyData(let info):
            defaultMessage = "Data object is empty or nil"
            additionalInfo = info
        case .emptyArray(let info):
            defaultMessage = "Array is empty or nil"
            additionalInfo = info
        case .cantFind(let info):
            defaultMessage = "Can't find item[s]"
            additionalInfo = info
        case .cantConvert(let info):
            defaultMessage = "Can't convert data"
            additionalInfo = info
        case .missingParam(let info):
            defaultMessage = "Missing param"
            additionalInfo = info
        }
        
        if !additionalInfo.isEmpty {
            return "\(defaultMessage). Info (\(additionalInfo))"
        } else {
            return defaultMessage
        }
    }
    
    var showHelp: Bool {
        switch self {
        case .omitedOption:
            return true
        default:
            return false
        }
    }
}
