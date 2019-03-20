//
//  Array+Extension.swift
//
//  Created by Dmitry Rybakov on 2019-03-20.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import UIKit

extension Array where Element == Float {
    func draw(width: Int, height: Int) -> UIImage {
        guard let max = self.max(), let min = self.min() else {
            return UIImage()
        }
        let k = Float(255 / ( max - min ))
        let convertedArray = map { UInt8(k * ($0 - min)) }
        guard let image = CGImage.fromByteArrayGray(convertedArray,
                                                    width: width,
                                                    height: height) else {
                                                        
                                                        return UIImage()
        }
        return UIImage(cgImage: image)
    }
}

extension Array where Element == HeatMapJointCandidate {
    func draw(width: Int, height: Int, alpha: CGFloat = 1.0,
              radius: CGFloat = 3, lineWidth: CGFloat = 1, on image: UIImage) -> UIImage {
        let kx = CGFloat(image.size.width) / CGFloat(width)
        let ky = CGFloat(image.size.height) / CGFloat(height)
        let (offsetX, offsetY) = (image.size.width / CGFloat(width) / 2,
                                  image.size.height / CGFloat(height) / 2)
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            image.draw(at: .zero)
            context.cgContext.setLineWidth(lineWidth)
            for c in self {
                context.cgContext.setStrokeColor(c.color.cgColor)
                context.cgContext.setAlpha(alpha)
                context.cgContext.beginPath()
                let x = CGFloat(c.col) * kx + offsetX - radius
                let y = CGFloat(c.row) * ky + offsetY - radius
                context.cgContext.addEllipse(in: CGRect(origin: CGPoint(x: x, y: y),
                                                        size: CGSize(width: 2 * radius,
                                                                     height: 2 * radius)))
                context.cgContext.strokePath()
            }
        }
    }
}

extension Array where Element == JointConnectionWithScore {
    
    func draw(width: Int, height: Int, lineWidth: CGFloat = 1,
              drawJoint: Bool = false, useAlpha: Bool = true,
              on image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let kx = CGFloat(image.size.width) / CGFloat(width)
        let ky = CGFloat(image.size.height) / CGFloat(height)
        return renderer.image { context in
            image.draw(at: .zero)
            let score = self.map({ $0.score })
            var factor = Float(1)
            var min = Float(0)
            if let scoreMin = score.min(), let max = score.max() {
                factor = Float(1.0) / abs(max - min)
                min = scoreMin
            }
            let radius = lineWidth
            let (offsetX, offsetY) = (image.size.width / CGFloat(width) / 2,
                                      image.size.height / CGFloat(height) / 2)
            self.forEach { c in
                context.cgContext.setStrokeColor(c.connection.color.cgColor)
                if useAlpha {
                    context.cgContext.setAlpha(CGFloat((c.score - min) * factor))
                }
                context.cgContext.setLineWidth(lineWidth)
                context.cgContext.beginPath()
                context.cgContext.move(to: CGPoint(x: CGFloat(c.joint1.x) * kx + offsetX,
                                                   y: CGFloat(c.joint1.y) * ky + offsetY))
                context.cgContext.addLine(to: CGPoint(x: CGFloat(c.joint2.x) * kx + offsetX,
                                                      y: CGFloat(c.joint2.y) * ky + offsetY))
                if drawJoint {
                    let coords = [(c.joint1.x, c.joint1.y, c.connection.joints.0.color.cgColor),
                                  (c.joint2.x, c.joint2.y, c.connection.joints.1.color.cgColor)]
                    coords.forEach { i in
                        let x = CGFloat(i.0) * kx + offsetX - radius
                        let y = CGFloat(i.1) * ky + offsetY - radius
                        context.cgContext.setStrokeColor(i.2)
                        context.cgContext.addEllipse(in: CGRect(origin: CGPoint(x: x, y: y),
                                                                size: CGSize(width: 2 * radius,
                                                                             height: 2 * radius)))
                    }
                }
                context.cgContext.strokePath()
            }
        }
    }
}
