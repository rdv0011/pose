//
//  Array+Extension.swift
//
//  Created by Dmitry Rybakov on 2019-03-20.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import UIKit

extension Array where Element == Float {
    
    /// Returns converted values
    /// The range of output array varies from 0 to highestValue
    /// If the source array is empty the output is nil
    /// If there is one element in the source array only the output will be the highestValue
    /// If the input if onle element that is equal to zero the output is zero also
    private func converted(from values: [Float], highestValue: Float) -> [Float]? {
        var factor = Double(1)
        var min = Float(0)
        guard let scoreMin = values.min(), let scoreMax = values.max() else {
            return nil
        }
        if scoreMax - scoreMin > 0.0001  {
            factor = Double(highestValue) / Double(scoreMax - scoreMin)
            min = scoreMin
        } else if scoreMax != 0 {
            factor = Double(highestValue) / Double(scoreMax)
        }
        return values.map { Float(Double(($0 - min)) * factor) }
    }
    
    /// Generates an image out of the array
    /// The width and height indicate the size of the output image
    /// The values in the array are scaled to the range [0, 255]
    /// The size of the array should be greater or equal to width * height
    func draw(width: Int, height: Int) -> UIImage {
        guard let convertedValues = converted(from : self, highestValue: 255) else {
            return UIImage()
        }
        guard let image = CGImage.fromByteArrayGray(convertedValues.map({ UInt8($0) }),
                                                    width: width,
                                                    height: height) else {
                                                        
                                                        return UIImage()
        }
        return UIImage(cgImage: image)
    }
    
    /// Generates an image out of the array
    /// The width and height indicate the size of the output image
    /// The size of the array should be greater or equal to matricesCount * width * height
    /// Each sequence with a size width * height is treated as a separate image and is tinted with a different color
    /// All images are combined into one
    func drawMatricesCombined(matricesCount: Int, width: Int, height: Int, colors: [UIColor]) -> UIImage {
        let matSize = width * height
        let size = matricesCount * matSize
        guard self.count >= size else {
            return UIImage()
        }
        var finalImage = UIImage()
        
        for idx in stride(from: 0, to: size, by: matSize) {
            let endIndex = Swift.min(idx + matSize, self.count - 1)
            let matArray = Array(self[idx..<endIndex])
            let color = colors[(idx / matSize) % colors.count]
            let image = matArray.draw(width: width, height: height).tinted(with: color)
            if idx == 0 {
                finalImage = image
            } else {
                finalImage = image.combined(withBacground: finalImage)
            }
        }
        return finalImage
    }
    
    /// Returns a sub array. Given that the entire array is divided into blocks of equal size
    /// blockIndex - an index of the block
    /// blockSize - equals to block size
    func slice(blockIndex: Int, blockSize: Int) -> SubSequence {
        let idx = blockIndex * blockSize
        let endIdx = idx + blockSize
        return self[idx..<endIdx]
    }
}

extension Array where Element == HeatMapJointCandidate {
    /// Draws heat map candidates on a specified image
    /// If alpha specified then it will be used or an alpha is calculated dynamically based on a heat map candidate's confidence
    /// The lineWidth varies based on the candidate's confidence
    func draw(alpha: CGFloat? = nil, radius: CGFloat = 3,
              lineWidth: CGFloat = 1, offset: CGFloat = 4, on image: UIImage) -> UIImage {
        let confidences: [Float] = self.map({ $0.confidence })
        guard let convertedValues = confidences.converted(from : confidences, highestValue: 0.7) else {
            return UIImage()
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            image.draw(at: .zero)
            self.enumerated().forEach { idx, c in
                context.cgContext.setLineWidth(lineWidth * CGFloat(convertedValues[idx] + 0.3))
                context.cgContext.setStrokeColor(c.color.cgColor)
                context.cgContext.setAlpha(alpha ?? CGFloat(convertedValues[idx] + 0.3))
                context.cgContext.beginPath()
                let x = CGFloat(c.col) - radius + offset
                let y = CGFloat(c.row) - radius + offset
                context.cgContext.addEllipse(in: CGRect(origin: CGPoint(x: x, y: y),
                                                        size: CGSize(width: 2 * radius,
                                                                     height: 2 * radius)))
                context.cgContext.strokePath()
            }
        }
    }
}

extension Array where Element: JointConnectionScoreProtocol {
    
    /// Draws connections on a specified image
    /// The alpha is constant if specified or is dynamically calculated based on a confidence otherwise
    /// Draws joints also if drawJoint is true
    func draw(lineWidth: CGFloat = 5,
             drawJoint: Bool = false, alpha: CGFloat? = nil, offset: CGFloat = 4,
             on image: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            image.draw(at: .zero)
            self.draw(lineWidth: lineWidth,
                         drawJoint: drawJoint,
                         alpha: alpha, offset: offset,
                         on: context.cgContext)
        }
    }
    /// Draws connections with a specified cotext
    /// The alpha is constant if specified or is dynamically calculated based on a confidence otherwise
    /// Draws joints also if drawJoint is true
    func draw(lineWidth: CGFloat = 5,
              drawJoint: Bool = false, alpha: CGFloat? = nil, offset: CGFloat = 4,
              on context: CGContext) {
        
        let confidences: [Float] = self.map({ $0.score })
        guard let convertedValues = confidences.converted(from : confidences, highestValue: 0.7) else {
            return
        }
        
        let radius = lineWidth
        self.enumerated().forEach { idx, c in
            context.setStrokeColor(c.connection.color.cgColor)
            context.setAlpha(alpha ?? CGFloat(convertedValues[idx] + 0.3))
            context.setLineWidth(lineWidth)
            context.beginPath()
            context.move(to: CGPoint(x: CGFloat(c.joint1.x) + offset,
                                     y: CGFloat(c.joint1.y) + offset))
            context.addLine(to: CGPoint(x: CGFloat(c.joint2.x) + offset,
                                        y: CGFloat(c.joint2.y) + offset))
            if drawJoint {
                let coords = [(c.joint1.x, c.joint1.y, c.connection.joints.0.color.cgColor),
                              (c.joint2.x, c.joint2.y, c.connection.joints.1.color.cgColor)]
                coords.forEach { i in
                    let x = CGFloat(i.0) - radius + offset
                    let y = CGFloat(i.1) - radius + offset
                    context.setStrokeColor(i.2)
                    context.addEllipse(in: CGRect(origin: CGPoint(x: x, y: y),
                                                            size: CGSize(width: 2 * radius,
                                                                         height: 2 * radius)))
                }
            }
            context.strokePath()
        }
    }
}
