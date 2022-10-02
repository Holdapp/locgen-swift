import Foundation

extension String {
    func asURL() throws -> URL {
        if let url = URL(string: self) {
            return url
        } else {
            throw InternalError.cantParsePath(self)
        }
    }
    
    func asFileURL() throws -> URL {
        return URL(fileURLWithPath: self)
    }
}

extension URL {
    func isWeb() throws -> Bool {
        if let components = URLComponents(url: self, resolvingAgainstBaseURL: true) {
            if components.scheme != nil {
                return true
            } else {
                return false
            }
        } else {
            throw InternalError.cantParsePath(self.absoluteString)
        }
    }
}
