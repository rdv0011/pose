//
//  UIImage+Extension.swift
//
//  Created by Dmitry Rybakov on 2019-03-20.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import UIKit

extension UIImage {
    func tinted(with color: UIColor) -> UIImage {
        
        // The higher intensity a pixel has more tinted with a color it will be
        let ciImage = self.ciImage ?? CIImage(image: self)
        guard let filter = CIFilter(name: "CIMultiplyCompositing") else {
            return self
        }
        
        guard let colorFilter = CIFilter(name: "CIConstantColorGenerator") else {
            return self
        }
        
        let ciColor = CIColor(color: color)
        colorFilter.setValue(ciColor, forKey: kCIInputColorKey)
        let colorImage = colorFilter.outputImage
        
        filter.setValue(colorImage, forKey: kCIInputImageKey)
        filter.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
        
        guard let outputCIImage = filter.outputImage else {
            return self
        }
        return UIImage(ciImage: outputCIImage, scale: self.scale, orientation: self.imageOrientation)
    }
    
    func combined(withBacground backgroundImage: UIImage) -> UIImage {
        guard let composingFilter = CIFilter(name: "CIAdditionCompositing"),
            let ciImage = self.ciImage ?? CIImage(image: self),
            let ciImageBackground = backgroundImage.ciImage ?? CIImage(image: backgroundImage) else {
                
                return self
        }
        composingFilter.setDefaults()
        composingFilter.setValuesForKeys(["inputImage": ciImage,
                                          "inputBackgroundImage": ciImageBackground])
        guard let outputCIImage = composingFilter.outputImage else {
            return self
        }
        return UIImage(ciImage: outputCIImage, scale: self.scale, orientation: self.imageOrientation)
    }
    
    var grayed: UIImage {
        guard let grayingfilter = CIFilter(name: "CIPhotoEffectNoir") else {
            return self
        }
        
        let ciImage = self.ciImage ?? CIImage(image: self)
        grayingfilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputCIImage = grayingfilter.outputImage else {
            return self
        }
        return UIImage(ciImage: outputCIImage, scale: self.scale, orientation: self.imageOrientation)
    }
    
    static func image(with color: UIColor, size: CGSize) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
