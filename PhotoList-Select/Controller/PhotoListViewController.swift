//
//  PhotoListViewController.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

final class PhotoListViewController: UIViewController {

    @IBOutlet weak var photoListView: UICollectionView!
    private let coreDataStore = CoreDataStore()
    private var assetEntitys = [AssetEntity]()
    // 選択状態のセルを管理する
    private var selectedCellDic = [IndexPath: Bool]()
    // 削除結果が保存されるまで使用される仮領域
    private var deleteItemsIdDic = [String: Bool]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if !editing {
            deselectCell()
            selectedCellDic = [:]
            deleteItemsIdDic = [:]
        }
        setTrashButtonIsHidden(!editing)
    }

    private func setup() {
        photoListView.dataSource = self
        photoListView.delegate = self
        photoListView.register(PhotoListViewCollectionViewCell.nib(),
                               forCellWithReuseIdentifier: PhotoListViewCollectionViewCell.identifier)
        photoListView.allowsMultipleSelection = true

        navigationItem.rightBarButtonItem = editButtonItem
        let trushButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(didTapTrashButton))
        navigationItem.leftBarButtonItem = trushButton
        setTrashButtonIsHidden(true)

        PhotoLibraryDataStore.requestAuthorization { [weak self] (success) in
            guard let self = self else { return }
            guard success else {
                self.showAttentionAlert(title: "アクセスできません", message: "写真ライブラリへのアクセスが許可されていません。")
                return
            }

            PhotoLibraryDataStore.requestAssets().forEach {
                self.coreDataStore.insertAssetEntity(with: $0)
            }

            self.coreDataStore.fetchAllAssetEntity(completion: { (result) in
                switch result {
                case .success(let assetEntitys):
                    self.assetEntitys = assetEntitys
                    self.photoListView.reloadData()
                case .failure(let error):
                    self.showAttentionAlert(title: "取得失敗", message: error.localizedDescription)
                }
            })

        }
    }

    private func deselectCell() {
        (0...assetEntitys.count).forEach { [weak self] in
            let indexPath = IndexPath(item: $0, section: 0)
            if let cell = self?.photoListView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell {
                self?.photoListView.deselectItem(at: indexPath, animated: true)
                cell.updateViewStatus(isSelect: false)
                selectedCellDic = [:]
            }
        }
    }

    private func setTrashButtonIsHidden(_ isHidden: Bool) {
        if isHidden {
            navigationItem.leftBarButtonItem?.isEnabled = false
            navigationItem.leftBarButtonItem?.tintColor = .clear
        } else {
            navigationItem.leftBarButtonItem?.isEnabled = true
            navigationItem.leftBarButtonItem?.tintColor = nil
        }
    }

    @objc private func didTapTrashButton() {
        guard !selectedCellDic.isEmpty else { return }

        selectedCellDic.forEach { [weak self] (indexPath, isSelect) in
            guard let self = self else { return }
            let deleteAssetEntity = self.assetEntitys[indexPath.item]
            if let deleteAssetEntityID = deleteAssetEntity.localIdentifier {
                // 保存が完了する前にリフレッシュされた場合はこのDicで削除済みのアイテムを確認する
                self.deleteItemsIdDic[deleteAssetEntityID] = isSelect
            }
            self.coreDataStore.updateAssetEntity(deleteAssetEntity)
        }
        // TODO: - 削除完了までeditボタンを押せなくする

        // FIXME: 現状クラッシュ
        print(photoListView.indexPathsForSelectedItems!)
//        photoListView.performBatchUpdates({
//            let deleteItemIndexs = selectedCellDic.filter { $0.value }.map { $0.key }
//            photoListView.deleteItems(at: deleteItemIndexs)
//        }, completion: nil)
    }

}

extension PhotoListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO: - セクション分けするときはここでfetchControllerをみる
        return assetEntitys.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoListViewCollectionViewCell.identifier, for: indexPath) as? PhotoListViewCollectionViewCell else {
            fatalError("not found PhotoListViewCollectionViewCell")
        }
        cell.setImage(asset: PhotoLibraryDataStore.requestAsset(by: assetEntitys[indexPath.row].localIdentifier))
        return cell
    }
}

extension PhotoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let selectCell = collectionView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell {
            selectCell.updateViewStatus(isSelect: true)
            selectedCellDic[indexPath] = true
        }
    }
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let selectCell = collectionView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell {
            selectCell.updateViewStatus(isSelect: false)
            selectedCellDic[indexPath] = false
        }
    }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return isEditing
    }
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return isEditing
    }
}
