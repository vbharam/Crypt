//
//  URLSession+SanitizedResponse.swift
//  Crypt
//
//  Created by Mitul Manish on 21/10/18.
//  Copyright © 2018 Mitul Manish. All rights reserved.
//

import Foundation

enum NetworkResult {
    case success(data: Data)
    case error(reason: Error)
    case unexpected
}

extension URLSession {
    func getData(request: URLRequest, dataResponse: @escaping (NetworkResult) -> ()) {
        dataTask(with: request) { (serverData, serverResponse, networkError) in
            let validStatusCodeRange: ClosedRange<Int> = 200...299
            switch (serverData, serverResponse, networkError) {
            case (_, _, let error?):
                dataResponse(.error(reason: error))
            case(let data?, let response as HTTPURLResponse, _)
                where validStatusCodeRange.contains(response.statusCode):
                dataResponse(.success(data: data))
            default:
                dataResponse(.unexpected)
            }
        }.resume()
    }
}
