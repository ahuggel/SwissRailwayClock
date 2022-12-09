// Copyright 2022 by Andreas Huggel
// 
// Based on the Garmin Analog sample program, which is
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! This implements an analog watch face
//! Original design by Austen Harbour
class AnalogView extends WatchUi.WatchFace {
    private var _isAwake as Boolean?; // TODO: NEEDS INITIALIZATION BUT HOW
    private var _offscreenBuffer as BufferedBitmap?;
    private var _screenCenterPoint as Array<Number>?;
    private var _clockRadius as Float = 0.0;

    // Geometry of the clock, relative to the radius of the clock face.
    //                                            height, width1, width2, radius, circle
    private var _bigTickMark as Array<Float>   = [0.2408, 0.0733, 0.0733,  0.6963];	
    private var _smallTickMark as Array<Float> = [0.0733, 0.0262, 0.0262,  0.8639];	
    private var _hourHand as Array<Float>      = [0.8482, 0.1257, 0.0995, -0.2304];	
    private var _minuteHand as Array<Float>    = [1.1257, 0.1047, 0.0733, -0.2356];	
    private var _secondHand as Array<Float>    = [0.9319, 0.0314, 0.0314, -0.3246, 0.1047];

    //! Initialize variables for this view
    public function initialize() {
        WatchFace.initialize();
    }

    //! Load resources and configure the layout of the watchface for this device
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {

        System.println("onLayout"); // DEBUG

        var width = dc.getWidth();
        var height = dc.getHeight();

        _screenCenterPoint = [width / 2, height / 2] as Array<Number>;
        _clockRadius = _screenCenterPoint[0] < _screenCenterPoint[1] ? _screenCenterPoint[0] : _screenCenterPoint[1] as Float;

        // Convert the clock geometry data to pixels
        for (var i = 0; i < 4; i++) {
            _bigTickMark[i]   = ( Math.round(_bigTickMark[i] * _clockRadius) );
            _smallTickMark[i] = Math.round(_smallTickMark[i] * _clockRadius) as Float;
            _hourHand[i]      = Math.round(_hourHand[i] * _clockRadius) as Float;
            _minuteHand[i]    = Math.round(_minuteHand[i] * _clockRadius) as Float;
            _secondHand[i]    = Math.round(_secondHand[i] * _clockRadius) as Float;
        }
        _secondHand[4] = Math.round(_secondHand[4] as Float * _clockRadius) as Float;

        // If this device supports BufferedBitmap, allocate the buffers we use for drawing
        // Allocate a full screen size buffer with a palette of only 4 colors to draw
        // the background image of the watchface.  This is used to facilitate blanking
        // the second hand during partial updates of the display
        _offscreenBuffer = null;
        if (Graphics has :BufferedBitmap) {
            var bbmo = {
                :width=>width,
	            :height=>height,
	            :palette=>[
                    Graphics.COLOR_BLACK,
                    Graphics.COLOR_WHITE,
                    Graphics.COLOR_LT_GRAY,
                    Graphics.COLOR_DK_GRAY
                ]
            };
            // CIQ 4 devices *need* to use createBufferBitmaps() 
  	        if (Graphics has :createBufferedBitmap) {
    			var bbRef = Graphics.createBufferedBitmap(bbmo);
    			_offscreenBuffer = bbRef.get();
    		} else {
    			_offscreenBuffer = new Graphics.BufferedBitmap(bbmo);
			}
        }
    }

    //! Handle the update event
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {

        System.println("onUpdate"); // DEBUG

        var targetDc = dc;
        if (null != _offscreenBuffer) {
            // If we have an offscreen buffer that we are using to draw the background,
            // set the draw context of that buffer as our target.
            targetDc = _offscreenBuffer.getDc();
            dc.clearClip();
        }
        var width = targetDc.getWidth();
        var height = targetDc.getHeight();

        // Fill the entire background with black and draw a white circle in the center
        targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        targetDc.fillRectangle(0, 0, width, height);
        targetDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        targetDc.fillCircle(_screenCenterPoint[0], _screenCenterPoint[1], _clockRadius);

        // Draw tick marks around the edges of the screen
        targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i++) {
            targetDc.fillPolygon(generatePolygonCoords(i % 5 ? _smallTickMark : _bigTickMark, i / 60.0 * 2 * Math.PI));
        }

        var clockTime = System.getClockTime();

        // Draw the hour hand. Convert it to minutes and compute the angle.
        var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min) / (12 * 60.0) * 2 * Math.PI;
        targetDc.fillPolygon(generatePolygonCoords(_hourHand, hourHandAngle));

        // Draw the minute hand.
        targetDc.fillPolygon(generatePolygonCoords(_minuteHand, clockTime.min / 60.0 * 2 * Math.PI));

        // Output the offscreen buffer to the main display if required.
        if (null != _offscreenBuffer) {
            dc.drawBitmap(0, 0, _offscreenBuffer);
        }

        // Draw the second hand directly in the full update method.
        var secondAngle = clockTime.sec / 60.0 * 2 * Math.PI;
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(generatePolygonCoords(_secondHand, secondAngle));
        var secondCircleCenter = [
                (_screenCenterPoint[0] + (_secondHand[0] + _secondHand[3]) * Math.sin(secondAngle) + 0.5) as Number,
                (_screenCenterPoint[1] - (_secondHand[0] + _secondHand[3]) * Math.cos(secondAngle) + 0.5) as Number 
            ];
        dc.fillCircle(secondCircleCenter[0], secondCircleCenter[1], _secondHand[4]);

        // TODO: SET CLIP? Maybe not. Then, when onPartialUpdate is called for the first time, it will install the entire bg?
    }

    //! Handle the partial update event
    //! @param dc Device context
    public function onPartialUpdate(dc as Dc) as Void {

        System.println("onPartialUpdate"); // DEBUG

        // If we have an offscreen buffer, output it to the main display.
        // Note that this will only affect the clipped region, if there is one, to delete the second hand
        if (null != _offscreenBuffer) {
            dc.drawBitmap(0, 0, _offscreenBuffer);
        }
        // TODO: ELSE WHAT? I.E. IF THIS DEVICE DOES NOT HAVE BUFFERS, THEN WHAT?

        var clockTime = System.getClockTime();

        // Draw the second hand to the screen.
        var secondAngle = clockTime.sec / 60.0 * 2 * Math.PI;
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(generatePolygonCoords(_secondHand, secondAngle));
        var secondCircleCenter = [
                (_screenCenterPoint[0] + (_secondHand[0] + _secondHand[3]) * Math.sin(secondAngle) + 0.5) as Number,
                (_screenCenterPoint[1] - (_secondHand[0] + _secondHand[3]) * Math.cos(secondAngle) + 0.5) as Number 
            ];
        dc.fillCircle(secondCircleCenter[0], secondCircleCenter[1], _secondHand[4]);

        // Update the clipping rectangle to the new location of the second hand.
        var boundingBox = [_secondHand[0] + _secondHand[4], 3 * _secondHand[4], 3 * _secondHand[4], _secondHand[3]];
        var boundingBoxPoints = generatePolygonCoords(boundingBox, secondAngle);
        var minX = 65536;
        var minY = 65536;
        var maxX = 0;
        var maxY = 0;
        for (var i = 0; i < 4; i++) {
            if (boundingBoxPoints[i][0] < minX) {
                minX = boundingBoxPoints[i][0];
            }
            if (boundingBoxPoints[i][1] < minY) {
                minY = boundingBoxPoints[i][1];
            }
            if (boundingBoxPoints[i][0] > maxX) {
                maxX = boundingBoxPoints[i][0];
            }
            if (boundingBoxPoints[i][1] > maxY) {
                maxY = boundingBoxPoints[i][1];
            }
        }
        // Add one pixel on each side for good measure
        dc.setClip(minX - 1, minY - 1, maxX + 1 - (minX - 1), maxY + 1 - (minY - 1));
    }

    //! This function is used to generate the screen coordinates of the four corners of a polygon (trapezoid),
    //! used to draw a watch hand or a tick mark. The coordinates are generated using a specified height,
    //! and two separate widths, and are rotated around the center point at the provided angle.
    //! 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    //! @param shape Definition of the polygon (in pixels) as follows
    //!        shape[0] The height of the polygon
    //!        shape[1] Width of the polygon at the tail of the hand or tick mark
    //!        shape[2] Width of the polygon at the tip of the hand or tick mark
    //!        shape[3] Distance from the center of the watch to the tail side (negative for a watch hand with a tail) of the polygon
    //! @param angle Angle of the hand in radians
    //! @return The coordinates of the polygon (watch hand or tick mark)
    private function generatePolygonCoords(shape as Array<Numeric>, angle as Float) as Array< Array<Number> > {
        // Map out the coordinates of the polygon (trapezoid)
        var coords = [[-(shape[1] / 2), -shape[3]] as Array<Number>,
                      [-(shape[2] / 2), -(shape[3] + shape[0])] as Array<Number>,
                      [shape[2] / 2, -(shape[3] + shape[0])] as Array<Number>,
                      [shape[1] / 2, -shape[3]] as Array<Number>] as Array< Array<Number> >;

        // Rotate the coordinates
        var result = new Array< Array<Number> >[4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        for (var i = 0; i < 4; i++) {
            var x = (coords[i][0] * cos - coords[i][1] * sin + 0.5) as Number;
            var y = (coords[i][0] * sin + coords[i][1] * cos + 0.5) as Number;

            result[i] = [_screenCenterPoint[0] + x, _screenCenterPoint[1] + y];
        }

        return result;
    }

    //! This method is called when the device re-enters sleep mode.
    //! Set the isAwake flag to let onUpdate know it should stop rendering the second hand.
    public function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    //! This method is called when the device exits sleep mode.
    //! Set the isAwake flag to let onUpdate know it should render the second hand.
    public function onExitSleep() as Void {
        _isAwake = true;
    }

}

//! Receives watch face events
class AnalogDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as AnalogView;

    //! Constructor
    //! @param view The analog view
    public function initialize(view as AnalogView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! The onPowerBudgetExceeded callback is called by the system if the
    //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
    //! the system will stop invoking onPartialUpdate each second, so we notify the
    //! view here to let the rendering methods know they should not be rendering a
    //! second hand.
    //! @param powerInfo Information about the power budget
    public function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        System.println("Average execution time: " + powerInfo.executionTimeAverage);
        System.println("Allowed execution time: " + powerInfo.executionTimeLimit);
        // TODO: TURN OFF SECONDS
    }
}
