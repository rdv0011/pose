//
//  Pose.swift
//
//  Created by Dmitry Rybakov on 2019-03-20.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import UIKit
import CoreML
import Vision
import CoreMLHelpers
import SwiftyBeaver

open class PoseEstimation {

    private let model: MLModel
    
    // Model configuration
    private let modelConfig: PoseModelConfiguration
    
    private var coremlProcessingStart = Date()
    private var coremlProcessingFinish = Date()
    private let log = SwiftyBeaver.self

    public var keepDebugInfo: Bool = false
    
    private(set) var networkOutput: Array<Float> = []
    private(set) var heatMapCandidates: [HeatMapJointCandidate] = []
    private(set) var filteredHeatMapCandidates: [HeatMapJointCandidate] = []
    private(set) var connectionCandidates: [JointConnectionWithScore] = []
    private(set) var humanConnections: [Int: [JointConnectionWithScore]] = [:]
    
    public init(model: MLModel, modelConfig: PoseModelConfiguration) {
        self.model = model
        self.modelConfig = modelConfig
    }
    
    private func stride(x1: Int, y1: Int, x2: Int, y2: Int,
                processBlock: ((Int, Int, Int, Int) -> Void)) {
        var (dx, dy) = (Float(abs(x2 - x1) + 1), Float(abs(y2 - y1) + 1))
        var stepCount = dy
        if (dx >= dy) {
            stepCount = dx
        }
        dx /= stepCount
        dy /= stepCount
        if x2 < x1 {
            dx = -dx
        }
        if y2 < y1 {
            dy = -dy
        }
        var (x, y) = (Float(x1), Float(y1))
        let count = Int(stepCount.rounded())
        (0..<count).forEach { idx in
            processBlock(Int(x.rounded(.toNearestOrAwayFromZero)),
                         Int(y.rounded(.toNearestOrAwayFromZero)), idx, count)
            x += dx
            y += dy
        }
    }
    
    private func score(x1: Int, y1: Int, x2: Int, y2: Int,
               pafMatX: Array<Float32>, pafMatY: Array<Float32>,
               yStride: Int) -> (Float32, Int) {
        
        var pafXs = Array<Float32>()
        var pafYs = Array<Float32>()
        
        stride(x1: x1, y1: y1, x2: x2, y2: y2) { x, y, idx, count in
            // These offset values are used to cover larger area in PAF's to collect as many score as possible
            var dx = [-1, 0, 1]
            var dy = [0, 0, 0]
            if abs(x2 - x1) > abs(y2 - y1) {
                // If scores are collected horizontally then use Ys offsets instead of Xs
                //  When moving horizontally
                //  y - 1   y - 1      y - 1
                //  x1, y   x2, y .... xn, y
                //  y + 1   y + 1      y + 1
                //  When moving vertically
                //  x - 1   x, y1  x + 1
                //  x - 1   x, y2  x + 1
                //          ....
                //          ....
                //  x - 1   x, yn  x + 1
                swap(&dx, &dy)
            }
            var (scoreX, scoreY) = (Float(0), Float(0))
            for (dx, dy) in zip(dx, dy) {
                var offset = (y + dy) * yStride + x + dx
                // Check if it is out of array's bounds
                offset = min(max(0, offset), pafMatX.count - 1)
                // Accumulate PAFs values
                scoreX += pafMatX[offset]
                scoreY += pafMatY[offset]
            }
            pafXs.append(scoreX)
            pafYs.append(scoreY)
        }
        pafXs = pafXs.map({ abs($0) })
        pafYs = pafYs.map({ abs($0) })
        // Summ all the scores
        let localScores = zip(pafXs, pafYs).map(+)
        // The parts of the scores that crosses PAFs that belong to other connections should be penalized
        // In that way the scores that belongs to correct connection will have more chances to win later
        let localScoreMax = localScores.max() ?? Float(0.0)
        let scorePenalty = -localScoreMax
        let filteredLocalScores = localScores.map { localScoreMax / $0 > modelConfig.scoreThreasholdFactor ? scorePenalty: $0 }
        
        log.debug("scores: [\(localScores)]\nfiltered_scores: [\(filteredLocalScores)]")
        
        return (filteredLocalScores.reduce(0, +), filteredLocalScores.count )
    }
    
    public func estimate(on image: UIImage, completion: @escaping (([Int: [JointConnectionWithScore]]) -> ())) {
        
        var uiImage = image
        if image.size != modelConfig.inputSize {
            uiImage = image.resizedCentered(toSize: modelConfig.inputSize)
        }
        
        guard let ciImage = CIImage(image: uiImage) else {
            assertionFailure("Failed to create ciImage")
            completion([:])
            return
        }
        
        do {
            let coremlRequest = try mlRequest(model: self.model, completion: completion)
            // Set an image scaling mode for the Vision framework
            coremlRequest.imageCropAndScaleOption = .centerCrop
            // Even though the CoreML model has fixed input image size that is not equal to the real input image the Vision framework will scale it accordingly
            let handler = VNImageRequestHandler(ciImage: ciImage)
            DispatchQueue.global(qos: .userInteractive).async {
                do {
                    self.coremlProcessingStart = Date()
                    try handler.perform([coremlRequest])
                } catch {
                    self.log.error(error)
                }
            }
        }
        catch {
            log.error(error)
        }
    }
}

extension PoseEstimation {
    
    private func mlRequest(model: MLModel,
                           completion: @escaping (([Int: [JointConnectionWithScore]]) -> ())) throws -> VNCoreMLRequest {
        let model = try VNCoreMLModel(for: model)
        let coremlRequest = VNCoreMLRequest(model: model) { request, error in
            
            self.coremlProcessingFinish = Date()
            
            guard let observations = request.results as? [VNCoreMLFeatureValueObservation] else {
                assertionFailure("Unknown results for CoreML request: \(request)")
                return
            }
            let multiArray = observations.first!.featureValue.multiArrayValue
            let layersCount = self.modelConfig.layersCount
            let modelOutputWidth = self.modelConfig.outputWidh
            let modelOutputHeight = self.modelConfig.outputHeight
            let backgroundLayerIndex = self.modelConfig.backgroundLayerIndex
            let pafLayerStartIndex = self.modelConfig.pafLayerStartIndex
            
            withExtendedLifetime(multiArray) {
                
                if let multiArray = try? multiArray?.reshaped(to: [layersCount,
                                                                   modelOutputWidth,
                                                                   modelOutputHeight]),
                    let reshapedArray = multiArray {
                    
                    let nnOutput = UnsafeMutablePointer<Float32>(OpaquePointer(reshapedArray.dataPointer))
                    let layerStride = reshapedArray.strides[0].intValue
                    let heatMatCount = backgroundLayerIndex
                    let heatMatPtr = nnOutput
                    
                    if self.keepDebugInfo {
                        // Convert a network output to an array for debugging purposes
                        self.networkOutput = nnOutput.array(index: 0, count: layersCount * layerStride)
                    }
                    // Filter the heatmapp network output by applying a threshold
                    let heatMapArray = heatMatPtr.array(index: 0, count: heatMatCount * layerStride)
                    let avg = heatMapArray.reduce(0, +) / Float32(heatMapArray.count)
                    let NMS_Threshold: Float32 = 0.1
                    var _NMS_Threshold = max(avg * 4.0, NMS_Threshold)
                    _NMS_Threshold = min(_NMS_Threshold, 0.3)
                    self.heatMapCandidates = []
                    for layerIndex in 0..<heatMatCount {
                        let layerPtr = heatMatPtr.advanced(by: layerIndex * layerStride)
                        for idx in 0..<layerStride {
                            if layerPtr[idx] > _NMS_Threshold {
                                let col = idx % modelOutputWidth
                                let row = idx / modelOutputWidth
                                self.heatMapCandidates.append(HeatMapJointCandidate(col: col,
                                                                                    row: row,
                                                                                    layerIndex: layerIndex,
                                                                                    confidence: layerPtr[idx]))
                            }
                        }
                    }
                    // Continue filtering using a non maximum suppression approach
                    self.filteredHeatMapCandidates = []
                    for layerIndex in (0..<heatMatCount) {
                        let candidates = self.heatMapCandidates.filter { $0.layerIndex == layerIndex }
                        // Non maximum suppression to get as minimum candidates as possible
                        let boxes = candidates.map { c -> BoundingBox in
                            let windowOrigin = CGPoint(x: max(0, c.col - 2), y: max(0, c.row - 2))
                            let windowSize = CGSize(width: 5, height: 5)
                            return BoundingBox(classIndex: 0,
                                               score: Float(c.confidence),
                                               rect: CGRect(origin: windowOrigin, size: windowSize))
                        }
                        let boxIndices = nonMaxSuppression(boundingBoxes: boxes, iouThreshold: 0.3, maxBoxes: boxes.count)
                        self.filteredHeatMapCandidates += boxIndices.map { candidates[$0] }
                    }
                    
                    let pose = PoseModelConfigurationMPI15()
                    // Map layerIndex to joint type
                    let candidatesByJoints = Dictionary(grouping: self.filteredHeatMapCandidates, by: { pose.joints[$0.layerIndex] })
                    // Get joint connections with scores based on PAF matrices
                    var allConnectionCandidates: [JointConnectionWithScore] = []
                    var connections: [JointConnectionWithScore] = []
                    pose.jointConnections.forEach { connection in

                        let (indexX, indexY) = connection.pafIndices
                        let pafMatX = nnOutput.array(index: pafLayerStartIndex + indexX,
                                                     count: layerStride)
                        let pafMatY = nnOutput.array(index: pafLayerStartIndex + indexY,
                                                     count: layerStride)
                        
                        let (joint1, joint2) = (connection.joints.0, connection.joints.1)
                        
                        if let candidate1 = candidatesByJoints[joint1],
                            let candidate2 = candidatesByJoints[joint2] {
                            
                            self.connectionCandidates = []
                            
                            // Enumerate through non filtered joint connections
                            candidate1.enumerated().forEach { offset1, first in
                                candidate2.enumerated().forEach { offset2, second in
                                    
                                    let (x1, y1) = (first.col, first.row)
                                    let (x2, y2) = (second.col, second.row)
                                    
                                    let (s, c) = self.score(x1: x1, y1: y1, x2: x2, y2: y2,
                                                            pafMatX: pafMatX, pafMatY: pafMatY,
                                                            yStride: modelOutputWidth)
                                    if s > 0 {
                                        let jointPoint1 = JointPoint(x: x1, y: y1)
                                        let jointPoint2 = JointPoint(x: x2, y: y2)
                                        let connWithCoords = JointConnectionWithScore(connection: connection,
                                                                                      score: s,
                                                                                      count: c,
                                                                                      offsetJoint1: offset1,
                                                                                      offsetJoint2: offset2,
                                                                                      joint1: jointPoint1,
                                                                                      joint2: jointPoint2)
                                        self.connectionCandidates.append(connWithCoords)
                                    }
                                }
                            }
                            allConnectionCandidates += self.connectionCandidates
                            
                            var (usedIdx1, usedIdx2) = (Set<Int>(), Set<Int>())
                            self.connectionCandidates.sorted(by: { $0.score > $1.score }).forEach { c in
                                if usedIdx1.contains(c.offsetJoint1) || usedIdx2.contains(c.offsetJoint2) {
                                    return
                                }
                                connections.append(c)
                                usedIdx1.insert(c.offsetJoint1)
                                usedIdx2.insert(c.offsetJoint2)
                            }
                        }
                    }
                    // Group connections by human.
                    var humanJoints: [Set<JointPoint>] = []
                    self.humanConnections = [:]
                    connections.enumerated().forEach { connIdx, c in
                        var added = false
                        (0..<humanJoints.count).forEach { humanIdx in
                            let conn = humanJoints[humanIdx]
                            if (conn.contains(c.joint1) && !conn.contains(c.joint2)) ||
                                (conn.contains(c.joint2) && !conn.contains(c.joint1)) {
                                humanJoints[humanIdx].insert(c.joint1)
                                humanJoints[humanIdx].insert(c.joint2)
                                self.humanConnections[humanIdx]?.append(c)
                                added = true
                                return
                            }
                        }
                        if !added {
                            humanJoints.append([c.joint1, c.joint2])
                            self.humanConnections[humanJoints.count - 1] = [c]
                        }
                    }
                    completion(self.humanConnections)
                }
            }
        }
        return coremlRequest
    }
}

extension PoseEstimation {
    
    private var modelOutputLayerStride: Int {
        return self.modelConfig.outputWidh * self.modelConfig.outputHeight
    }
    
    public var coreMLProcessingTime: String {
        let timeElapsed = coremlProcessingFinish.timeIntervalSince(coremlProcessingStart)
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: timeElapsed)) ?? ""
    }
    
    public func heatMapLayersCombined(completion: @escaping ((UIImage)->())) {
        let heatMatCount = modelConfig.backgroundLayerIndex
        DispatchQueue.global(qos: .userInteractive).async {
            completion(self.networkOutput.drawMatricesCombined(matricesCount: heatMatCount,
                                                      width: self.modelConfig.outputWidh,
                                                      height: self.modelConfig.outputHeight,
                                                      colors: Pose.colors).resized(to: self.modelConfig.inputSize))
        }
    }
    
    public func heatMapCandidatesImage(completion: @escaping ((UIImage)->())) {
        guard networkOutput.count >= modelConfig.layersCount * self.modelOutputLayerStride else {
            log.error("The netowrk output array has an incorrect size or it was not set")
            completion(UIImage())
            return
        }
        
        let modelOutputWidth = modelConfig.outputWidh
        let modelOutputHeight = modelConfig.outputHeight
        let backgroundLayer = Array(networkOutput.slice(blockIndex: modelConfig.backgroundLayerIndex,
                                                  blockSize: modelOutputLayerStride))
        DispatchQueue.global(qos: .userInteractive).async {
            // Draw heatmap candidates for joints after NN output filtering
            // Use alpha to indicate candiates confidence
            let resizedBackgroundLayer = backgroundLayer.draw(width: modelOutputWidth,
                                                              height: modelOutputHeight).resized(to: self.modelConfig.inputSize)
            completion(self.heatMapCandidates.draw(width: modelOutputWidth,
                                          height: modelOutputHeight,
                                          radius: 3.0,
                                          lineWidth: 2.0,
                                          on: resizedBackgroundLayer))
        }
    }
    
    public func filteredHeatMapCandidatesImage(completion: @escaping ((UIImage)->())) {
        DispatchQueue.global(qos: .userInteractive).async {
            // Draw joint candidates after second round filtering
            completion(self.filteredHeatMapCandidates.draw(width: self.modelConfig.outputWidh,
                                                  height: self.modelConfig.outputHeight,
                                                  radius: 3.0,
                                                  lineWidth: 6.0,
                                                  on: UIImage.image(with: .white, size: self.modelConfig.inputSize)))
        }
    }
    
    public func jointsWithConnectionsImage(completion: @escaping ((UIImage)->())) {
        DispatchQueue.global(qos: .userInteractive).async {
            // Draw all connecions using a score as an alpha
            let allConnectionsImage = self.connectionCandidates.draw(width: self.modelConfig.outputWidh,
                                                                   height: self.modelConfig.outputHeight,
                                                                   lineWidth: 5,
                                                                   on: UIImage.image(with: .white, size: self.modelConfig.inputSize))
            // Draw filtered joints over the all connection candidates
            completion(self.filteredHeatMapCandidates.draw(width: self.modelConfig.outputWidh,
                                        height: self.modelConfig.outputHeight,
                                        radius: 5,
                                        lineWidth: 3,
                                        on: allConnectionsImage))
        }
    }
    
    public func jointsWithConnectionsByLayers(completion: @escaping (([UIImage])->())) {
        guard networkOutput.count >= modelConfig.layersCount * self.modelOutputLayerStride else {
            log.error("The netowrk output array has an incorrect size or it was not set")
            completion([UIImage()])
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            let modelOutputWidth = self.modelConfig.outputWidh
            let modelOutputHeight = self.modelConfig.outputHeight
            let pafLayerStartIndex = self.modelConfig.pafLayerStartIndex
            let modelInputSize = self.modelConfig.inputSize
            var resultImages: [UIImage] = []
            let pose = PoseModelConfigurationMPI15()
            pose.jointConnections.forEach { connection in
                let (indexX, indexY) = connection.pafIndices
                let pafMatX = Array(self.networkOutput.slice(blockIndex: pafLayerStartIndex + indexX,
                                                       blockSize: self.modelOutputLayerStride))
                let pafMatY = Array(self.networkOutput.slice(blockIndex: pafLayerStartIndex + indexY,
                                                       blockSize: self.modelOutputLayerStride))
                let pafXImage = pafMatX.draw(width: modelOutputWidth, height: modelOutputHeight)
                let pafYImage = pafMatY.draw(width: modelOutputWidth, height: modelOutputHeight)
                
                // Two joints one connection
                let joints1 = self.heatMapCandidates.filter({ $0.layerIndex == connection.joints.0.index()})
                let joints2 = self.heatMapCandidates.filter({ $0.layerIndex == connection.joints.1.index()})
                let filteredJoints1 = self.filteredHeatMapCandidates.filter({ $0.layerIndex == connection.joints.0.index()})
                let filteredJoints2 = self.filteredHeatMapCandidates.filter({ $0.layerIndex == connection.joints.1.index()})
                let jointConns = self.connectionCandidates.filter({ $0.connection == connection })
                
                // The index of joint is equal to a heatmap index
                let (heatMapIndex1, heatMapIndex2) = (connection.joints.0.index(), connection.joints.1.index())
                // Heatmap's starts from the zero index therefore no offset is needed for a 'heatMapIndex'
                // 'heatMap1' corresponds to the first joint, 'heatMap2' to the second one
                let heatMap1 = Array(self.networkOutput.slice(blockIndex: heatMapIndex1,
                                                        blockSize: self.modelOutputLayerStride))
                let heatMap2 = Array(self.networkOutput.slice(blockIndex: heatMapIndex2,
                                                        blockSize: self.modelOutputLayerStride))
                var heatMap1Image = heatMap1.draw(width: modelOutputWidth, height: modelOutputHeight)
                var heatMap2Image = heatMap2.draw(width: modelOutputWidth, height: modelOutputHeight)
                
                heatMap1Image = filteredJoints1.draw(width: modelOutputWidth,
                                                     height: modelOutputHeight,
                                                     alpha: 1.0,
                                                     radius: 5,
                                                     lineWidth: 3,
                                                     on: heatMap1Image.resized(to: modelInputSize))
                resultImages.append(joints1.draw(width: modelOutputWidth,
                                                 height: modelOutputHeight,
                                                 radius: 5,
                                                 lineWidth: 0.5,
                                                 on: heatMap1Image))
                heatMap2Image = filteredJoints2.draw(width: modelOutputWidth,
                                                     height: modelOutputHeight,
                                                     alpha: 1.0,
                                                     radius: 5,
                                                     lineWidth: 3,
                                                     on: heatMap2Image.resized(to: modelInputSize))
                resultImages.append(joints2.draw(width: modelOutputWidth,
                                                 height: modelOutputHeight,
                                                 radius: 5,
                                                 lineWidth: 0.5,
                                                 on: heatMap2Image))
                resultImages.append(filteredJoints1.draw(width: modelOutputWidth,
                                                         height: modelOutputHeight,
                                                         alpha: 1.0,
                                                         radius: 7,
                                                         lineWidth: 3,
                                                         on: pafXImage.resized(to: modelInputSize)))
                resultImages.append(filteredJoints2.draw(width: modelOutputWidth,
                                                         height: modelOutputHeight,
                                                         alpha: 1.0,
                                                         radius: 7,
                                                         lineWidth: 3,
                                                         on: pafYImage.resized(to: modelInputSize)))
                resultImages.append(jointConns.draw(width: modelOutputWidth,
                                                    height: modelOutputHeight,
                                                    lineWidth: 3,
                                                    on: pafXImage.resized(to: modelInputSize)))
                resultImages.append(jointConns.draw(width: modelOutputWidth,
                                                    height: modelOutputHeight,
                                                    lineWidth: 3,
                                                    on: pafYImage.resized(to: modelInputSize)))
            }
            completion(resultImages)
        }
    }
    
    public func humanPosesImage(overImage: UIImage, completion: @escaping ((UIImage)->())) {
        guard self.humanConnections.count > 0 else {
            log.error("No human pose was detected")
            completion(UIImage())
            return
        }
        // Draw human joints and connections over an input image
        DispatchQueue.global(qos: .userInteractive).async {
            var resultImage = overImage.grayed
            self.humanConnections.forEach { h in
                resultImage = h.value.draw(width: self.modelConfig.outputWidh,
                                           height: self.modelConfig.outputHeight,
                                           lineWidth: 3,
                                           drawJoint: true,
                                           alpha: 1.0,
                                           on: resultImage)
            }
            completion(resultImage)
        }
    }
    
    public func pafLayersCombinedImage(completion: @escaping ((UIImage)->())) {
        guard networkOutput.count >= modelConfig.layersCount * self.modelOutputLayerStride else {
            log.error("The netowrk output array has an incorrect size or it was not set")
            completion(UIImage())
            return
        }
        let layersCount = self.modelConfig.layersCount
        let modelOutputWidth = self.modelConfig.outputWidh
        let modelOutputHeight = self.modelConfig.outputHeight
        let pafLayerStartIndex = self.modelConfig.pafLayerStartIndex
        let modelOutputLayerStride = self.modelOutputLayerStride
        
        let pafCount = layersCount - pafLayerStartIndex
        DispatchQueue.global(qos: .userInteractive).async {
            
            // PAF matrices go from the pafLayerStartIndex till the end of the NN output array
            let pafArray = Array(self.networkOutput[(pafLayerStartIndex * modelOutputLayerStride)...])
            let pointer = UnsafeMutablePointer<Float>(mutating: pafArray)
            for layerIndex in 0..<pafCount {
                let layerPtr = pointer.advanced(by: layerIndex * modelOutputLayerStride)
                let channelArray = pafArray.slice(blockIndex: layerIndex, blockSize: modelOutputLayerStride)
                let keyFactor = Float(10000) // is used to make a key(integral value) out of float value
                let valSet = NSCountedSet(array: channelArray.map { ($0 * keyFactor).rounded() })
                let hist = valSet.sorted(by: { (a, b) -> Bool in
                    return valSet.count(for: a) < valSet.count(for: b)
                })
                if let last = hist.last as? Int {
                    let maxHist = Float(last) / keyFactor
                    for idx in 0..<modelOutputLayerStride {
                        if layerPtr[idx] < 0 {
                            layerPtr[idx] = abs(layerPtr[idx] - maxHist)
                        }
                    }
                }
            }
            let image = pafArray.drawMatricesCombined(matricesCount: pafCount, width: modelOutputWidth,
                                                     height: modelOutputHeight, colors: Pose.colors).resized(to: self.modelConfig.inputSize)
            completion(image)
        }
    }
}
