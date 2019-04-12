//
//  UnsafeMutablePointer+Extension.swift
//
//  Created by Dmitry Rybakov on 2019-03-20.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import UIKit

extension UnsafeMutablePointer where Pointee == Float32 {
    
    /// Returns an array with a specified index and size
    func array(index: Int, count: Int) -> Array<Pointee> {
        return Array(UnsafeBufferPointer(start: advanced(by: index * count), count: count))
    }
}
