//
//  UIViewController+Alert.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

enum EditActionType {
    case delete, restore

    func actionTitle(editDataCount: Int) -> String {
        switch self {
        case .delete:
            return "\(editDataCount)項目を削除"
        case .restore:
            return "すべての写真を復元"
        }
    }

    var finishMessage: String {
        switch self {
        case .delete:
            return "削除が完了しました"
        case .restore:
            return "復元が完了しました"
        }
    }
}

extension UIViewController {

    func showAttentionAlert(title: String? = "注意", message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let close = UIAlertAction(title: "閉じる", style: .default, handler: nil)
        alert.addAction(close)
        self.present(alert, animated: true)
    }

    func showConfirmationActionSheet(actionType: EditActionType, editDataCount: Int, actionHandler: ((UIAlertAction) -> ())?) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let action = UIAlertAction(title: actionType.actionTitle(editDataCount: editDataCount),
                                   style: .destructive,
                                   handler: actionHandler)
        let cancel = UIAlertAction(title: "キャンセル", style: .cancel, handler: nil)
        actionSheet.addAction(action)
        actionSheet.addAction(cancel)
        self.present(actionSheet, animated: true)
    }

    func showFinishLabel(actionType: EditActionType) {
        if !self.view.subviews.isEmpty, let frontView = self.view.subviews.last as? FinishView {
            // すでに出ていたら消す
            frontView.removeFromSuperview()
        }

        let finishView = FinishView.make()
        finishView.frame = CGRect(x: 0,
                                  y: 0,
                                  width: self.view.bounds.size.width * 0.8,
                                  height: self.view.bounds.size.height * 0.08)
        finishView.messageLabel.text = actionType.finishMessage
        finishView.isHidden = true
        finishView.alpha = 0.0
        finishView.center.x = self.view.center.x
        finishView.center.y = self.view.center.y * 1.7
        self.view.addSubview(finishView)

        UIView.animateKeyframes(withDuration: 6.0, delay: 0.3, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.05, animations: {
                finishView.isHidden = false
                finishView.alpha = 1.0
            })
            UIView.addKeyframe(withRelativeStartTime: 0.83, relativeDuration: 0.1, animations: {
                finishView.alpha = 0.0
            })
        }, completion: { (_) in
            finishView.removeFromSuperview()
        })
    }

}
