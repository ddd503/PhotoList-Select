//
//  Date+String.swift
//  PhotoList-Select
//
//  Created by kawaharadai on 2019/04/26.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import Foundation

extension Date {
    var string: String {
        let format = DateFormatter()
        // 0000年0月00日
        format.dateFormat = DateFormatter.dateFormat(fromTemplate: "ydMMM",
                                                     options: 0, locale: Locale(identifier: "ja_JP"))
        return format.string(from: self)
    }
}
