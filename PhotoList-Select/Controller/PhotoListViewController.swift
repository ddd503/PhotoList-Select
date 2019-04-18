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
    private var assetEntitysDic = [String: AssetEntity]()
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

            self.coreDataStore.fetchAllAssetEntity(completion: { [weak self] (result) in
                switch result {
                case .success(let assetEntitys):
                    assetEntitys.forEach {
                        guard let localId = $0.localIdentifier else { return }
                        self?.assetEntitysDic[localId] = $0
                    }
                    self?.photoListView.reloadData()
                case .failure(let error):
                    self?.showAttentionAlert(title: "取得失敗", message: error.localizedDescription)
                }
            })

        }
    }

    private func deselectCell() {
        (0...assetEntitysDic.count).forEach { [weak self] in
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
        // Valueが0ならreturn
//        guard !(selectedItems.compactMap { $0.value }.isEmpty) else { return }
//        let deleteItemIds = selectedItems.compactMap { $0.key }
//        let copyAssetEntitys = assetEntitysDic
//        assetEntitysDic.forEach {
//            guard let localId = $0.localIdentifier else { return }
//            if let localId = $0.localIdentifier, deleteItemIds.contains(localId) {
//
//            }
//        }
//        selectedCellDic.forEach { [weak self] (indexPath, isSelect) in
//            guard let self = self else { return }
//            let deleteAssetEntity = self.assetEntitys[indexPath.item]
//            if let deleteAssetEntityID = deleteAssetEntity.localIdentifier {
//                // 保存が完了する前にリフレッシュされた場合はこのDicで削除済みのアイテムを確認する
//                self.deleteItemsIdDic[deleteAssetEntityID] = isSelect
//            }
//            self.coreDataStore.updateAssetEntity(deleteAssetEntity)
//        }
//        // TODO: - 削除完了までeditボタンを押せなくする
//
//        photoListView.performBatchUpdates({
//            let deleteItemIndexs = selectedCellDic.filter { $0.value }.map { $0.key }
//            var afterAssetEntitys = assetEntitys
//            deleteItemIndexs.forEach {
//                // TODO - CoreData側のデータもisDeleteを更新しておき、fetchの際に弾く必要がある
//                // 実際に観にいく方を消しておく必要がある（deleteItems消すはずのindexPathのitemがdataSourceに残っているとクラッシュするため）
//                deleteAssetEntitys.append(assetEntitys[$0.row])
//            }
//            assetEntitys =
//            photoListView.deleteItems(at: deleteItemIndexs)
//        }, completion: nil)
    }

}

extension PhotoListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // TODO: - セクション分けするときはここでfetchControllerをみる
        return assetEntitysDic.compactMap { $0.value }.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoListViewCollectionViewCell.identifier, for: indexPath) as? PhotoListViewCollectionViewCell else {
            fatalError("not found PhotoListViewCollectionViewCell")
        }

        cell.setImage(asset: PhotoLibraryDataStore.requestAsset(by: assetEntitysDic[indexPath.row].localIdentifier))
        return cell
    }
}

extension PhotoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let selectCell = collectionView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell {
            selectCell.updateViewStatus(isSelect: true)
            if let localId = assetEntitys[indexPath.item].localIdentifier {
                selectedItems[localId] = indexPath
            }
//            selectedCellDic[indexPath] = true
        }
    }
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let selectCell = collectionView.cellForItem(at: indexPath) as? PhotoListViewCollectionViewCell {
            selectCell.updateViewStatus(isSelect: false)
            if let localId = assetEntitys[indexPath.item].localIdentifier {
                selectedItems.removeValue(forKey: localId)
            }
//            selectedCellDic[indexPath] = false
        }
    }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return isEditing
    }
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return isEditing
    }
}
