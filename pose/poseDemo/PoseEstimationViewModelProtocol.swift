//
//  PoseEstimationViewModelProtocol.swift
//  poseDemo
//
//  Created by Dmitry Rybakov on 2020-03-03.
//  Copyright © 2020 Dmitry Rybakov. All rights reserved.
//

import Foundation
import UIKit

protocol PoseEstimationViewModelProtocol {
    var joitConnectionCombinedImagesCount: Int { get }

    var totalImageCount: Int { get }

    var keepDebugInfo: Bool { get set }

    var coreMLProcessingTime: String { get }

    var postProcessingTime: String { get }
    
    var statusText: String { get }

    func estimate(on image: UIImage, completion: @escaping ((Result<Void, Error>) -> ()))

    func humanPosesImage(overImage: UIImage, completion: @escaping ((UIImage)->()))

    func heatMapLayersCombined(completion: @escaping ((UIImage)->()))
    
    func heatMapCandidatesImage(completion: @escaping ((UIImage)->()))
    
    func filteredHeatMapCandidatesImage(completion: @escaping ((UIImage)->()))
    
    func pafLayersCombinedImage(completion: @escaping ((UIImage)->()))
    
    func jointsWithConnectionsByLayers(completion: @escaping (([UIImage])->()))
    
    func numberOfItemsInSection(_ section: Int) -> Int
    
    func numberOfSections() -> Int
    
    func imageFor(for indexPath: IndexPath, completion: @escaping ((UIImage)->()))
    
    func description(for indexPath: IndexPath) -> String
}
