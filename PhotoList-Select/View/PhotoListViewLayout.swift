//
//  PhotoListViewCollectionViewLayout.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/13.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

protocol PhotoListViewLayoutDelegate: class {
    func collectionView(_ collectionView: UICollectionView, footerViewHeightAt indexPath: IndexPath) -> CGFloat
}

class PhotoListViewLayout: UICollectionViewLayout {
    // MARK: - Propatis
    weak var delegate: PhotoListViewLayoutDelegate?
    private var cachedAttributes = [UICollectionViewLayoutAttributes]()
    // レイアウトの総Height
    private var contentHeight: CGFloat = 0
    // レイアウトの総Width
    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        let insets = collectionView.contentInset
        return collectionView.bounds.width - (insets.left + insets.right)
    }
    // 直近のy軸のoffsetを保持
    private var lastContentOffsetY = CGFloat.zero
    // falseならレイアウト更新後ScrollToTopとなる
    var isKeepCurrentOffset = false

    private var footerViewHeight = CGFloat.zero

    // MARK: - Life Cycle
    override func prepare() {
        if let collectionView = collectionView {
            lastContentOffsetY = collectionView.contentOffset.y
        }
        resetAttributes()
        setupAttributes()
        setupOffset()
    }

    // prepareが終わった後に呼ばれる
    override var collectionViewContentSize: CGSize {
        let newContentSize = CGSize(width: contentWidth, height: contentHeight)
        // セルの増減があった時にcurrentのoffsetを保つ場合は改めてoffsetをセットし直す（このタイミングでは新しいレイアウトが決まっている）
        if let collectionView = collectionView {
            setContentOffsetIfNeeded(shouldSetContentOffset: isKeepCurrentOffset &&
                (newContentSize.height > (collectionView.frame.size.height - footerViewHeight)),
                                     collectionView: collectionView)
        }
        return newContentSize
    }

    // 生成したUICollectionViewLayoutAttributesを返す（要素数→セルの数）
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cachedAttributes.filter({ (layoutAttributes) -> Bool in
            rect.intersects(layoutAttributes.frame)
        })
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cachedAttributes[indexPath.item]
    }

    // MARK: - Private
    private func setupAttributes() {
        guard cachedAttributes.isEmpty, let collectionView = collectionView else { return }
        let cellLength = contentWidth / CGFloat(numberOfColumns())
        let cellXOffsets = (0 ..< numberOfColumns()).map {
            CGFloat($0) * cellLength
        }
        gridAttributes(collectionView: collectionView, cellLength: cellLength, cellXOffsets: cellXOffsets)
    }

    private func setupOffset() {
        // ナビバー分を調整
        collectionView?.contentOffset = CGPoint(x: 0, y: -(collectionView?.adjustedContentInset.top ?? 0))
    }

    private func resetAttributes() {
        cachedAttributes = []
        contentHeight = 0
        collectionView?.contentOffset.y = 0
    }

    // 列の数
    private func numberOfColumns() -> Int {
        return 4
    }

    // セル周囲のスペース
    private func cellPadding() -> CGFloat {
        return 1
    }

    // 生成したセルの配置情報を配列に追加
    private func addAttributes(cellFrame: CGRect, indexPath: IndexPath) {
        // セルの内側にスペースを入れる
        let itemFrame = cellFrame.insetBy(dx: cellPadding(), dy: cellPadding())
        // Attributesを追加
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = itemFrame
        cachedAttributes.append(attributes)
        // ContentSizeを更新
        contentHeight = max(contentHeight, cellFrame.maxY)
    }

    // グリッド形式のレイアウト生成
    private func gridAttributes(collectionView: UICollectionView, cellLength: CGFloat, cellXOffsets: [CGFloat]) {
        var cellYOffsets = [CGFloat](repeating: 0, count: numberOfColumns())
        var currentColumnNumber = 0
        (0 ..< collectionView.numberOfItems(inSection: 0)).forEach {
            let indexPath = IndexPath(item: $0, section: 0)
            let cellFrame = CGRect(x: cellXOffsets[currentColumnNumber], y: cellYOffsets[currentColumnNumber], width: cellLength, height: cellLength)
            cellYOffsets[currentColumnNumber] = cellYOffsets[currentColumnNumber] + cellLength
            currentColumnNumber = currentColumnNumber < (numberOfColumns() - 1) ? currentColumnNumber + 1 : 0
            addAttributes(cellFrame: cellFrame, indexPath: indexPath)
        }

        let indexPath = IndexPath(item: 0, section: 0)
        let footerAttribute = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                                               with: indexPath)
        footerViewHeight = delegate?.collectionView(collectionView, footerViewHeightAt: indexPath) ?? .zero
        footerAttribute.frame = CGRect(x: 0, y: cellYOffsets[0], width: collectionView.bounds.size.width, height: footerViewHeight)
        cachedAttributes.append(footerAttribute)
        contentHeight = contentHeight + footerViewHeight
    }

    private func setContentOffsetIfNeeded(shouldSetContentOffset: Bool, collectionView: UICollectionView) {
        if shouldSetContentOffset {
            let newOffset = CGPoint(x: collectionView.frame.origin.x, y: lastContentOffsetY)
            collectionView.setContentOffset(newOffset, animated: false)
            isKeepCurrentOffset = false
        }
    }
}
