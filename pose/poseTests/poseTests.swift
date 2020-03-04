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
    
    var pose: PoseEstimation?
    let estimationTimeout = 50.0
    var testImage: UIImage?

    override func setUp() {
        pose = PoseEstimation(model: PoseModel().model, modelConfiguration: ModelConfigurationCNNMulti15())
        testImage = UIImage(named: "sample-pose1-resized", in: Bundle(for: PoseTests.self), compatibleWith: nil)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testPoseEstimation() {
        guard let testImage = testImage else {
            assertionFailure("A test image is not set")
            return
        }

        let estimationCompleted = XCTestExpectation(description: "Pose estimation has completed")
        pose?.estimate(on: testImage) { humans in
            XCTAssertEqual(1, humans.count, "Incorrect amount of poses")
            XCTAssertEqual(14, humans[0]?.count, "Incorrect amount of pose parts")
            estimationCompleted.fulfill()
        }
        wait(for: [estimationCompleted], timeout: estimationTimeout)
    }

    func testStride() {
        let pose = PoseEstimation(model: PoseModel().model, modelConfiguration: ModelConfigurationCNNMulti15())
        let strideResult = [[0, 0, 4, 0, 5], [0, 0, -4, 0, 5], [0, 0, -4, -4, 5],
        [-4, -4, 0, 0, 5], [0, -4, 0, 0, 5], [0, -4, 0, 0, 5],
        [0, 0, 4, 2, 5], [0, 0, -4, -2, 5], [0, 0, -2, -4, 5]]
        strideResult.forEach { a in
            pose.stride_testable(x1: a[0], y1: a[1], x2: a[2], y2: a[3]) { (x, y, idx, stepCount) in
                XCTAssertEqual(stepCount, a[4], "The number of steps is incorrect")
                XCTAssert(x == a[0] && y == a[1] && idx == 0, "x or y is not correct for index \(idx)")
                XCTAssert(x == a[2] && y == a[3] && idx == stepCount - 1, "x or y is not correct for index \(idx)")
            }
        }
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
