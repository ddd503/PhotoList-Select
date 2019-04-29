//
//  PhotoListFooterView.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/29.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

final class PhotoListFooterView: UICollectionReusableView {

    @IBOutlet weak private var countLabel: UILabel!
    @IBOutlet weak private var spaceView: UIView!

    static var identifier: String {
        return String(describing: self)
    }

    static func nib() -> UINib {
        return UINib(nibName: identifier, bundle: nil)
    }

    func setCount(_ count: Int) {
        countLabel.text = "\(count)枚"
    }

    func setSpaceViewHeight(_ height: CGFloat) {
        spaceView.frame.size.height = height
    }

}
