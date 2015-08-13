//
//  JCMTimeSliderControl.swift
//  TimeSlider
//
//  Created by Juan C. Mendez on 9/27/14.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2014 Juan C. Mendez (jcmendez@alum.mit.edu)
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

import UIKit
import QuartzCore

/**
*  Defines a data point returned by JCMTimeSliderControlDataSource
*
*/
public struct JCMTimeSliderControlDataPoint {
  public let date: NSDate
  public let hasIcon: Bool
  
  //
  //  We must define public initializer to be able to Unit Test the struct
  //
  public init(date: NSDate, hasIcon: Bool) {
    self.date = date
    self.hasIcon = hasIcon
  }
}


// MARK: - JCMTimeSliderControlDataSource


/**
*  Protocol that must be implemented by any data source for this control.  Note that the
*  data source must guarantee that the dates are sorted ascending
*/
public protocol JCMTimeSliderControlDataSource {
  func numberOfDates() -> Int
  func dataPointAtIndex(index: Int) -> JCMTimeSliderControlDataPoint
}


// MARK: - JCMTimeSliderControlDelegate


@objc protocol JCMTimeSliderControlDelegate {
  optional func selectedDate(date:NSDate, index:Int, control:JCMTimeSliderControl)
  optional func hoveredOverDate(date:NSDate, index:Int, control:JCMTimeSliderControl)
  optional func dataPointDateFormat(control:JCMTimeSliderControl) -> String
  optional func boundariesDateFormat(control:JCMTimeSliderControl) -> String
}

// MARK: - JCMTimeSliderControl

class JCMTimeSliderControl: UIControl, UIDynamicAnimatorDelegate, JCMTimeSliderControlDataSource {
  
  required init(coder aDecoder: NSCoder) {
    // Initialize our added elements
    expanded = false
    expansionChangeNeeded = false
    
    super.init(coder: aDecoder)
    
    clipsToBounds = true
    dataSource = self
  }
  
  let tsu = JCMTimeSliderUtils()
  
  /**
  *  We use this shell class to let UIKit Dynamics to do the heavy lifting of the animation
  *  for our selected tick
  */
  internal class DynamicTick : NSObject, UIDynamicItem {
    var tick: CAShapeLayer
    var labels: [CATextLayer]
    var center: CGPoint {
      get {
        return CGPoint(x: tick.frame.midX, y: tick.frame.midY)
      }
      set {
        let w = tick.frame.width
        let h = tick.frame.height
        let xx = newValue.x - w/2.0
        let yy = newValue.y - h/2.0
        let newFrame = CGRect(x: xx, y: yy, width: w, height: h)
        tick.frame = newFrame
      }
    }
    var bounds: CGRect {
      get {
        return tick.bounds
      }
    }
    var transform: CGAffineTransform
    
    init(tick: CAShapeLayer, labels: [CATextLayer]) {
      self.tick = tick
      self.labels = labels
      self.transform = CGAffineTransformIdentity
      super.init()
    }
  }
  
  // MARK: - Properties

  var breakPoints = Dictionary<JCMTimeSliderUtils.BreakPoint,TimeMappingPoint>()
  
  /// Delegate
  var delegate: JCMTimeSliderControlDelegate?
  
  
  // Expanded control is wider by this factor
  let expandedControlWidthFactor: CGFloat = 2.4
  
  // Offset (X) each tick for an expanded control by this many points
  let expandedControlTickXOffset: CGFloat = 50.0
  
  
  /// Is in expanded form?
  var expanded: Bool {
    willSet {
      if expanded != newValue {
        expansionChangeNeeded = true
      }
    }
    
    didSet {
      if expansionChangeNeeded {
        expansionChangeNeeded = false
        if expanded {
          widthConstraint?.constant *= expandedControlWidthFactor
        } else {
          widthConstraint?.constant *=  CGFloat (1 / expandedControlWidthFactor)
        }
        setNeedsLayout()
      }
    }
  }
  
  /// We manage the width of the control by changing this constraint
  @IBOutlet var widthConstraint: NSLayoutConstraint?
  
  /// The color of the labels
  var labelColor: UIColor = UIColor.whiteColor().colorWithAlphaComponent(1.0)
  
  /// The color of the inactive ticks
  var inactiveTickColor: UIColor = UIColor.whiteColor().colorWithAlphaComponent(0.6)
  
  /// The color of the selected tick
  var selectedTickColor: UIColor = UIColor.whiteColor()
  
  var dataInsets: CGSize = CGSize(width: 0.0, height: 15.0)
  
  /// How many ticks around the selected one are shown linearly
  var linearExpansionRange: Int = 5
  
  /// How many pixels are the steps separated on the linear expansion
  var linearExpansionStep: CGFloat = 14.0
  
  /// The index of the last selected tick
  var lastSelectedIndex: Int? {
    didSet {
      breakPoints = self.tsu.setupMidPoints(dataSource, breakPoints: breakPoints, lastSelectedIndex: self.lastSelectedIndex,
        shouldUseTimeExpansion: self.shouldUseTimeExpansion, linearExpansionRange:
        self.linearExpansionRange, linearExpansionStep: linearExpansionStep)
    }
  }
  
  /// Will be set to true if the control is animating the snapping
  var isSnapping: Bool = false
  
  /// Will be set to true if data source is set and it contains at least 3 dates
  var isUsable: Bool = false
  
  /// Flags if snapping was canceled because user re-engaged control
  var canceledSnapping: Bool = false
  
  /// Seconds from the time user lifts touch until the control auto-closes
  let secondsToClose: NSTimeInterval = 0.5
  
  /// Flag to allow the control to keep tracking even if user goes outside the frame
  var allowTrackOutsideControl: Bool = true
  
  /// Layer for the ticks
  private var ticksLayer : CALayer?
  
  /// Layer for the labels
  private var labelsLayer : CALayer?
  
  private var centerTick : DynamicTick?
  
  /// Flag to determine whether to expand horizontally
  private var expansionChangeNeeded : Bool
  
  private var shouldUseTimeExpansion : Bool = false
  
  /// In case we are our own delegate, create an array as needed
  lazy private var dates: Array<NSDate> = {
    return Array<NSDate>()
    }()
  
  /// An animator to show a snapping effect on the selected tick
  lazy private var snapAnimUIDynamicAnimator: UIDynamicAnimator = {
    let animator = UIDynamicAnimator(referenceView: self)
    animator.delegate = self
    return animator
    }()
  
  /// A closure that is used to close the control after user lifts finger
  private var closureToCloseControl : dispatch_cancelable_closure?
  
  
  // MARK: Data source
  
  /// The data source for this control
  var dataSource: JCMTimeSliderControlDataSource? {
    didSet {
      
      // Require data source to have at least 3 data points (dates)
      isUsable = dataSource?.numberOfDates() > 2
      if (isUsable) {
        
        shouldUseTimeExpansion = (dataSource?.numberOfDates() > 2 * linearExpansionRange)
        breakPoints = tsu.setupEndPoints(dataSource, breakPoints: breakPoints, frame: frame, dataInsets: dataInsets)
        setupSubViews()
      }
    }
  }

  
  
  // MARK: - Setup

  
  func setupSubViews() {
    createTicks()
    createLabels()
    updateTicksAndLabels()
  }

  
  override func layoutSubviews() {
    super.layoutSubviews()
    breakPoints = tsu.setupEndPoints(dataSource, breakPoints: breakPoints, frame: frame, dataInsets: dataInsets)
    breakPoints = self.tsu.setupMidPoints(dataSource, breakPoints: breakPoints, lastSelectedIndex: self.lastSelectedIndex,
      shouldUseTimeExpansion: self.shouldUseTimeExpansion, linearExpansionRange:
      self.linearExpansionRange, linearExpansionStep: linearExpansionStep)
    ticksLayer?.frame = bounds
    updateTicksAndLabels()
    labelsLayer?.frame = bounds
  }

  
  // MARK: - Touch Tracking

  
  override func beginTrackingWithTouch(touch: UITouch, withEvent event: UIEvent) -> Bool {

    if (!isUsable) {
      println("beginTrackingWithTouch: !isUsable")
      return false
    }

    if isSnapping {
      println("Canceled snapping")
      canceledSnapping = true
      snapAnimUIDynamicAnimator.removeAllBehaviors()
      if closureToCloseControl != nil {
        cancel_delay(closureToCloseControl)
      }
      isSnapping = false
    }
    expanded = true
    continueTrackingWithTouch(touch, withEvent: event)
    return true  // Track continuously
  }
  
  override func continueTrackingWithTouch(touch: UITouch, withEvent event: UIEvent) -> Bool {
    
    if (!isUsable) {
//    if ((dataSource == nil) || (dataSource!.numberOfDates() < 2)) {
      closeLater()
      return false
    }
    
    let point = touch.locationInView(self)
    let global = touch.locationInView(self.superview)
    let inBounds = frame.contains(global)
    let offset = point.y
    let hypoDate = tsu.linearDateFrom(breakPoints, from: offset)
    lastSelectedIndex = tsu.findNearestDate(self.dataSource, searchItem: hypoDate)
    
    updateTicksAndLabels()
    
    delegate?.hoveredOverDate?(hypoDate, index: lastSelectedIndex!, control:self)
    
    let keepGoing = allowTrackOutsideControl ? true : inBounds
    if !keepGoing {
      closeLater()
    }
    return keepGoing
  }
  
  override func cancelTrackingWithEvent(event: UIEvent?) {
    super.cancelTrackingWithEvent(event)
    closeLater()
  }
  
  override func endTrackingWithTouch(touch: UITouch, withEvent event: UIEvent) {
    super.endTrackingWithTouch(touch, withEvent: event)

    if (!isUsable) {
//    if ((dataSource == nil) || (dataSource!.numberOfDates() < 2)) {
      return
    }
    
//    println("Snapping")
    
    // Prepare the snapping animation to the selected date
    let point = touch.locationInView(self)
    
    let snapPointY = self.tsu.distortedYOffsetFrom(breakPoints, from: dataSource!.dataPointAtIndex(lastSelectedIndex!).date,
      index: lastSelectedIndex!, expanded: expanded, shouldUseTimeExpansion: shouldUseTimeExpansion,
      lastSelectedIndex: lastSelectedIndex, numberOfDates: numberOfDates(), linearExpansionStep: linearExpansionStep)
    if let sublayers = ticksLayer?.sublayers {
      let t = sublayers[lastSelectedIndex!] as! CAShapeLayer
      let labels = labelsLayer!.sublayers as! [CATextLayer]
      
      t.frame.offset(dx: 0, dy: linearExpansionStep)
      centerTick = DynamicTick(tick: t, labels:labels)
      let snapPoint = CGPoint(x: t.frame.midX, y: snapPointY)
      let snap = UISnapBehavior(item: centerTick!, snapToPoint: snapPoint)
      snap.damping = 0.1
      isSnapping = true
      
      if let lsi = lastSelectedIndex {
        let date = dataSource!.dataPointAtIndex(lsi).date
        delegate?.selectedDate?(date, index:lastSelectedIndex!, control:self)
      }
      
      //      snap.action = {
      //        println("Snapping")
      //      }
      snapAnimUIDynamicAnimator.addBehavior(snap)
    } else {
      closeLater()
    }
  }
  
  
  
  
  // MARK: - Tick Methods
  
  

  /**
  Create a layer for the ticks, with sublayers representing each tick
  */
  private func createTicks() {
    
    assert(dataSource != nil, kNoDataSourceInconsistency)
    let lastIndex = dataSource!.numberOfDates()
    
    if ticksLayer != nil {
      ticksLayer!.removeFromSuperlayer()
    }
    
    // If there are any ticks, we add them
    
    if (lastIndex != 0) {
      ticksLayer = CALayer()
      layer.addSublayer(ticksLayer!)
      
      ticksLayer!.masksToBounds = true
      ticksLayer!.position = CGPointZero
      
      for i in 0...lastIndex-1 {
        let aTick = CAShapeLayer()
        aTick.anchorPoint = CGPointZero
        ticksLayer!.addSublayer(aTick)
        
        aTick.frame = CGRect(origin: CGPoint.zeroPoint,size: CGSize(width: frame.width, height: 2.0))
        aTick.fillColor = UIColor.clearColor().CGColor
        aTick.strokeColor = inactiveTickColor.CGColor
        aTick.lineWidth = 1.0
        aTick.lineCap = kCALineCapRound
        aTick.opacity = 1.0
        
        let path = UIBezierPath()
        path.moveToPoint(CGPoint(x: frame.width * 0.66,y: 1.0))
        path.addLineToPoint(CGPoint(x: frame.width, y: 1.0))
        aTick.path = path.CGPath
      }
    }
  }
  
  
  /**
  Create the labels that will show dates
  */
  private func createLabels() {
    
    assert(dataSource != nil, kNoDataSourceInconsistency)
    
    let lastIndex = dataSource!.numberOfDates()
    
    if labelsLayer != nil {
      labelsLayer!.removeFromSuperlayer()
    }
    
    labelsLayer = CALayer()
    layer.addSublayer(labelsLayer!)
    
    labelsLayer!.anchorPoint = CGPointZero
    labelsLayer!.masksToBounds = false
    labelsLayer!.position = CGPointZero
    
    let a : Int = JCMTimeSliderUtils.BreakPoint.Earliest.rawValue
    let b = JCMTimeSliderUtils.BreakPoint.Latest.rawValue
    let font = UIFont.systemFontOfSize(UIFont.smallSystemFontSize())
    let height = font.ascender - font.descender
    for i in a...b {
      let aLabel = CATextLayer()
      aLabel.anchorPoint = CGPointZero
      labelsLayer!.addSublayer(aLabel)
      
      // Frame has to be wide enough to fit the date string with an icon in front
      aLabel.frame = CGRect(x: 0.0, y: 0.0, width: frame.width * 2.0, height: height)
      
      aLabel.fontSize = UIFont.smallSystemFontSize()
      aLabel.font = font
      aLabel.opacity = 0.0
      aLabel.string = ""
    }
    
  }
  
  
  /**
  Set the ticks to the desired position
  */
  func updateTicksAndLabels() {
    
    if (!isUsable) {
      println("updateTicksAndLabels: !isUsable")
      return
    }
    
    assert(dataSource != nil, kNoDataSourceInconsistency)
    
    let font = UIFont.systemFontOfSize(UIFont.smallSystemFontSize())
    let fontOffset = -(font.xHeight / 2.0 - font.descender)
    let lastIndex = dataSource!.numberOfDates()
    
    // Lead spacing between a label and a control
    let labelLeadSpace: CGFloat = 4.0
    
    if let sublayers = ticksLayer?.sublayers {
      assert(lastIndex == sublayers.count, kNoWrongNumberOfLayersInconsistency)
      
      // Pick the transform for the selected tick
      let selectedTransform = CATransform3DConcat(CATransform3DMakeTranslation(-15.0, 0.0, 0.0), CATransform3DMakeScale(2.0, 2.0, 1.0))
      
      // Start animating as a single transaction
      CATransaction.begin()
      CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
      
      // Assume labels won't be visible, to start with
      for label in labelsLayer!.sublayers as! [CATextLayer] {
        label.opacity = 0.0
        label.foregroundColor = labelColor.CGColor
      }
      
      // Process each tick
      for i in 0...lastIndex-1 {
        let tick = sublayers[i] as! CAShapeLayer
        tick.lineWidth = 1.0
        tick.transform = CATransform3DIdentity
        
        var offset = self.tsu.distortedYOffsetFrom(breakPoints, from: dataSource!.dataPointAtIndex(i).date,
          index: i, expanded: expanded, shouldUseTimeExpansion: shouldUseTimeExpansion,
          lastSelectedIndex: lastSelectedIndex, numberOfDates: numberOfDates(), linearExpansionStep: linearExpansionStep)
        
        switch self.tsu.indexToKind(breakPoints, index: i, expanded: expanded, shouldUseTimeExpansion: shouldUseTimeExpansion,
          lastSelectedIndex: lastSelectedIndex, numberOfDates: numberOfDates()) {
        case .LinearMiddle:
          if (offset < breakPoints[.Earliest]!.y) ||
            (offset > breakPoints[.Latest]!.y) {
              tick.strokeColor = UIColor.clearColor().CGColor
          } else {
            let indexDifference = abs(lastSelectedIndex! - i)
            tick.strokeColor = selectedTickColor.colorWithAlphaComponent(1.0-0.5*CGFloat(indexDifference)/CGFloat(linearExpansionRange)).CGColor
          }
        case .FloatRight, .FloatLeft:
          tick.strokeColor = inactiveTickColor.CGColor
        case .Anchored:
          tick.strokeColor = inactiveTickColor.CGColor
        case .Linear:
          tick.strokeColor = inactiveTickColor.CGColor
        }
        
        
        // Always show the labels for the first date
        if (expanded && (i==0) && (lastSelectedIndex != 0)) {
          let topLabel = labelsLayer?.sublayers[JCMTimeSliderUtils.BreakPoint.Earliest.rawValue] as! CATextLayer
          
          let labelPosition = CGPoint(x: labelLeadSpace, y: offset + fontOffset)
          topLabel.position = labelPosition
          
          let labelText = self.tsu.dateString(dataSource!.dataPointAtIndex(i), format:self.boundariesDateFormat(self))
          topLabel.string = labelText
          
          topLabel.opacity = 1.0
        }
        
        // Always show the label for the last date
        if (expanded && (i == lastIndex-1) && (lastSelectedIndex != lastIndex-1)) {
          let bottomLabel = labelsLayer?.sublayers[JCMTimeSliderUtils.BreakPoint.Latest.rawValue] as! CATextLayer
          
          let labelPosition = CGPoint(x: labelLeadSpace, y: offset + fontOffset)
          bottomLabel.position = labelPosition
          
          let labelText = self.tsu.dateString(dataSource!.dataPointAtIndex(i), format:self.boundariesDateFormat(self))
          bottomLabel.string = labelText

          bottomLabel.opacity = 1.0
        }
        
        // Find out if this tick is a "normal" one (outside the expanded range), and process it
        // differently if it is not
        if let lsi = lastSelectedIndex {
          let indexDifference = abs(lsi - i)
          if (indexDifference < linearExpansionRange) {
            if (i == lastSelectedIndex) {
              
              // This is the selected tick.  Draw it, plus its label.
              tick.transform = selectedTransform
              tick.strokeColor = selectedTickColor.CGColor
              tick.lineWidth = 3.0
              
              if expanded {
                
                // Draw selected label
                
                let selectedLabel = labelsLayer?.sublayers[JCMTimeSliderUtils.BreakPoint.Selected.rawValue] as! CATextLayer
                
                let labelPosition = CGPoint(x: labelLeadSpace, y: offset + fontOffset)
                selectedLabel.position = labelPosition
                
                let labelText = self.tsu.dateString(dataSource!.dataPointAtIndex(i), format:self.dataPointDateFormat(self))
                selectedLabel.string = labelText

                selectedLabel.opacity = 1.0
              }
              
            } else {
              // Draw the accessory ticks that visually highlight the expanded range
              if (expanded) {
                tick.transform = CATransform3DMakeTranslation(-2.0 * CGFloat(linearExpansionRange-indexDifference), 0.0, 0.0)
              }
              
              if expanded && (indexDifference == linearExpansionRange - 1) {
                let labelID = (i > lastSelectedIndex) ? JCMTimeSliderUtils.BreakPoint.LastDistorted : JCMTimeSliderUtils.BreakPoint.FirstDistorted
                let label = labelsLayer?.sublayers[labelID.rawValue] as! CATextLayer
                
                label.opacity = 0.3
                label.position = CGPoint(x: labelLeadSpace, y: offset + fontOffset)
                label.string = self.tsu.dateString(dataSource!.dataPointAtIndex(i), format:self.dataPointDateFormat(self))
              }
            }
          }
        }
        
        tick.position = CGPoint(x: (expanded ? expandedControlTickXOffset : 0.0), y: offset)
        
      }
      CATransaction.commit()
    }
    setNeedsDisplay()
  }
  

  
  // MARK: - UIDynamicAnimatorDelegate
  
  
  func dynamicAnimatorDidPause(animator: UIDynamicAnimator) {
    if animator == snapAnimUIDynamicAnimator {
      println("Snapped")
      animator.removeAllBehaviors()
      isSnapping = false
      if canceledSnapping {
        canceledSnapping = false
      } else {
        closeLater()
      }
    }
  }
  
  // MARK: - Data source
  
  func numberOfDates() -> Int {
    return dates.count
  }
  
  func dataPointAtIndex(index: Int) -> JCMTimeSliderControlDataPoint {
    return JCMTimeSliderControlDataPoint(date: dates[index], hasIcon: false)
  }

  
  // MARK: - Delegate methods
  

  // Default date format
  let kLocaleShortDateFormatSwift = NSLocalizedString("MMM-yy", comment: "Short date format : MM/dd/yy in english")
  let kLocaleLongDateFormatSwift = NSLocalizedString("MM/dd/yy", comment: "Long date format : MM/dd/yy in english")
  
  // Delegate can provide data point date format (uses long date format by default)
  func dataPointDateFormat(control:JCMTimeSliderControl) -> String {
    
    if (delegate != nil) {
      
      if let format = delegate!.dataPointDateFormat?(control) {
        return format
      }
    }
    
    return kLocaleLongDateFormatSwift
  }
  
  // Delegate can provide boundaries date format (first/last data point; uses short date format by default)
  func boundariesDateFormat(control:JCMTimeSliderControl) -> String {
    
    if (delegate != nil) {
      
      if let format = delegate!.boundariesDateFormat?(control) {
        return format
      }
    }
    
    return kLocaleShortDateFormatSwift
  }

  
  // MARK: - Other properties & methods

  
  /**
  Closes the control after the time specified in secondsToClose
  */
  func closeLater() {
    if let lsi = lastSelectedIndex {
      let date = dataSource!.dataPointAtIndex(lsi).date
      delegate?.selectedDate?(date, index:lastSelectedIndex!, control:self)
    }
    
    if closureToCloseControl != nil {
      cancel_delay(closureToCloseControl)
    }
    
    closureToCloseControl = delay(secondsToClose, { () -> () in
      CATransaction.begin()
      CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
      println("Contracting control")
      self.expanded = false
      self.closureToCloseControl = nil
      CATransaction.commit()
    })
  }

  override func prepareForInterfaceBuilder() {
    let twoYearsAgo=NSDate(timeIntervalSinceNow: -2*365*24*60*60)
    let now = NSDate(timeIntervalSinceNow: 0)
    let amount = Int(arc4random_uniform(25))
    var a = Array<NSDate>()
    let diff = now.timeIntervalSinceDate(twoYearsAgo)
    for i in 1...amount {
      let randomNumber = arc4random_uniform(UINT32_MAX)
      let randomTimeInterval = diff * Double(randomNumber) / Double(UINT32_MAX)
      a.append(NSDate(timeInterval: randomTimeInterval, sinceDate: twoYearsAgo))
    }
    a.sort { (d1, d2) -> Bool in
      return d1.compare(d2) == NSComparisonResult.OrderedAscending
    }
    self.dates = a
  }
  
}

internal let kNoDataSourceInconsistency : String = "Must have a data source"
internal let kNoWrongNumberOfLayersInconsistency : String = "Inconsistent number of layers"

