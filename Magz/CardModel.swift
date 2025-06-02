//
//  CardModel.swift
//  Magz
//
//  Created by Nate  on 5/30/25.
//

import Foundation
struct CardModel: Decodable {
    let identifier: String
    var thumbnailURL: URL? {
        return URL(string:
            "https://archive.org/download/\(identifier)/page/cover.jpg")
            //"https://archive.org/services/img/\(identifier)")
    }
}

