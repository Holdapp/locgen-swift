//

import Foundation

struct Config: Codable {
    var key: String
    var languages: [String: String]
    var dirs: [String: String]?
    var filenames: [String: String]?
}
