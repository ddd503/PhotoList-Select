//
//  PhotoListViewCollectionViewCell.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit
import Photos

final class PhotoListViewCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak private var photoImageView: UIImageView!
    @IBOutlet weak private var checkMarkView: UIImageView!

    static var identifier: String {
        return String(describing: self)
    }

    static func nib() -> UINib {
        return UINib(nibName: identifier, bundle: .main)
    }

    func setImage(asset: PHAsset?) {
        if let asset = asset {
            PHImageManager.default().requestImage(for: asset,
                                                  targetSize: CGSize(width: 185, height: 185),
                                                  contentMode: .aspectFill,
                                                  options: nil) { [weak self] (image, info) in
                                                    self?.photoImageView.image = image
            }
        } else {
            photoImageView.image = UIImage(named: "no_image")
        }
    }

    func updateCheckMarkView() {
        checkMarkView.isHidden.toggle()
    }

    func resetCheckMarkView() {
        checkMarkView.isHidden = true
    }

}
