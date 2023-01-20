/*
   Swiss Railway Clock - an analog watchface for Garmin watches

   Copyright (C) 2023 Andreas Huggel <ahuggel@gmx.net>

   Permission is hereby granted, free of charge, to any person obtaining a copy of this software
   and associated documentation files (the "Software"), to deal in the Software without 
   restriction, including without limitation the rights to use, copy, modify, merge, publish, 
   distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the 
   Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all copies or 
   substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING 
   BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
   DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Implements the Swiss Railway Clock watch face
class ClockView extends WatchUi.WatchFace {
    
    enum { M_LIGHT, M_DARK } // Color modes
    enum { C_FOREGROUND, C_BACKGROUND, C_SECONDS, C_TEXT } // Indexes into the color arrays
    private var _colors as Array< Array<Number> > = [
        [Graphics.COLOR_BLACK, Graphics.COLOR_WHITE, Graphics.COLOR_RED, Graphics.COLOR_DK_GRAY],
        [Graphics.COLOR_WHITE, Graphics.COLOR_BLACK, Graphics.COLOR_ORANGE, Graphics.COLOR_LT_GRAY]
    ] as Array< Array<Number> >;

    // List of watchface shapes, used as indexes
    enum { S_BIGTICKMARK, S_SMALLTICKMARK, S_HOURHAND, S_MINUTEHAND, S_SECONDHAND, S_SIZE }
    // A 2 dimensional array for the geometry of the watchface shapes (because the initialisation is more intuitive that way)
    private var _shapes as Array< Array< Float > > = new Array< Array<Float> >[S_SIZE];
    private var _secondCircleRadius as Number; // Radius of the second hand circle
    // A 1 dimensional array for the coordinates, size: S_SIZE (shapes) * 4 (points) * 2 (coordinates)
    private var _coords as Array<Number> = new Array<Number>[S_SIZE * 8];

    private const TWO_PI as Float = 2 * Math.PI;
    
    private var _isAwake as Boolean;
    private var _doPartialUpdates as Boolean;
    private var _hasAlpha as Boolean;
    private var _colorMode as Number;
    private var _screenShape as Number;
    private var _width as Number;
    private var _height as Number;
    private var _screenCenter as Array<Number>;
    private var _clockRadius as Number;
    private var _offscreenBuffer as BufferedBitmap;

    //! Constructor. Initialize the variables for this view.
    public function initialize() {
        WatchFace.initialize();

        _isAwake = true; // Assume we start awake and depend on onEnterSleep() to fall asleep
        _doPartialUpdates = true; // WatchUi.WatchFace has :onPartialUpdate since API Level 2.3.0
        _hasAlpha = Graphics has :createColor;
        _colorMode = M_LIGHT;
        _screenShape = System.getDeviceSettings().screenShape;
        _width = System.getDeviceSettings().screenWidth;
        _height = System.getDeviceSettings().screenHeight;
        _screenCenter = [_width/2, _height/2] as Array<Number>;
        _clockRadius = _screenCenter[0] < _screenCenter[1] ? _screenCenter[0] : _screenCenter[1];

        // Allocate the buffer we use for drawing the watchface, hour and minute hands in low-power mode, 
        // using BufferedBitmap (API Level 2.3.0).
        // This is a full-colored buffer (with no palette), as we have enough memory :) and it makes drawing 
        // text with anti-aliased fonts much more straightforward.
        // Doing this in initialize() rather than onLayout() so _offscreenBuffer does not need to be 
        // nullable, which makes the type checker complain less.
        var bbmo = {:width=>_width, :height=>_height};
        // CIQ 4 devices *need* to use createBufferBitmaps() 
  	    if (Graphics has :createBufferedBitmap) {
    		var bbRef = Graphics.createBufferedBitmap(bbmo);
			_offscreenBuffer = bbRef.get() as BufferedBitmap;
    	} else {
    		_offscreenBuffer = new Graphics.BufferedBitmap(bbmo);
		}

        // Geometry of the hands and tick marks of the clock, as percentages of the diameter of the
        // clock face. Each of these shapes is a polygon (trapezoid), defined by
        // - its height (length),
        // - the width at the tail of the hand or tick mark,
        // - the width at the tip of the hand or tick mark,
        // - the distance from the center of the clock to the tail side (negative for a watch hand 
        //   with a tail).
        // In addition, the second hand has a circle, which is defined separately.
        // See docs/1508_CHD151_foto_b.jpg for the original design. The numbers used here deviate from 
        // that only slightly.
        //                          height, width1, width2, radius
        _shapes[S_BIGTICKMARK]   = [  12.0,    3.5,    3.5,   36.5];	
        _shapes[S_SMALLTICKMARK] = [   3.5,    1.4,    1.4,   45.0];
        _shapes[S_HOURHAND]      = [  44.0,    6.3,    5.1,  -12.0];
        _shapes[S_MINUTEHAND]    = [  57.8,    5.2,    3.7,  -12.0];
        _shapes[S_SECONDHAND]    = [  47.9,    1.4,    1.4,  -16.5];

        // The radius of the second hand circle in pixels, calculated from the percentage of the clock face diameter
        _secondCircleRadius = Math.round(5.1 * _clockRadius / 50.0) as Number;

        // Convert the clock geometry data to pixels
        for (var s = 0; s < S_SIZE; s++) {
            for (var i = 0; i < 4; i++) {
                _shapes[s][i] = Math.round(_shapes[s][i] * _clockRadius / 50.0);
            }
        }

        // Map out the coordinates of all the shapes. Doing that only once to reduce processing time.
        for (var s = 0; s < S_SIZE; s++) {
            var idx = s * 8;
            _coords[idx]     = -(_shapes[s][1] / 2 + 0.5).toNumber();
            _coords[idx + 1] = -(_shapes[s][3] + 0.5).toNumber();
            _coords[idx + 2] = -(_shapes[s][2] / 2 + 0.5).toNumber();
            _coords[idx + 3] = -(_shapes[s][3] + _shapes[s][0] + 0.5).toNumber();
            _coords[idx + 4] =  (_shapes[s][2] / 2 + 0.5).toNumber();
            _coords[idx + 5] = -(_shapes[s][3] + _shapes[s][0] + 0.5).toNumber();
            _coords[idx + 6] =  (_shapes[s][1] / 2 + 0.5).toNumber();
            _coords[idx + 7] = -(_shapes[s][3] + 0.5).toNumber();
        }
    }

    //! Load resources and configure the layout of the watchface for this device
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {
        // If available, enable anti-aliasing for both, the main display and the off-screen buffer 
        if (Toybox.Graphics.Dc has :setAntiAlias) {
            dc.setAntiAlias(true);
            var offscreenDc = _offscreenBuffer.getDc();
            offscreenDc.setAntiAlias(true);
        }
    }

    //! Called when this View is brought to the foreground. Restore the state of this view and
    //! prepare it to be shown. This includes loading resources into memory.
    public function onShow() as Void {
    }

    //! Handle the update event. This function is called
    //! 1) every second when the device is awake,
    //! 2) every full minute in low-power mode, and
    //! 3) it's also triggered when the device goes in or out of low-power mode
    //!    (from onEnterSleep() and onExitSleep()).
    //!
    //! Depending on the power state of the device, we need to be more or less careful regarding
    //! the cost of (mainly) the drawing operations used. The processing logic is as follows.
    //!
    //! When awake: 
    //! onUpdate(): Draw the entire screen every second, directly on the main display.
    //!
    //! In low-power mode:
    //! onUpdate(): Draw the screen into the off-screen buffer and then output the buffer
    //!             to the main display. If partial updates are enabled, also draw the second 
    //!             hand, directly on the main display.
    //! onPartialUpdate(): Use (part of) the off-screen buffer to blank out the second hand and 
    //!             re-draw the second hand at the new position, directly on the main display.
    //!
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        dc.clearClip();
        var targetDc = dc;
        if (!_isAwake) {
            // Only use the buffer in low-power mode
            targetDc = _offscreenBuffer.getDc();
        }
        var clockTime = System.getClockTime();

        // Set the color mode
        switch (settings.getValue("darkMode")) {
            case settings.S_DARK_MODE_SCHEDULED:
                _colorMode = M_LIGHT;
                var time = clockTime.hour * 60 + clockTime.min;
                if (time >= settings.getValue("dmOn") or time < settings.getValue("dmOff")) {
                    _colorMode = M_DARK;
                }
                break;
            case settings.S_DARK_MODE_OFF:
                _colorMode = M_LIGHT;
                break;
            case settings.S_DARK_MODE_ON:
                _colorMode = M_DARK;
                break;
        }
        if (!_isAwake) {
            switch (settings.getValue("lowPower")) {
                case settings.S_LOW_POWER_CARRYOVER:
                    // Use the high-power mode setting
                    break;
                case settings.S_LOW_POWER_DARK:
                    _colorMode = M_DARK;
                    break;
                case settings.S_LOW_POWER_LIGHT:
                    _colorMode = M_LIGHT;
                    break;
                case settings.S_LOW_POWER_INVERT:
                    if (M_DARK == _colorMode) { _colorMode = M_LIGHT; }
                    if (M_LIGHT == _colorMode) { _colorMode = M_DARK; }
                    break;
            }
        }

        // Draw the background
        if (System.SCREEN_SHAPE_ROUND == _screenShape) {
            // Fill the entire background with the background color
            targetDc.setColor(_colors[_colorMode][C_BACKGROUND], _colors[_colorMode][C_BACKGROUND]);
            targetDc.fillRectangle(0, 0, _width, _height);
        } else {
            // Fill the entire background with black and draw a circle with the background color
            targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            targetDc.fillRectangle(0, 0, _width, _height);
            if (_colors[_colorMode][C_BACKGROUND] != Graphics.COLOR_BLACK) {
                targetDc.setColor(_colors[_colorMode][C_BACKGROUND], _colors[_colorMode][C_BACKGROUND]);
                targetDc.fillCircle(_screenCenter[0], _screenCenter[1], _clockRadius);
            }
        }

        // Draw the date string
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        targetDc.setColor(_colors[_colorMode][C_TEXT], Graphics.COLOR_TRANSPARENT);
        switch (settings.getValue("dateDisplay")) {
            case settings.S_DATE_DISPLAY_OFF:
                break;
            case settings.S_DATE_DISPLAY_DAY_ONLY: 
                var dateStr = Lang.format("$1$", [info.day.format("%02d")]);
                targetDc.drawText(_width*0.75, _height/2 - Graphics.getFontHeight(Graphics.FONT_MEDIUM)/2, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
                break;
            case settings.S_DATE_DISPLAY_WEEKDAY_AND_DAY:
                dateStr = Lang.format("$1$ $2$", [info.day_of_week, info.day]);
                targetDc.drawText(_width/2, _height*0.65, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
                break;
        }

        // Draw the battery level indicator
        var batterySetting = settings.getValue("battery");
        if (batterySetting > settings.S_BATTERY_OFF) {
            var battery = System.getSystemStats().battery;
            var radius = Math.round(3.2 * _clockRadius / 50.0) as Number;
            if (battery < 20.0 and batterySetting >= settings.S_BATTERY_ALERT) {
                targetDc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                targetDc.fillCircle(_width/2, _clockRadius/2, radius);
            } else if (battery < 40.0 and batterySetting >= settings.S_BATTERY_WARN) {
                var warnColor = [Graphics.COLOR_ORANGE, Graphics.COLOR_YELLOW] as Array<Number>;
                targetDc.setColor(warnColor[_colorMode], Graphics.COLOR_TRANSPARENT);
                var x = (battery - 20.0) / 20.0;
                targetDc.fillCircle(_width/2-radius*x, _clockRadius/2, radius);
                targetDc.fillCircle(_width/2+radius*x, _clockRadius/2, radius);
            } else if (batterySetting >= settings.S_BATTERY_ON) {
                targetDc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                var x = 1 + (battery - 40.0) / 60.0;
                targetDc.fillCircle(_width/2-radius*x, _clockRadius/2, radius);
                targetDc.fillCircle(_width/2, _clockRadius/2, radius);
                targetDc.fillCircle(_width/2+radius*x, _clockRadius/2, radius);
            }
        }

        // Draw tick marks around the edges of the screen
        targetDc.setColor(_colors[_colorMode][C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i++) {
            targetDc.fillPolygon(rotateCoords(i % 5 ? S_SMALLTICKMARK : S_BIGTICKMARK, i / 60.0 * TWO_PI));
        }

        // Draw the clock hands. All shadows first (it looks better that way), then the actual hands.
        // As we need all the hand coordinates for the shadows, this is now a bit messy.
        var hourHandAngle = ((clockTime.hour % 12) * 60 + clockTime.min) / (12 * 60.0) * TWO_PI;
        var hourHandCoords = rotateCoords(S_HOURHAND, hourHandAngle);
        var minuteHandCoords = rotateCoords(S_MINUTEHAND, clockTime.min / 60.0 * TWO_PI);
        var secondHandCoords = rotateSecondHandCoords(clockTime.sec);

        // Draw shadows on devices which support an alpha channel, when awake and in light color mode
        if (_hasAlpha and _isAwake and M_DARK != _colorMode) {
            var shadowColor = Graphics.createColor(0x80, 0x77, 0x77, 0x77);
            dc.setFill(shadowColor);

            // Draw the hour hand shadow
            var shadow = shadowCoords(hourHandCoords, 7);
            dc.fillPolygon(shadow);

            // Draw the minute hand shadow
            shadow = shadowCoords(minuteHandCoords, 9);
            dc.fillPolygon(shadow);

            // Draw the second hand shadow
            shadow = shadowCoords(secondHandCoords, 10);
            drawSecondHand(dc, shadow);
        }

        // Draw the hour and minute hands
        targetDc.setColor(_colors[_colorMode][C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
        targetDc.fillPolygon(hourHandCoords);
        targetDc.fillPolygon(minuteHandCoords);

        if (!_isAwake) {
            // Output the offscreen buffer to the main display
            dc.drawBitmap(0, 0, _offscreenBuffer);
        }

        if (_isAwake or _doPartialUpdates) {
            setSecondHandClippingRegion(dc, secondHandCoords);
            dc.setColor(_colors[_colorMode][C_SECONDS], Graphics.COLOR_TRANSPARENT);        
            drawSecondHand(dc, secondHandCoords);
        }
    }

    //! Handle the partial update event. This function is called every second when the device is
    //! in low-power mode. See onUpdate() for the full story.
    //! @param dc Device context
    public function onPartialUpdate(dc as Dc) as Void {
        // Output the offscreen buffer to the main display and draw the second hand.
        // Note that this will only affect the clipped region, to delete the second hand.
        dc.drawBitmap(0, 0, _offscreenBuffer);
        var clockTime = System.getClockTime();
        var secondHandCoords = rotateSecondHandCoords(clockTime.sec);
        setSecondHandClippingRegion(dc, secondHandCoords);
        dc.setColor(_colors[_colorMode][C_SECONDS], Graphics.COLOR_TRANSPARENT);
        drawSecondHand(dc, secondHandCoords);
    }

    private function rotateSecondHandCoords(second as Number) as Array< Array<Number> > {
        var angle = second / 60.0 * TWO_PI;
        // Compute the center of the second hand circle, at the tip of the second hand
        var sin = Math.sin(angle);
        var cos = Math.cos(angle);
        var circleCenter = [
            (_screenCenter[0] + (_shapes[S_SECONDHAND][0] + _shapes[S_SECONDHAND][3]) * sin + 0.5).toNumber(),
            (_screenCenter[1] - (_shapes[S_SECONDHAND][0] + _shapes[S_SECONDHAND][3]) * cos + 0.5).toNumber() 
        ] as Array<Number>;
        var coords = rotateCoords(S_SECONDHAND, angle);
        return [ coords[0], coords[1], coords[2], coords[3], circleCenter ] as Array< Array<Number> >;
    }

    // Set the clipping region for the second hand
    private function setSecondHandClippingRegion(dc as Dc, coords as Array< Array<Number> >) as Void {
        // coords[4] is the centre of the second hand circle
        var clipCoords = [
            coords[0], coords[1], coords[2], coords[3],
            [ coords[4][0] - _secondCircleRadius, coords[4][1] - _secondCircleRadius ],
            [ coords[4][0] + _secondCircleRadius, coords[4][1] - _secondCircleRadius ],
            [ coords[4][0] + _secondCircleRadius, coords[4][1] + _secondCircleRadius ],
            [ coords[4][0] - _secondCircleRadius, coords[4][1] + _secondCircleRadius ]
        ] as Array< Array<Number> >;
        var minX = 65536;
        var minY = 65536;
        var maxX = 0;
        var maxY = 0;
        for (var i = 0; i < clipCoords.size(); i++) {
            if (clipCoords[i][0] < minX) { minX = clipCoords[i][0]; }
            if (clipCoords[i][1] < minY) { minY = clipCoords[i][1]; }
            if (clipCoords[i][0] > maxX) { maxX = clipCoords[i][0]; }
            if (clipCoords[i][1] > maxY) { maxY = clipCoords[i][1]; }
        }
        // Add one pixel on each side for good measure
        dc.setClip(minX - 1, minY - 1, maxX + 1 - (minX - 1), maxY + 1 - (minY - 1));
    }

    private function drawSecondHand(dc as Dc, coords as Array< Array<Number> >) as Void {
        // Draw the second hand
        dc.fillPolygon([ coords[0], coords[1], coords[2], coords[3] ] as Array< Array<Number> >);
        dc.fillCircle(coords[4][0], coords[4][1], _secondCircleRadius);
    }

    //! Rotate the four corner coordinates of a polygon used to draw a watch hand or a tick mark.
    //! 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    //! @param shape Index of the shape
    //! @param angle Rotation angle in radians
    //! @return The rotated coordinates of the polygon (watch hand or tick mark)
    private function rotateCoords(shape as Number, angle as Float) as Array< Array<Number> > {
        var sin = Math.sin(angle);
        var cos = Math.cos(angle);
        var shapeIdx = shape * 8;
        var result = new Array< Array<Number> >[4];
        for (var i = 0; i < 4; i++) {
            var idx = shapeIdx + i * 2;
            var x = (_coords[idx] * cos - _coords[idx + 1] * sin + 0.5).toNumber();
            var y = (_coords[idx] * sin + _coords[idx + 1] * cos + 0.5).toNumber();
            result[i] = [_screenCenter[0] + x, _screenCenter[1] + y];
        }
        return result;
    }

    private function shadowCoords(coords as Array< Array<Number> >, len as Number) as Array< Array<Number> > {
        var size = coords.size();
        var result = new Array< Array<Number> >[size];
        // Direction to move points, clockwise from 12 o'clock
        var angle = 3 * Math.PI / 4;
        var dx = Math.sin(angle) * len;
        var dy = -Math.cos(angle) * len;
        for (var i = 0; i < size; i++) {
            result[i] = [coords[i][0] + dx, coords[i][1] + dy];
        }
        return result;
    }

    //! This method is called when the device re-enters sleep mode
    public function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    //! This method is called when the device exits sleep mode
    public function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    //! Indicate if partial updates are on or off (only used with false)
    public function setPartialUpdates(doPartialUpdates as Boolean) as Void {
        _doPartialUpdates = doPartialUpdates;
    }
}

//! Receives watch face events
class ClockDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as ClockView;

    //! Constructor
    //! @param view The analog view
    public function initialize(view as ClockView) {
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

        _view.setPartialUpdates(false);
    }
}

/*
    // DEBUG
    function typeName(obj) {
        if (obj instanceof Toybox.Lang.Number) {
            return "Number";
        } else if (obj instanceof Toybox.Lang.Long) {
            return "Long";
        } else if (obj instanceof Toybox.Lang.Float) {
            return "Float";
        } else if (obj instanceof Toybox.Lang.Double) {
            return "Double";
        } else if (obj instanceof Toybox.Lang.Boolean) {
            return "Boolean";
        } else if (obj instanceof Toybox.Lang.String) {
            return "String";
        } else if (obj instanceof Toybox.Lang.Array) {
            var s = "Array [";
            for (var i = 0; i < obj.size(); ++i) {
                s += typeName(obj);
                s += ", ";
            }
            s += "]";
            return s;
        } else if (obj instanceof Toybox.Lang.Dictionary) {
            var s = "Dictionary{";
            var keys = obj.keys();
            var vals = obj.values();
            for (var i = 0; i < keys.size(); ++i) {
                s += keys;
                s += ": ";
                s += vals;
                s += ", ";
            }
            s += "}";
            return s;
        } else if (obj instanceof Toybox.Time.Gregorian.Info) {
            return "Gregorian.Info";
        } else {
            return "???";
        }
    }
*/
