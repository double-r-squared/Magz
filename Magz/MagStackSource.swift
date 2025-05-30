//
//  CardStackSource.swift
//  SwiftUICardStack
//
//  Created by Peter Larson on 5/28/21.
//

import UIKit

class MagStackSource<Item> {
    // Builder function to convert an item into a UIView
    let builder: (Item) -> UIView

    // The items to render
    private(set) var items: [Item]

    // The corresponding views, built lazily
    private(set) lazy var views: [UIView] = items.map(builder)

    init(items: [Item], builder: @escaping (Item) -> UIView) {
        self.items = items
        self.builder = builder
    }
}

