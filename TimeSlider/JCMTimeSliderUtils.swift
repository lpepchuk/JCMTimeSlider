//
//  JCMTimeSliderUtils.swift
//  TimeSlider
//
//  Created by Larry Pepchuk on 5/11/15.
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
import QuartzCore

// Slider will accept data source that has not more than this (max) record count
let DATA_SOURCE_MAX_RECORD_COUNT = 1000

/**
*  Used to map time to points and vice versa
*
*   NOTE: 'public' access is required for unit testing (as code runs in a separate module)
*/
public struct TimeMappingPoint {
  
  public var ti: NSTimeInterval
  public var y: CGFloat
  public var index: Int?
  
  //
  //  We must define public initializer to be able to Unit Test the struct
  //
  public init(ti: NSTimeInterval, y: CGFloat, index: Int?) {
    self.ti = ti
    self.y = y
    self.index = index
  }
  
  //
  //  Computes slope for two time mapping points.
  //
  //  Slope is defined as: {Y coordinates difference} / {time interval difference}
  //
  public func slopeTo(other: TimeMappingPoint) -> CGFloat {
    
    // Make sure we don't try to divide by zero
    if other.ti - ti == 0 {
      
      // Officially, slope is not defined here (it is a vertical line)
      return 0.0
    } else {
      return (other.y - y) / CGFloat(other.ti - ti)
    }
  }
  
  
  //
  //  Creates a new time mapping point using time interval and a slope.
  //
  //  Computes new Y coordinate as: slope * {time interval difference} + y
  //
  public func projectTime(new_ti: NSTimeInterval, slope: CGFloat) -> TimeMappingPoint {
    
    let new_y: CGFloat = slope * CGFloat(new_ti-ti) + y
    
    return TimeMappingPoint(ti: new_ti, y: new_y, index: nil)
  }
  
  //
  //  Creates a new time mapping point using Y coordinate and a slope.
  //
  //  Computes new time interval as: ti + {Y coordinate difference} / slope
  //
  public func projectOffset(new_y: CGFloat, slope: CGFloat) -> TimeMappingPoint {
    
    let new_ti: NSTimeInterval
    
    // Make sure we don't try to divide by zero
    if slope == 0 {
      
      // Officially, time interval is not defined here (zero slope is invalid)
      
      new_ti = 0 // return zero
    } else {
      new_ti = ti + NSTimeInterval((new_y - y) / slope)
    }
    
    return TimeMappingPoint(ti: new_ti, y: new_y, index:nil)
  }
}

public enum PointKind {
  case Linear, Anchored, FloatLeft, LinearMiddle, FloatRight
}


public class JCMTimeSliderUtils {
  
  public init() {
    // Initialize elements
  }
  
  public enum BreakPoint : Int {
    case Earliest=0, FirstDistorted, Selected, LastDistorted, Latest
  }
  
  /**
  Binary search for the index with the closest date to the one passed by parameter
  
  :param: searchItem the date we want to find in the data source
  
  :returns: the index at which we find the closest date available
  
  NOTE: The method is always expected to find the closest date in the past
  */
  public func findNearestDate(dataSource: JCMTimeSliderControlDataSource?, searchItem :NSDate) -> Int {
    
    assert(dataSource!.numberOfDates() <= DATA_SOURCE_MAX_RECORD_COUNT, "Data source should contain \(DATA_SOURCE_MAX_RECORD_COUNT) records or less")
    
    var lowerIndex = 0;
    var upperIndex = dataSource!.numberOfDates()-1
    
    while (true) {
      var currentIndex = (lowerIndex + upperIndex)/2
      
      let dataPoint = dataSource!.dataPointAtIndex(currentIndex)
      
      if(dataPoint.date == searchItem) {
        return currentIndex
      } else if (lowerIndex > upperIndex) {
        return currentIndex
      } else {
        if (dataPoint.date.compare(searchItem) == NSComparisonResult.OrderedDescending) {
          upperIndex = currentIndex - 1
        } else {
          lowerIndex = currentIndex + 1
        }
      }
    }
  }
  
  
  /**
  Linearly converts from a given offset to the corresponding date
  
  :param: from the offset in the control geometry
  
  :returns: the date that corresponds linearly to that offset
  */
  public func linearDateFrom(breakPoints: Dictionary<BreakPoint,TimeMappingPoint>, from: CGFloat) -> NSDate {
    
    var temp = TimeMappingPoint(ti: 0, y: 0, index: 0)
    
    // Make sure we have at least 2 breakpoints defined (both the earliest and the latest)
    if (breakPoints.count >= 2) {
      let earliest = breakPoints[.Earliest]
      let latest = breakPoints[.Latest]
      let slope = earliest!.slopeTo(latest!)
      temp = earliest!.projectOffset(from, slope: slope)
    }
  
    return NSDate(timeIntervalSinceReferenceDate:temp.ti)
  }
  
  
  
  // MARK: - Setup
  
  
  /**
  Every time the data source changes, we call this method to set the end points of the control
  and cache the dates and coordinates of the corresponding points.
  We also call this every time the geometry changes
  The invariant after this call is that breakPoints[.Earliest] and breakPoints[.Latest] will be
  set, either nil if the control is useable (more than 2 dates), or valid TimeMappingPoints
  */
  func setupEndPoints(
    dataSource: JCMTimeSliderControlDataSource?,
    breakPoints: Dictionary<BreakPoint,TimeMappingPoint>,
    frame: CGRect,
    dataInsets: CGSize) -> Dictionary<BreakPoint,TimeMappingPoint> {
      
      assert(dataSource!.numberOfDates() <= DATA_SOURCE_MAX_RECORD_COUNT, "Data source should contain \(DATA_SOURCE_MAX_RECORD_COUNT) records or less")
      
      var localBreakPoints = breakPoints
      
      localBreakPoints.removeAll()
      localBreakPoints[.Earliest] = nil
      localBreakPoints[.Latest] = nil
      
      if let ds = dataSource {
        let numDates = dataSource!.numberOfDates()
        if numDates > 2 {
          let firstDate = dataSource!.dataPointAtIndex(0).date
          let lastDate = dataSource!.dataPointAtIndex(numDates-1).date
          let lowestCoord = dataInsets.height
          let highestCoord = frame.height - 2.0 * dataInsets.height
          localBreakPoints[.Earliest] = TimeMappingPoint(ti: firstDate.timeIntervalSinceReferenceDate, y: lowestCoord, index: 0)
          localBreakPoints[.Latest] = TimeMappingPoint(ti: lastDate.timeIntervalSinceReferenceDate, y: highestCoord, index: numDates-1)
        }
      }
      
      return localBreakPoints
  }
  
  
  /**
  Every time the selected index changes, we call this method to set the middle points of the control
  and cache the dates and coordinates.
  */
  func setupMidPoints(
    dataSource: JCMTimeSliderControlDataSource?,
    breakPoints: Dictionary<BreakPoint,TimeMappingPoint>,
    lastSelectedIndex: Int?,
    shouldUseTimeExpansion : Bool,
    linearExpansionRange: Int,
    linearExpansionStep: CGFloat) -> Dictionary<BreakPoint,TimeMappingPoint>
  {
      var updatedBreakPoints: Dictionary<BreakPoint,TimeMappingPoint> = breakPoints
      
      updatedBreakPoints[.FirstDistorted] = nil
      updatedBreakPoints[.LastDistorted] = nil
      updatedBreakPoints[.Selected] = nil
      let earliest = updatedBreakPoints[.Earliest]
      let latest = updatedBreakPoints[.Latest]
      if (earliest == nil) || (latest == nil) {
        return updatedBreakPoints
      }
      if let lsi = lastSelectedIndex {
        let linearSlope = earliest!.slopeTo(latest!)
        let midDate = dataSource!.dataPointAtIndex(lsi).date
        updatedBreakPoints[.Selected] = earliest!.projectTime(midDate.timeIntervalSinceReferenceDate, slope: linearSlope)
        updatedBreakPoints[.Selected]!.index = lsi
        
        if shouldUseTimeExpansion {
          // Here the transfer function will be a broken line of 2 or 3 segments, depending to how
          // close we are to the edge.  The invariant is that the "center" segment, which has low
          // slope to allow precise time selection, always exists.  This segment goes between
          // .FirstDistorted and .LastDistorted
          let lastIndex = dataSource!.numberOfDates()-1
          let firstDistortedIndex = max(lsi - linearExpansionRange, 0)
          let lastDistortedIndex = min(lsi + linearExpansionRange, lastIndex)
          let mid = updatedBreakPoints[.Selected]
          let firstDistortedOffset = max(mid!.y - linearExpansionStep * CGFloat(lsi - firstDistortedIndex), updatedBreakPoints[.Earliest]!.y)
          let lastDistortedOffset = min(mid!.y - linearExpansionStep * CGFloat (lsi - lastDistortedIndex),updatedBreakPoints[.Latest]!.y)
          //println(firstDistortedIndex, lastDistortedIndex, firstDistortedOffset, lastDistortedOffset)
          updatedBreakPoints[.FirstDistorted] = TimeMappingPoint(ti: dataSource!.dataPointAtIndex(firstDistortedIndex).date.timeIntervalSinceReferenceDate, y: firstDistortedOffset, index: firstDistortedIndex)
          updatedBreakPoints[.LastDistorted] = TimeMappingPoint(ti: dataSource!.dataPointAtIndex(lastDistortedIndex).date.timeIntervalSinceReferenceDate, y: lastDistortedOffset, index: lastDistortedIndex)
        }
      }
      
      return updatedBreakPoints
  }

  
  public func dateString(dataPoint: JCMTimeSliderControlDataPoint, format: String) -> NSString {
    
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = format
    
    if dataPoint.hasIcon {
      return "• \(dateFormatter.stringFromDate(dataPoint.date))"
    } else {
      return "  \(dateFormatter.stringFromDate(dataPoint.date))"
    }
  }
  
  
  
  
  
  // MARK: - Offset Calculation
  
  
  
  /**
  Linearly converts from a given date to the corresponding control offset
  
  :param: from is an NSDate that you want to represent on the control
  
  :returns: the offset in the control that corresponds linearly to that date
  */
  public func linearYOffsetFrom(breakPoints: Dictionary<BreakPoint,TimeMappingPoint>, from: NSDate) -> CGFloat {
    
    var temp = TimeMappingPoint(ti: 0, y: 0, index: 0)
    
    // Make sure we have at least 2 breakpoints defined (both the earliest and the latest)
    if (breakPoints.count >= 2) {
    
      let earliest = breakPoints[.Earliest]
      let latest = breakPoints[.Latest]
      let slope = earliest!.slopeTo(latest!)
      temp = earliest!.projectTime(from.timeIntervalSinceReferenceDate, slope: slope)
    }
    
    return temp.y
  }
  
  /**
  Converts from a given date to the corresponding control offset, taking into account the
  last selected item, and a touch offset within the control
  
  :param: from is an NSDate that you want to represent on the control
  
  :returns: the offset in the control that corresponds to that date using the transform
  */
  public func distortedYOffsetFrom(
    breakPoints: Dictionary<BreakPoint,TimeMappingPoint>,
    from: NSDate,
    index: Int,
    expanded: Bool,
    shouldUseTimeExpansion: Bool,
    lastSelectedIndex: Int?,
    numberOfDates: Int,
    linearExpansionStep: CGFloat) -> CGFloat
  {
    var leftPoint : TimeMappingPoint
    var rightPoint : TimeMappingPoint
    
    switch indexToKind(breakPoints, index: index, expanded: expanded,
      shouldUseTimeExpansion: shouldUseTimeExpansion, lastSelectedIndex: lastSelectedIndex, numberOfDates: numberOfDates) {
    case .Anchored, .Linear:
      return linearYOffsetFrom(breakPoints, from: from)
    case .LinearMiddle:
      let baseY = breakPoints[.Selected]!.y
      let dist = index - lastSelectedIndex!
      return baseY + CGFloat(dist) * linearExpansionStep
    case .FloatLeft:
      leftPoint = breakPoints[.Earliest]!
      rightPoint = breakPoints[.FirstDistorted]!
    case .FloatRight:
      leftPoint = breakPoints[.LastDistorted]!
      rightPoint = breakPoints[.Latest]!
    }
    let slope = leftPoint.slopeTo(rightPoint)
    let temp = leftPoint.projectTime(from.timeIntervalSinceReferenceDate, slope: slope)
    
    return temp.y
  }

  /**
  Utility to map a given index to the kind of tick that we should display
  
  :param: index the index of the tick
  
  :returns: the kind of point we should show
  */
  public func indexToKind(
    breakPoints: Dictionary<BreakPoint,TimeMappingPoint>,
    index: Int,
    expanded: Bool,
    shouldUseTimeExpansion: Bool,
    lastSelectedIndex: Int?,
    numberOfDates: Int) -> PointKind
  {
    if expanded && shouldUseTimeExpansion {
      if let lsi = lastSelectedIndex {
        switch index {
        case 0,lsi,numberOfDates:
          return .Anchored
        default:
          if (index >= breakPoints[.FirstDistorted]?.index) && (index <= breakPoints[.LastDistorted]?.index) {
            return .LinearMiddle
          } else if (index < breakPoints[.FirstDistorted]?.index) {
            return .FloatLeft
          } else {
            return .FloatRight
          }
        }
      }
    }
    return .Linear
  }

}
