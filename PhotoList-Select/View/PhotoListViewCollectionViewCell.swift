//
//  PhotoListViewCollectionViewCell.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

final class PhotoListViewCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak private var photoImageView: UIImageView!
    @IBOutlet weak private var checkMarkView: UIImageView!

    static var identifier: String {
        return String(describing: self)
    }

    static func nib() -> UINib {
        return UINib(nibName: identifier, bundle: .main)
    }

}
