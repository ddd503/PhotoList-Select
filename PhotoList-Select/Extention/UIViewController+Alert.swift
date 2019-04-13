//
//  UIViewController+Alert.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

extension UIViewController {

    func showAttentionAlert(title: String? = "注意", message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let close = UIAlertAction(title: "閉じる", style: .default, handler: nil)
        alert.addAction(close)
        self.present(alert, animated: true)
    }

}
