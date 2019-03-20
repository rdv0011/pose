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
    
    func drawMatricesCombined(matricesCount: Int, width: Int, height: Int, colors: [UIColor]) -> UIImage {
        let matStride = width * height
        var finalImage = UIImage()
        
        for idx in stride(from: 0, to: matricesCount, by: 1) {
            let matArray = self.array(idx: idx, stride: matStride)
            let color = colors[idx % colors.count]
            let image = matArray.draw(width: width, height: height).tinted(with: color)
            if idx == 0 {
                finalImage = image
            } else {
                finalImage = image.combined(withBacground: finalImage)
            }
        }
        return finalImage
    }
}
