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

    func showFinishLabel() {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width * 0.8, height: self.view.bounds.size.height * 0.08))
        label.center.x = self.view.center.x
        label.center.y = self.view.center.y * 1.8
        label.text = "削除が完了しました。"
        label.backgroundColor = .darkGray
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 20)
        label.isHidden = true
        label.alpha = 0.0
        self.view.addSubview(label)

        UIView.animateKeyframes(withDuration: 6.0, delay: 0.5, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.1, animations: {
                label.isHidden = false
                label.alpha = 1.0
            })
            UIView.addKeyframe(withRelativeStartTime: 0.83, relativeDuration: 0.1, animations: {
                label.alpha = 0.0
            })
        }, completion: { (_) in
            label.removeFromSuperview()
        })
    }

}
