import Foundation

struct DownloadResponse {
    let id: String
    let data: Data?
    let error: Error?
    let urlResponse: URLResponse?
}

class DownloadManager {
    private var tasks: [URLSessionDataTask] = []
    private var responses: [DownloadResponse] = []
    private var semaphore = DispatchSemaphore(value: 0)
    
    var hasEnquedTasks: Bool {
        !tasks.isEmpty
    }
    
    func enqueue(url: URL, id: String) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else {
                return
            }
            
            self.responses.append(
                .init(
                    id: id,
                    data: data,
                    error: error,
                    urlResponse: response
                )
            )
            
            self.semaphore.signal()
        }
        
        tasks.append(task)
    }
    
    func execute(finished: ([DownloadResponse]) -> ()) {
        guard hasEnquedTasks else {
            finished([])
            return
        }
        
        semaphore = DispatchSemaphore(value: tasks.count - 1)
        
        for task in tasks {
            task.resume()
        }
        
        semaphore.wait()
        
        finished(responses)
    }
}
