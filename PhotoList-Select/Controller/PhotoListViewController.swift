//
//  PhotoListViewController.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

final class PhotoListViewController: UIViewController {

    @IBOutlet weak private var photoListView: UICollectionView!
    @IBOutlet weak private var trashButton: UIBarButtonItem!
    @IBOutlet weak private var redoButton: UIBarButtonItem!

    private let coreDataStore = CoreDataStore()
    private var assetEntitys = [AssetEntity]()
    // 選択されているセルを持つ
    private var selectedItems = [String: IndexPath]()
    private var startPanIndexPath: IndexPath?
    private var lastPanIndexPath: IndexPath?
    // 任意のセルを選択した状態からパンをスタートしたか
    private var isStartSelectedCell = false
    // Panを開始したセルからどれだけのitem数離れているかを保持
    private var currentCountAwayFromStartPanItem = 0

    // MARK: Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if !editing {
            deselectCell()
        }
        trashButton.isEnabled = editing
        redoButton.isEnabled = !editing
    }

    // MARK: Action
    @IBAction func didTapTrashButton(_ sender: UIBarButtonItem) {
        guard !selectedItems.isEmpty else { return }
        showConfirmationActionSheet(actionType: .delete, editDataCount: selectedItems.count, actionHandler: hiddenSelectedItems)
    }

    @IBAction func didTapRedoButton(_ sender: UIBarButtonItem) {
        showConfirmationActionSheet(actionType: .restore, editDataCount: 0, actionHandler: showAllItems)
    }

    // MARK: Setup
    private func setup() {
        setupPhotoListView()
        setupNavigationBarButtonItem()
        setupPanGesture()

        PhotoLibraryDataStore.requestAuthorization { [weak self] (success) in
            guard let self = self else { return }
            guard success else {
                self.showAttentionAlert(title: "アクセスできません", message: "写真ライブラリへのアクセスが許可されていません。")
                return
            }
            // ローカルから取得して永続化
            self.prepareAssetEntitys()
            // 永続化した写真(AssetEntity)をfetch
            self.requestAssetEntitys()
        }
    }

    private func setupPhotoListView() {
        photoListView.dataSource = self
        photoListView.delegate = self
        photoListView.register(PhotoListViewCollectionViewCell.nib(),
                               forCellWithReuseIdentifier: PhotoListViewCollectionViewCell.identifier)
        photoListView.allowsMultipleSelection = true
    }

    private func setupNavigationBarButtonItem() {
        navigationItem.rightBarButtonItem = editButtonItem
    }

    private func setupPanGesture() {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(didPan(toSelectCells:)))
        view.addGestureRecognizer(gesture)
    }

    private func prepareAssetEntitys() {
        PhotoLibraryDataStore.requestAssets().forEach {
            coreDataStore.insertAssetEntity(with: $0)
        }
    }

    // MARK: Private
    private func requestAssetEntitys() {
        self.coreDataStore.fetchIsNotHiddenAssetEntitys(completion: { [weak self] (result) in
            switch result {
            case .success(let assetEntitys):
                self?.assetEntitys = assetEntitys
                self?.photoListView.reloadData()
            case .failure(let error):
                self?.showAttentionAlert(title: "取得失敗", message: error.localizedDescription)
            }
        })
    }

    private func deselectCell() {
        (0..<assetEntitys.count).forEach { [weak self] in
            let indexPath = IndexPath(item: $0, section: 0)
            self?.photoListView.deselectItem(at: indexPath, animated: false)
            self?.selectedItems = [:]
            self?.lastPanIndexPath = nil
        }
    }

    private func hiddenSelectedItems(action: UIAlertAction) {
        // DB側の値を更新
        selectedItems.forEach {
            coreDataStore.fetchAsset(by: $0.key, completion: { [weak self] (result) in
                switch result {
                case .success(let assetEntity):
                    assetEntity.isHidden = true
                    self?.coreDataStore.saveContext(assetEntity.managedObjectContext)
                case .failure(let nserror):
                    print("削除更新失敗")
                    print(nserror.localizedDescription)
                }
            })
        }

        // View側の更新（DB側の更新は待たない）
        let deleteItemLocalIds = selectedItems.map { $0.key }
        assetEntitys = assetEntitys.compactMap {
            if let localId = $0.localIdentifier, !deleteItemLocalIds.contains(localId) {
                return $0
            } else {
                return nil
            }
        }

        // 消す際に選択状態を戻す
        selectedItems.forEach { photoListView.deselectItem(at: $0.value, animated: false) }

        photoListView.performBatchUpdates({
            photoListView.deleteItems(at: selectedItems.map { $0.value })
        }) { [weak self] (_) in
            guard let self = self else { return }
            self.selectedItems = [:]
            self.showFinishLabel(actionType: .delete)
            self.setEditing(false, animated: true)
        }
    }

    private func switchPhotoListIsScrollEnabled(by fingerPosition: CGPoint) {
        let isScrollEnabled =
            (photoListView.bounds.size.height * 0.2 > fingerPosition.y) || (photoListView.bounds.size.height * 0.8 < fingerPosition.y)
        photoListView.isUserInteractionEnabled = isScrollEnabled
        photoListView.isScrollEnabled = isScrollEnabled
    }

    private func showAllItems(action: UIAlertAction) {
        coreDataStore.fetchAllAssetEntity { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let assetEntitys):
                let insertIndexs = assetEntitys.enumerated().compactMap { (offset: Int, element: AssetEntity)  -> IndexPath? in
                    return element.isHidden ? IndexPath(item: offset, section: 0) : nil
                }
                self.assetEntitys = assetEntitys
                DispatchQueue.main.async { [weak self] in
                    self?.photoListView.insertItems(at: insertIndexs)
                    self?.showFinishLabel(actionType: .restore)
                }
            case .failure(let nserror):
                print("元に戻す失敗")
                print(nserror.localizedDescription)
                self.showAttentionAlert(title: "失敗", message: "データの復元に失敗しました")
            }
        }
    }

    private func isAwayFromStartPanItem(at indexPath: IndexPath) -> Bool {
        guard let startPanIndexPath = startPanIndexPath else {
            // 開始時のIndexPathが取れない（ありえない想定）
            return false
        }

        let awayCount = abs(startPanIndexPath.item - indexPath.item)
        let isAwayFromStart = awayCount > currentCountAwayFromStartPanItem
        currentCountAwayFromStartPanItem = awayCount
        return isAwayFromStart
    }

    private func isSelectCell(by indexPath: IndexPath) -> Bool {
        guard let localId = assetEntitys[indexPath.item].localIdentifier else {
            fatalError("localId does not exist, but it does not assume")
        }
        return selectedItems[localId] != nil
    }

    private func selectItems(at indexPaths: [IndexPath]) {
        indexPaths.forEach {
            guard let localId = assetEntitys[$0.item].localIdentifier else {
                print("not found localId")
                return
            }
            selectedItems[localId] = $0
            photoListView.selectItem(at: $0, animated: false, scrollPosition: .centeredHorizontally)
        }
    }

    private func deselectItems(at indexPaths: [IndexPath]) {
        indexPaths.forEach {
            guard let localId = assetEntitys[$0.item].localIdentifier else {
                print("not found localId")
                return
            }
            selectedItems.removeValue(forKey: localId)
            photoListView.deselectItem(at: $0, animated: false)
        }
    }

    private func operationIndexs(between currentIndex: IndexPath, _ previousIndex: IndexPath?) -> [IndexPath] {
        guard currentIndex != previousIndex, let previousIndex = previousIndex else { return [currentIndex] }
        // 今回はsctionで分かれている場合は考慮しない
        let isLargeCurrent = currentIndex.item > previousIndex.item

        if isLargeCurrent {
            // 昇順
            return (previousIndex.item...currentIndex.item).map {
                IndexPath(item: $0, section: 0)
            }
        } else {
            // 降順
            return (currentIndex.item...previousIndex.item).reversed().map {
                IndexPath(item: $0, section: 0)
            }
        }
    }

    private func handlePanGestureForSelectCell(at indexs: [IndexPath]) {
        guard !indexs.isEmpty else { return }
        var oldIndexPath = indexs[0] // 初期値は最初に触ったセル

        indexs.forEach {
            // 対象IndexPathの状態操作（deselectが必要なパターンはisStartSelectedCellの判定でtrueに入る）
            if !isSelectCell(by: $0) {
                selectItems(at: [$0])
            }

            // 操作対象のIndexPathの配列の要素数が1の場合は以降の処理は必要ない（してはいけない）
            guard indexs.count > 1 else { return }

            // 対象IndexPathの一つ前のIndexPathへの状態操作
            let isAwayFromStartCell = isAwayFromStartPanItem(at: $0)

            switch (isStartSelectedCell, isAwayFromStartCell) {
            case (false, true):
                selectItems(at: [oldIndexPath])
            case (false, false):
                deselectItems(at: [oldIndexPath])
            case (true, true):
                deselectItems(at: [oldIndexPath])
            case (true, false):
                selectItems(at: [oldIndexPath])
            }
            // 操作IndexPathを更新
            oldIndexPath = $0
        }
    }

    @objc private func didPan(toSelectCells panGesture: UIPanGestureRecognizer) {
        guard isEditing else { return }

        let location = panGesture.location(in: photoListView)

        guard let currentIndexPath = photoListView.indexPathForItem(at: location) else {
            print("ジェスチャー開始時のタッチ位置状態が取れません")
            return
        }

        switch panGesture.state {
        case .began:
            photoListView.isUserInteractionEnabled = false
            photoListView.isScrollEnabled = false
            isStartSelectedCell = isSelectCell(by: currentIndexPath)
            startPanIndexPath = currentIndexPath
        case .changed:
            // Pan位置によってスクロールの有無の切り替える
            switchPhotoListIsScrollEnabled(by: panGesture.location(in: view))

            // 一度処理したセルならリターン
            guard lastPanIndexPath != currentIndexPath else { return }

            if isStartSelectedCell {
                // 選択済みのセルからPanをスタートした場合は、どのセルを触っても非選択にするようにする
                deselectItems(at: operationIndexs(between: currentIndexPath, lastPanIndexPath))
            } else {
                handlePanGestureForSelectCell(at: operationIndexs(between: currentIndexPath, lastPanIndexPath))
            }
            // 次の選択移動のために値を更新
            lastPanIndexPath = currentIndexPath
        case .ended:
            photoListView.isScrollEnabled = true
            photoListView.isUserInteractionEnabled = true
            lastPanIndexPath = nil
            startPanIndexPath = nil
        default: break
        }
    }

}

extension PhotoListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assetEntitys.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoListViewCollectionViewCell.identifier, for: indexPath) as? PhotoListViewCollectionViewCell else {
            fatalError("not found PhotoListViewCollectionViewCell")
        }
        cell.setImage(asset: PhotoLibraryDataStore.requestAsset(by: assetEntitys[indexPath.item].localIdentifier))
        return cell
    }
}

extension PhotoListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditing {
            if let localId = assetEntitys[indexPath.item].localIdentifier {
                selectedItems[localId] = indexPath
            }
        } else {
            collectionView.deselectItem(at: indexPath, animated: false)
            guard let detailVC = DetailPhotoViewController.make(asset: PhotoLibraryDataStore.requestAsset(by: assetEntitys[indexPath.item].localIdentifier)) else { return }
            navigationController?.pushViewController(detailVC, animated: true)
            collectionView.deselectItem(at: indexPath, animated: false)
        }

    }
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard isEditing else { return }
        if let localId = assetEntitys[indexPath.item].localIdentifier {
            selectedItems.removeValue(forKey: localId)
        }
    }
}
