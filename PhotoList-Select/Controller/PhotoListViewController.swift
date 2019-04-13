//
//  PhotoListViewController.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

final class PhotoListViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    private func setup() {
        PhotoLibraryDataStore.requestAuthorization { [weak self] (success) in
            guard success else {
                self?.showAttentionAlert(title: "アクセスできません", message: "写真ライブラリへのアクセスが許可されていません。")
                return
            }
            print("許可成功")
        }
    }

}
