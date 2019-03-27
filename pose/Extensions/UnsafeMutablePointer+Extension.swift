//
//  UnsafeMutablePointer+Extension.swift
//
//  Created by Dmitry Rybakov on 2019-03-20.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import UIKit

extension UnsafeMutablePointer where Pointee == Float32 {
    
    func array(idx: Int, stride: Int) -> Array<Pointee> {
        return Array(UnsafeBufferPointer(start: advanced(by: idx * stride), count: stride))
    }
}
