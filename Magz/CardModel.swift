//
//  CardModel.swift
//  Magz
//
//  Created by Nate  on 5/30/25.
//

import Foundation
import UIKit

struct CardModel: Decodable {
    let identifier: String
    var thumbnailURL: URL? {
        return URL(string:
            //"https://archive.org/download/\(identifier)/page/cover.jpg")
            "https://archive.org/services/img/\(identifier)")
    }
}

struct ArchiveSearchResponse: Decodable {
    struct Response: Decodable {
        let docs: [CardModel]
    }
    let response: Response
}

class ArchiveService {
    func fetchMagazines(completion: @escaping ([CardModel]) -> Void) {
        let urlStr = "https://archive.org/advancedsearch.php?q=collection:computermagazines+AND+licenseurl:*publicdomain*&fl[]=identifier&sort[]=downloads+desc&rows=1070&page=1&output=json"
        
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Fetch error: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ArchiveSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(decoded.response.docs)
                }
            } catch {
                print("Decoding error: \(error)")
                completion([])
            }
        }.resume()
    }
}


