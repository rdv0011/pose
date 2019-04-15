//
//  poseTests.swift
//  poseTests
//
//  Created by Dmitry Rybakov on 2019-03-20.
//  Copyright © 2019 Dmitry Rybakov. All rights reserved.
//

import XCTest
import CoreML
@testable import Pose

class PoseTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testModel() {
    }

    func testExample() {
//        guard let testImage = UIImage(named: "sample-pose", in: Bundle(for: PoseTests.self), compatibleWith: nil) else {
//            assertionFailure("Failed to open image")
//            return
//        }
//
//        let pose = PoseEstimation(model: PoseModel().model, modelConfig: PoseModelConfigurationMPI15())
//        let estimationCompleted = XCTestExpectation(description: "Pose estimation has completed")
//        pose.estimate(on: testImage) { humans in
//            print(humans)
//            estimationCompleted.fulfill()
//        }
//        wait(for: [estimationCompleted], timeout: 50.0)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
