//
//  FinishView.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/20.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

class FinishView: UIView {

    @IBOutlet weak var messageLabel: UILabel!

    class func make() -> FinishView {
        let view = UINib(nibName: String(describing: FinishView.self), bundle: .main).instantiate(withOwner: self, options: nil).first as! FinishView
        return view
    }

}
