//
//  JCMTimeSliderUtilsTests1.swift
//  TimeSlider
//
//  Created by Larry Pepchuk on 5/12/15.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Accenture. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


import Foundation
import UIKit
import XCTest
import TimeSlider

//
//  Contains various unit tests for JCMTimeSliderUtils methods
//
class JCMTimeSliderUtilsTests1: XCTestCase {
    
    let tsu = JCMTimeSliderUtils()
    
    // Create an empty data source
    var testDataSource = TimeSliderTestDataSource(data: [JCMTimeSliderControlDataPoint]())

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    
    
    //
    //  Tests public initializer of TimeMappingPoint struct
    //
    func testTimeMappingPointInitMethod() {
        
        // Zero values with nil index
        var y: CGFloat = 0.0
        var ti: NSTimeInterval = 0
        var index: Int? = nil
        var testPoint = TimeMappingPoint(ti:ti, y:y, index:index)

        XCTAssertEqual(testPoint.ti, ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, y, "Y coordinate should match")
        XCTAssertNil(testPoint.index, "Index should be nil")

        
        // Zero values for all params
        y = 0.0
        ti = 0
        index = 0
        testPoint = TimeMappingPoint(ti:ti, y:y, index:index)
        
        XCTAssertEqual(testPoint.ti, ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, y, "Y coordinate should match")
        XCTAssertNotNil(testPoint.index, "Index should not be nil")
        XCTAssertEqual(testPoint.index!, index!, "Index should match")
        
        
        // Non-zero values for all params
        y = 1.0
        ti = 2
        index = 3
        testPoint = TimeMappingPoint(ti:ti, y:y, index:index)
        
        XCTAssertEqual(testPoint.ti, ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, y, "Y coordinate should match")
        XCTAssertNotNil(testPoint.index, "Index should not be nil")
        XCTAssertEqual(testPoint.index!, index!, "Index should match")
    }
    
    //
    //  Tests 'slopeTo' method of TimeMappingPoint struct
    //
    //  NOTE: index param does not influence slope calculation
    //
    func testTimeMappingPointSlopeToMethod() {
        
        let pointZero = TimeMappingPoint(ti:0, y:0.0, index:nil)
        let pointTen = TimeMappingPoint(ti:10, y:10.0, index:nil)
        
        // Slope is not defined here (90 degrees, a vertical line) but the method returns zero
        XCTAssertEqual(pointZero.slopeTo(pointZero), 0, "Slope should be 0.0")
        XCTAssertEqual(pointZero.slopeTo(TimeMappingPoint(ti:0, y:1.0, index:nil)), 0, "Slope should be 0.0")
        XCTAssertEqual(pointTen.slopeTo(TimeMappingPoint(ti:10, y:0.0, index:nil)), 0, "Slope should be 0.0")

        // Slope = 0
        var testPoint = TimeMappingPoint(ti:10, y:0.0, index:nil)
        var slope: CGFloat = 0.0
        XCTAssertEqual(pointZero.slopeTo(testPoint), slope, "Slope should match")
        XCTAssertEqual(testPoint.slopeTo(pointZero), slope, "Slope should match")

        // Slope = 0.1
        testPoint = TimeMappingPoint(ti:10, y:1.0, index:nil)
        slope = 0.1
        XCTAssertEqual(pointZero.slopeTo(testPoint), slope, "Slope should match")
        XCTAssertEqual(testPoint.slopeTo(pointZero), slope, "Slope should match")
        
        // Slope = 1.0
        testPoint = TimeMappingPoint(ti:1, y:1.0, index:nil)
        slope = 1.0
        XCTAssertEqual(pointZero.slopeTo(testPoint), slope, "Slope should match")
        XCTAssertEqual(testPoint.slopeTo(pointZero), slope, "Slope should match")

        testPoint = TimeMappingPoint(ti:10, y:10.0, index:nil)
        XCTAssertEqual(pointZero.slopeTo(testPoint), slope, "Slope should match")
        XCTAssertEqual(testPoint.slopeTo(pointZero), slope, "Slope should match")
        
        // Slope = 10.0
        testPoint = TimeMappingPoint(ti:10, y:100.0, index:nil)
        slope = 10.0
        XCTAssertEqual(pointZero.slopeTo(testPoint), slope, "Slope should match")
        XCTAssertEqual(testPoint.slopeTo(pointZero), slope, "Slope should match")
    }
    
    
    //
    //  Tests 'projectTime' method of TimeMappingPoint struct
    //
    //  NOTE: index param does not influence project time calculation
    //
    func testTimeMappingPointProjectTimeMethod() {
        
        //
        //  Tests with pointZero
        //
        let pointZero = TimeMappingPoint(ti:0, y:0.0, index:nil)
        
        // Time Interval = 0; Slope = 0
        var new_ti: NSTimeInterval = 0
        var slope: CGFloat = 0.0
        var targetY: CGFloat = 0.0
        var testPoint = pointZero.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 10; Slope = 0
        new_ti = 10
        slope = 0.0
        targetY = 0.0
        testPoint = pointZero.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 0; Slope = 0.1
        new_ti = 0
        slope = 0.1
        targetY = 0.0
        testPoint = pointZero.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 10; Slope = 0.1
        new_ti = 10
        slope = 0.1
        targetY = 1.0
        testPoint = pointZero.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 0; Slope = 1
        new_ti = 0
        slope = 1.0
        targetY = 0.0
        testPoint = pointZero.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 10; Slope = 1
        new_ti = 10
        slope = 1.0
        targetY = 10.0
        testPoint = pointZero.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 0; Slope = 10
        new_ti = 0
        slope = 10.0
        targetY = 0.0
        testPoint = pointZero.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 10; Slope = 10
        new_ti = 10
        slope = 10.0
        targetY = 100.0
        testPoint = pointZero.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        
        //
        //  Tests with pointTen
        //
        let pointTen = TimeMappingPoint(ti:10, y:10.0, index:nil)
        
        
        // Time Interval = 0; Slope = 0
        new_ti = 0
        slope = 0.0
        targetY = 10.0
        testPoint = pointTen.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 10; Slope = 0
        new_ti = 10
        slope = 0.0
        targetY = 10.0
        testPoint = pointTen.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 0; Slope = 0.1
        new_ti = 0
        slope = 0.1
        targetY = 9.0
        testPoint = pointTen.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 10; Slope = 0.1
        new_ti = 10
        slope = 0.1
        targetY = 10.0
        testPoint = pointTen.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 0; Slope = 1
        new_ti = 0
        slope = 1.0
        targetY = 0.0
        testPoint = pointTen.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 10; Slope = 1
        new_ti = 10
        slope = 1.0
        targetY = 10.0
        testPoint = pointTen.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 0; Slope = 10
        new_ti = 0
        slope = 10.0
        targetY = -90.0
        testPoint = pointTen.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
        
        // Time Interval = 10; Slope = 10
        new_ti = 10
        slope = 10.0
        targetY = 10.0
        testPoint = pointTen.projectTime(new_ti, slope: slope)
        XCTAssertEqual(testPoint.ti, new_ti, "Time interval should match")
        XCTAssertEqual(testPoint.y, targetY, "Y coordinate should match")
    }
    
    
    
    
    //
    //  Tests 'projectOffset' method of TimeMappingPoint struct
    //
    //  NOTE: index param does not influence project time calculation
    //
    func testTimeMappingPointProjectOffsetMethod() {
        
        //
        //  Tests with pointZero
        //
        let pointZero = TimeMappingPoint(ti:0, y:0.0, index:nil)
        
        // Y coordinate = 0; Slope = 0
        var new_y: CGFloat = 0.0
        var slope: CGFloat = 0.0    // Slope zero is invalid
        var targetTi: NSTimeInterval = 0
        var testPoint = pointZero.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 10; Slope = 0
        new_y = 10.0
        slope = 0.0    // Slope zero is invalid
        targetTi = 0
        testPoint = pointZero.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 0; Slope = 0.1
        new_y = 0.0
        slope = 0.1
        targetTi = 0
        testPoint = pointZero.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 10; Slope = 0.1
        new_y = 10.0
        slope = 0.1
        targetTi = 100
        testPoint = pointZero.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 0; Slope = 1
        new_y = 0.0
        slope = 1.0
        targetTi = 0
        testPoint = pointZero.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 10; Slope = 1
        new_y = 10.0
        slope = 1.0
        targetTi = 10
        testPoint = pointZero.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 0; Slope = 10
        new_y = 0.0
        slope = 10.0
        targetTi = 0
        testPoint = pointZero.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 10; Slope = 10
        new_y = 10.0
        slope = 10.0
        targetTi = 1
        testPoint = pointZero.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        
        //
        //  Tests with pointTen
        //
        let pointTen = TimeMappingPoint(ti:10, y:10.0, index:nil)
        
        
        // Y coordinate = 0; Slope = 0
        new_y = 0.0
        slope = 0.0    // Slope zero is invalid
        targetTi = 0
        testPoint = pointTen.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 10; Slope = 0
        new_y = 10.0
        slope = 0.0    // Slope zero is invalid
        targetTi = 0
        testPoint = pointTen.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 0; Slope = 0.1
        new_y = 0.0
        slope = 0.1
        targetTi = -90
        testPoint = pointTen.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 10; Slope = 0.1
        new_y = 10.0
        slope = 0.1
        targetTi = 10
        testPoint = pointTen.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 0; Slope = 1
        new_y = 0.0
        slope = 1.0
        targetTi = 0
        testPoint = pointTen.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 10; Slope = 1
        new_y = 10.0
        slope = 1.0
        targetTi = 10
        testPoint = pointTen.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 0; Slope = 10
        new_y = 0.0
        slope = 10.0
        targetTi = 9
        testPoint = pointTen.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
        // Y coordinate = 10; Slope = 10
        new_y = 10.0
        slope = 10.0
        targetTi = 10
        testPoint = pointTen.projectOffset(new_y, slope: slope)
        XCTAssertEqual(testPoint.y, new_y, "Y coordinate should match")
        XCTAssertEqual(testPoint.ti, targetTi, "Time interval should match")
        
    }
  
  
  //
  //  Tests for 'linearDateFrom' method with empty breakpoints and zero offset
  //
  func testlinearDateFromWithEmptyBreakpoints() {
    
    var breakPoints = Dictionary<JCMTimeSliderUtils.BreakPoint,TimeMappingPoint>()
    var offset: CGFloat
    offset = 0.0
    
    let date = self.tsu.linearDateFrom(breakPoints, from: offset)
    
    let refDate = NSDate(timeIntervalSinceReferenceDate: 0)
    XCTAssertEqual(date, refDate, "Should return a reference date")
  }
  
  
  //
  //  Tests for 'linearDateFrom' method with one valid breakpoint (earliest only; invalid configuration) and zero offset
  //
  func testlinearDateFromWithOneBreakpoint() {
    
    let firstDate = NSDate()
    let lastDate = firstDate.dateByAddingTimeInterval(60*60*24*7) // add one week
    let lowestCoord: CGFloat = 100.0
    let highestCoord: CGFloat = 200.0
    let numDates = 3
    
    var breakPoints = Dictionary<JCMTimeSliderUtils.BreakPoint,TimeMappingPoint>()
    
    // Use some valid values for earliest and latest break points
    breakPoints[.Earliest] = TimeMappingPoint(ti: firstDate.timeIntervalSinceReferenceDate, y: lowestCoord, index: 0)
    
    var offset: CGFloat
    offset = 0.0
    
    let date = self.tsu.linearDateFrom(breakPoints, from: offset)
    
    let refDate = NSDate(timeIntervalSinceReferenceDate: 0)
    XCTAssertEqual(date, refDate, "Should return a reference date")
  }
  
  
  //
  //  Tests for 'linearDateFrom' method with two valid breakpoints (earliest, latest) and zero offset
  //
  func testlinearDateFromWithTwoBreakpoints() {
    
    let firstDate = NSDate()
    let lastDate = firstDate.dateByAddingTimeInterval(60*60*24*7) // add one week
    let lowestCoord: CGFloat = 100.0
    let highestCoord: CGFloat = 200.0
    let numDates = 2
    
    var breakPoints = Dictionary<JCMTimeSliderUtils.BreakPoint,TimeMappingPoint>()
    
    // Use some valid values for earliest and latest break points
    breakPoints[.Earliest] = TimeMappingPoint(ti: firstDate.timeIntervalSinceReferenceDate, y: lowestCoord, index: 0)
    breakPoints[.Latest] = TimeMappingPoint(ti: lastDate.timeIntervalSinceReferenceDate, y: highestCoord, index: numDates-1)
    
    var offset: CGFloat
    offset = 200.0
    
    let date = self.tsu.linearDateFrom(breakPoints, from: offset)
    
    let refDate = lastDate
    XCTAssertEqual(date, refDate, "Should return correct date")
  }
  
  
  //
  //  Tests for 'linearDateFrom' method with three valid breakpoints (earliest, latest) and zero offset
  //
  func testlinearDateFromWithThreeBreakpoints() {
    
    let firstDate = NSDate()
    let lastDate = firstDate.dateByAddingTimeInterval(60*60*24*7) // add one week
    let lowestCoord: CGFloat = 100.0
    let highestCoord: CGFloat = 200.0
    let numDates = 3
    
    var breakPoints = Dictionary<JCMTimeSliderUtils.BreakPoint,TimeMappingPoint>()
    
    // Use some valid values for earliest and latest break points
    breakPoints[.Earliest] = TimeMappingPoint(ti: firstDate.timeIntervalSinceReferenceDate, y: lowestCoord, index: 0)
    breakPoints[.FirstDistorted] = TimeMappingPoint(ti: firstDate.timeIntervalSinceReferenceDate + 60*60*24, y: lowestCoord, index: 1)
    breakPoints[.Latest] = TimeMappingPoint(ti: lastDate.timeIntervalSinceReferenceDate, y: highestCoord, index: numDates-1)

    var offset: CGFloat

    offset = lowestCoord
    var date = self.tsu.linearDateFrom(breakPoints, from: offset)
    var refDate = firstDate
    XCTAssertEqual(date, refDate, "Should return correct date")
    
    offset = highestCoord
    date = self.tsu.linearDateFrom(breakPoints, from: offset)
    refDate = lastDate
    XCTAssertEqual(date, refDate, "Should return correct date")
  }
}
