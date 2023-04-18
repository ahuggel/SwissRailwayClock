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

//! Singleton class for watch face data which needs to be accessible from other classes
class ClockData {
    // Review optimizations in ClockView.drawSecondHand() before changing the following enums or the colors Array.
    enum { M_LIGHT, M_DARK } // Color modes
    enum { C_FOREGROUND, C_BACKGROUND, C_SECONDS, C_TEXT, C_BLUETOOTH } // Indexes into the color arrays

    public var colorMode as Number;
    public var colors as Array< Array<Number> > = [
        [Graphics.COLOR_BLACK, Graphics.COLOR_WHITE, Graphics.COLOR_RED, Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLUE],
        [Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK, Graphics.COLOR_ORANGE, Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_BLUE]
    ] as Array< Array<Number> >;
    public var isAwake as Boolean;
    public var iconFont as FontReference?;
    public var clockRadius as Number;

    public var doNotDisturb as Boolean = false; // deviceSettings.doNotDisturb
    public var alarmCount as Number = 0; // deviceSettings.alarmCount
    public var notificationCount as Number = 0; // deviceSettings.notificationCount
    public var phoneConnected as Boolean = false; // deviceSettings.phoneConnected

    private static var _instance as ClockData?;

    //! Constructor
    public function initialize() {
        colorMode = M_LIGHT;
        isAwake = true; // Assume we start awake and depend on onEnterSleep() to fall asleep
        clockRadius = 0;
        updDeviceSettings();
    }

    public function updDeviceSettings() as Void {
        var deviceSettings = System.getDeviceSettings();
        doNotDisturb = deviceSettings.doNotDisturb;
        alarmCount = deviceSettings.alarmCount;
        notificationCount = deviceSettings.notificationCount;
        phoneConnected = deviceSettings.phoneConnected;
    }

    static function getInstance() as ClockData {
        if (null == _instance) {
            _instance = new ClockData();
        }
        return _instance as ClockData;
    }
} // class ClockData

//! Implements the Swiss Railway Clock watch face
class ClockView extends WatchUi.WatchFace {

    private const TWO_PI as Float = 2 * Math.PI;
    private const SECOND_HAND_TIMER as Number = 30; // Number of seconds in low-power mode, before the second hand disappears

    // List of watchface shapes, used as indexes. Review optimizations in drawSecondHand() before changing the Shape enum.
    enum Shape { S_BIGTICKMARK, S_SMALLTICKMARK, S_HOURHAND, S_MINUTEHAND, S_SECONDHAND, S_SIZE }
    // A 2 dimensional array for the geometry of the watchface shapes - because the initialisation is more intuitive that way
    private var _shapes as Array< Array<Float> > = new Array< Array<Float> >[S_SIZE];
    private var _secondCircleRadius as Number; // Radius of the second hand circle
    private var _secondCircleCenter as Array<Number>; // Center of the second hand circle
    // A 1 dimensional array for the coordinates, size: S_SIZE (shapes) * 4 (points) * 2 (coordinates) - that's supposed to be more efficient
    private var _coords as Array<Number> = new Array<Number>[S_SIZE * 8];

    private var _lastDrawn as Array<Number>;
    private var _doPartialUpdates as Boolean;
    private var _hasAntiAlias as Boolean;
    private var _screenShape as Number;
    private var _width as Number;
    private var _height as Number;
    private var _screenCenter as Array<Number>;
    private var _sleepTimer as Number;
    private var _show3dEffects as Boolean;
    private var _hideSecondHand as Boolean;
    private var _shadowColor as Number;
    private var _offscreenBuffer as BufferedBitmap;
    // Indicators 
    // TODO: Make them Drawables? Or at least derive from some common base class? Group into an array or dictionary?
    private var _batteryLevel as BatteryLevel;
    private var _heartRate as HeartRate;
    private var _simpleIndicators as SimpleIndicators;

    private var _cd as ClockData; // Singleton instance with the public data

    //! Constructor. Initialize the variables for this view.
    public function initialize() {
        WatchFace.initialize();
        _cd = ClockData.getInstance();
        _lastDrawn = [-1, -1, -1] as Array<Number>; // Timestamp when the watch face was last completely re-drawn
        _doPartialUpdates = true; // WatchUi.WatchFace has :onPartialUpdate since API Level 2.3.0
        _hasAntiAlias = (Toybox.Graphics.Dc has :setAntiAlias);
        var deviceSettings = System.getDeviceSettings();
        _screenShape = deviceSettings.screenShape;
        _width = deviceSettings.screenWidth;
        _height = deviceSettings.screenHeight;
        _screenCenter = [_width/2, _height/2] as Array<Number>;
        _cd.clockRadius = _screenCenter[0] < _screenCenter[1] ? _screenCenter[0] : _screenCenter[1];
        _sleepTimer = SECOND_HAND_TIMER; // Counter for the time in low-power mode, before the second hand disappears
        _show3dEffects = false;
        _hideSecondHand = false;
        _shadowColor = 0;
        if ($.config.hasAlpha()) { _shadowColor = Graphics.createColor(0x80, 0x77, 0x77, 0x77); }
        // Indicators
        _batteryLevel = new BatteryLevel();
        _heartRate = new HeartRate();
        _simpleIndicators = new SimpleIndicators();

        // Allocate the buffer we use for drawing the watchface, using BufferedBitmap (API Level 2.3.0).
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

        // Convert the clock geometry data to pixels
        for (var s = 0; s < S_SIZE; s++) {
            for (var i = 0; i < 4; i++) {
                _shapes[s][i] = Math.round(_shapes[s][i] * _cd.clockRadius / 50.0);
            }
        }

        // Map out the coordinates of all the shapes. Doing that only once reduces processing time.
        for (var s = 0; s < S_SIZE; s++) {
            var idx = s * 8;
            _coords[idx]   = -(_shapes[s][1] / 2 + 0.5).toNumber();
            _coords[idx+1] = -(_shapes[s][3] + 0.5).toNumber();
            _coords[idx+2] = -(_shapes[s][2] / 2 + 0.5).toNumber();
            _coords[idx+3] = -(_shapes[s][3] + _shapes[s][0] + 0.5).toNumber();
            _coords[idx+4] =  (_shapes[s][2] / 2 + 0.5).toNumber();
            _coords[idx+5] = -(_shapes[s][3] + _shapes[s][0] + 0.5).toNumber();
            _coords[idx+6] =  (_shapes[s][1] / 2 + 0.5).toNumber();
            _coords[idx+7] = -(_shapes[s][3] + 0.5).toNumber();
        }

        // The radius of the second hand circle in pixels, calculated from the percentage of the clock face diameter
        _secondCircleRadius = ((5.1 * _cd.clockRadius / 50.0) + 0.5).toNumber();
        _secondCircleCenter = [ 0, _coords[S_SECONDHAND * 8 + 3]] as Array<Number>;
        // Shorten the second hand from the circle center to the edge of the circle to avoid a dark shadow
        _coords[S_SECONDHAND * 8 + 3] += _secondCircleRadius - 1;
        _coords[S_SECONDHAND * 8 + 5] += _secondCircleRadius - 1;
    }

    //! Load resources and configure the layout of the watchface for this device
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {
        _cd.iconFont = WatchUi.loadResource(Rez.Fonts.Icons) as FontReference;
    }

    //! Called when this View is brought to the foreground. Restore the state of this view and
    //! prepare it to be shown. This includes loading resources into memory.
    public function onShow() as Void {
        // Assuming onShow() is triggered after any device settings change, force the watch face
        // to be re-drawn in the next call to onUpdate(). This is to immediately react to a
        // possible change of the DND setting.
        _lastDrawn[1] = -1;
    }

    //! Handle the update event. This function is called
    //! 1) every second when the device is awake,
    //! 2) every full minute in low-power mode, and
    //! 3) it's also triggered when the device goes in or out of low-power mode
    //!    (from onEnterSleep() and onExitSleep()).
    //!
    //! In low-power mode, onPartialUpdate() is called every second, except on the full minute,
    //! and the system enforces a power budget, which the code must not exceed.
    //!
    //! The processing logic is as follows:
    //! Draw the screen into the off-screen buffer and then output the buffer to the main display.
    //! Finally, the second hand is drawn directly on the screen. If supported, use anti-aliasing.
    //! The off-screen buffer is later, in onPartialUpdate(), used to blank out the second hand,
    //! before it is re-drawn at the new position, directly on the main display.
    //!
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        dc.clearClip();

        // Always use the offscreen buffer, not only in low-power mode. That simplifies the logic and is more robust.
        var targetDc = _offscreenBuffer.getDc();
        if (_hasAntiAlias) {
            dc.setAntiAlias(true);
            targetDc.setAntiAlias(true); 
        }

        // Update the low-power mode timer
        if (_cd.isAwake) { 
            _sleepTimer = SECOND_HAND_TIMER; // Reset the timer
        } else if (_sleepTimer > 0) {
            _sleepTimer--;
        }

        var clockTime = System.getClockTime();

        // Only re-draw the entire watch face from scratch when required, else use the offscreen buffer
        var redraw = true;
        // Don't re-draw if the minute hasn't changed since the last time..
        if (_cd.isAwake and _lastDrawn[1] == clockTime.min and _lastDrawn[0] == clockTime.hour) { 
            redraw = false;
            // ..unless the settings menu has been accessed in the meantime
            var lastAccessed = $.config.lastAccessed();
            if (  lastAccessed[2] + lastAccessed[1]*60 + lastAccessed[0]*3600 
                > _lastDrawn[2] + _lastDrawn[1]*60 + _lastDrawn[0]*3600) { redraw = true; }
        }
        /* DEBUG
        var lastAccessed = $.config.lastAccessed();
        System.println("_lastDrawn = " + _lastDrawn[0].format("%02d") + ":" + _lastDrawn[1].format("%02d") + ":" + _lastDrawn[2].format("%02d") + " " +
                       "lastAccessed = " + lastAccessed[0].format("%02d") + ":" + lastAccessed[1].format("%02d") + ":" + lastAccessed[2].format("%02d") + " " +
                       "redraw = " + redraw);
        //*/
        if (redraw) {
            _lastDrawn = [clockTime.hour, clockTime.min, clockTime.sec] as Array<Number>;
            _cd.updDeviceSettings();

            // Set the color mode
            switch ($.config.getValue($.Config.I_DARK_MODE)) {
                case $.Config.O_DARK_MODE_SCHEDULED:
                    _cd.colorMode = ClockData.M_LIGHT;
                    var time = clockTime.hour * 60 + clockTime.min;
                    if (time >= $.config.getValue($.Config.I_DM_ON) or time < $.config.getValue($.Config.I_DM_OFF)) {
                        _cd.colorMode = ClockData.M_DARK;
                    }
                    break;
                case $.Config.O_DARK_MODE_OFF:
                    _cd.colorMode = ClockData.M_LIGHT;
                    break;
                case $.Config.O_DARK_MODE_ON:
                    _cd.colorMode = ClockData.M_DARK;
                    break;
                case $.Config.O_DARK_MODE_IN_DND:
                    _cd.colorMode = _cd.doNotDisturb ? ClockData.M_DARK : ClockData.M_LIGHT;
                    break;
            }

            // In dark mode, adjust colors based on the contrast setting
            if (ClockData.M_DARK == _cd.colorMode) {
                var foregroundColor = $.config.getValue($.Config.I_DM_CONTRAST);
                _cd.colors[ClockData.M_DARK][ClockData.C_FOREGROUND] = foregroundColor;
                switch (foregroundColor) {
                    case Graphics.COLOR_WHITE:
                        _cd.colors[ClockData.M_DARK][ClockData.C_TEXT] = Graphics.COLOR_LT_GRAY;
                        _cd.colors[ClockData.M_DARK][ClockData.C_BLUETOOTH] = Graphics.COLOR_DK_BLUE;
                        break;
                    case Graphics.COLOR_LT_GRAY:
                        _cd.colors[ClockData.M_DARK][ClockData.C_TEXT] = Graphics.COLOR_DK_GRAY;
                        _cd.colors[ClockData.M_DARK][ClockData.C_BLUETOOTH] = Graphics.COLOR_DK_BLUE;
                        break;
                    case Graphics.COLOR_DK_GRAY:
                        _cd.colors[ClockData.M_DARK][ClockData.C_TEXT] = Graphics.COLOR_DK_GRAY;
                        _cd.colors[ClockData.M_DARK][ClockData.C_BLUETOOTH] = Graphics.COLOR_BLUE;
                        break;
                }
            }

            // Note: Whether 3D effects are supported by the device is also ensured by getValue().
            _show3dEffects = $.Config.O_3D_EFFECTS_ON == $.config.getValue($.Config.I_3D_EFFECTS) and ClockData.M_LIGHT == _cd.colorMode;

            // Handle the setting to disable the second hand in sleep mode after some time
            var secondsOption = $.config.getValue($.Config.I_HIDE_SECONDS);
            _hideSecondHand = $.Config.O_HIDE_SECONDS_ALWAYS == secondsOption 
                or ($.Config.O_HIDE_SECONDS_IN_DM == secondsOption and ClockData.M_DARK == _cd.colorMode);

            // Draw the background
            if (System.SCREEN_SHAPE_ROUND == _screenShape) {
                // Fill the entire background with the background color
                targetDc.setColor(_cd.colors[_cd.colorMode][ClockData.C_BACKGROUND], _cd.colors[_cd.colorMode][ClockData.C_BACKGROUND]);
                targetDc.clear();
            } else {
                // Fill the entire background with black and draw a circle with the background color
                targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                targetDc.clear();
                if (_cd.colors[_cd.colorMode][ClockData.C_BACKGROUND] != Graphics.COLOR_BLACK) {
                    targetDc.setColor(_cd.colors[_cd.colorMode][ClockData.C_BACKGROUND], _cd.colors[_cd.colorMode][ClockData.C_BACKGROUND]);
                    targetDc.fillCircle(_screenCenter[0], _screenCenter[1], _cd.clockRadius);
                }
            }

            // Draw tick marks around the edge of the screen
            targetDc.setColor(_cd.colors[_cd.colorMode][ClockData.C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 60; i++) {
                targetDc.fillPolygon(rotateCoords(i % 5 ? S_SMALLTICKMARK : S_BIGTICKMARK, i / 60.0 * TWO_PI));
            }

            // Draw the date string
            var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
            var dateDisplay = $.config.getValue($.Config.I_DATE_DISPLAY);
            targetDc.setColor(_cd.colors[_cd.colorMode][ClockData.C_TEXT], Graphics.COLOR_TRANSPARENT);
            switch (dateDisplay) {
                case $.Config.O_DATE_DISPLAY_DAY_ONLY: 
                    var dateStr = info.day.format("%02d");
                    targetDc.drawText(_width*0.75, _height/2 - Graphics.getFontHeight(Graphics.FONT_MEDIUM)/2 - 1, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
                    break;
                case $.Config.O_DATE_DISPLAY_WEEKDAY_AND_DAY:
                    dateStr = Lang.format("$1$ $2$", [info.day_of_week, info.day]);
                    targetDc.drawText(_width/2, _height*0.65, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
                    break;
            }

            var symbolsDrawn = false;
            // Draw alarm, notification and phone connection indicators
            if ($.Config.O_ALARMS_ON == $.config.getValue($.Config.I_ALARMS)
                or $.Config.O_NOTIFICATIONS_ON == $.config.getValue($.Config.I_NOTIFICATIONS)) {
                var xpos = _width/2;
                var ypos = _height * 0.18;
                symbolsDrawn = _simpleIndicators.drawSymbols(targetDc, xpos as Number, ypos as Number);
            }
            if ($.Config.O_CONNECTED_ON == $.config.getValue($.Config.I_CONNECTED)) {
                var xpos = _width/2;
                var ypos = _height/2 + _shapes[S_BIGTICKMARK][3] + (_shapes[S_BIGTICKMARK][0] - Graphics.getFontHeight(_cd.iconFont as FontReference))/3;
                _simpleIndicators.drawPhoneConnected(targetDc, xpos as Number, ypos as Number);
            }

            // Draw the battery level indicator
            if ($.config.getValue($.Config.I_BATTERY) > $.Config.O_BATTERY_OFF) {
                var xpos = _width/2;
                var ypos = symbolsDrawn ? _cd.clockRadius * 0.64 : _cd.clockRadius * 0.5;
                _batteryLevel.draw(targetDc, xpos as Number, ypos as Number);
            }

            // Draw the heart rate indicator at the spot which is not occupied by the date display,
            // by default on the right side
            if ($.Config.O_HEART_RATE_ON == $.config.getValue($.Config.I_HEART_RATE)) {
                var xpos = _width * 0.73;
                var ypos = _height/2 - 1;
                if ($.Config.O_DATE_DISPLAY_DAY_ONLY == dateDisplay) {
                    xpos = _width * 0.48;
                    ypos = _height * 0.75;
                }
                _heartRate.draw(targetDc, xpos as Number, ypos as Number);
            }

            // Draw the hour and minute hands. Shadows first, then the actual hands.
            var hourHandAngle = ((clockTime.hour % 12) * 60 + clockTime.min) / (12 * 60.0) * TWO_PI;
            var hourHandCoords = rotateCoords(S_HOURHAND, hourHandAngle);
            var minuteHandCoords = rotateCoords(S_MINUTEHAND, clockTime.min / 60.0 * TWO_PI);
            if (_cd.isAwake and _show3dEffects) {
                targetDc.setFill(_shadowColor);
                targetDc.fillPolygon(shadowCoords(hourHandCoords, 7));
                targetDc.fillPolygon(shadowCoords(minuteHandCoords, 9));
            }
            targetDc.setColor(_cd.colors[_cd.colorMode][ClockData.C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
            targetDc.fillPolygon(hourHandCoords);
            targetDc.fillPolygon(minuteHandCoords);
        } // if (redraw)

        // Output the offscreen buffer to the main display
        dc.drawBitmap(0, 0, _offscreenBuffer);

        // Draw the second hand and shadow, directly on the screen
        var doIt = true;
        if (!_cd.isAwake) {
            if (!_doPartialUpdates) { doIt = false; }
            else if (_hideSecondHand and 0 == _sleepTimer) { doIt = false; }
        }
        if (doIt) { 
            drawSecondHand(dc, clockTime.sec); 
        }
    }

    //! Handle the partial update event. This function is called every second when the device is
    //! in low-power mode. See onUpdate() for the full story.
    //! @param dc Device context
    public function onPartialUpdate(dc as Dc) as Void {
        _cd.isAwake = false; // To state the obvious. Workaround for an Enduro 2 firmware bug.
        if (_sleepTimer > 0) { 
            _sleepTimer--; 
            if (0 == _sleepTimer and _hideSecondHand) {
                // Delete the second hand for the last time
                dc.drawBitmap(0, 0, _offscreenBuffer);
            }
        }
        if (_sleepTimer > 0 or !_hideSecondHand) {
            if (_hasAntiAlias) { dc.setAntiAlias(true); }
            var clockTime = System.getClockTime();
            // Delete the second hand. Note that this will only affect the clipped region
            dc.drawBitmap(0, 0, _offscreenBuffer);
            drawSecondHand(dc, clockTime.sec);
        }
    }

    //! This method is called when the device re-enters sleep mode
    public function onEnterSleep() as Void {
        _cd.isAwake = false;
        WatchUi.requestUpdate();
    }

    //! This method is called when the device exits sleep mode
    public function onExitSleep() as Void {
        _cd.isAwake = true;
        _lastDrawn[1] = -1; // A bit of a hack to force the watch face to be re-drawn
        WatchUi.requestUpdate();
    }

    public function stopPartialUpdates() as Void {
        _doPartialUpdates = false;
    }

    // Draw the second hand for the given second, including a shadow, if required, and set the clipping region.
    // This function is performance critical (when !isAwake) and has been optimized.
    private function drawSecondHand(dc as Dc, second as Number) as Void {
        // Interestingly, lookup tables for the angle or sin/cos don't make this any faster.
        var angle = second * 0.104719758; // TWO_PI / 60.0
        var sin = Math.sin(angle);
        var cos = Math.cos(angle);
        var offsetX = _screenCenter[0] + 0.5;
		var offsetY = _screenCenter[1] + 0.5;

        // Rotate the center of the second hand circle
        var x = (_secondCircleCenter[0] * cos - _secondCircleCenter[1] * sin + offsetX).toNumber();
        var y = (_secondCircleCenter[0] * sin + _secondCircleCenter[1] * cos + offsetY).toNumber();

        // Rotate the rectangular portion of the second hand, using inlined code from rotateCoords() to improve performance
        // Optimized: idx = S_SECONDHAND * 8; idy = idx + 1; and etc.
        var x0 = (_coords[32] * cos - _coords[33] * sin + offsetX).toNumber();
        var y0 = (_coords[32] * sin + _coords[33] * cos + offsetY).toNumber();
        var x1 = (_coords[34] * cos - _coords[35] * sin + offsetX).toNumber();
        var y1 = (_coords[34] * sin + _coords[35] * cos + offsetY).toNumber();
        var x2 = (_coords[36] * cos - _coords[37] * sin + offsetX).toNumber();
        var y2 = (_coords[36] * sin + _coords[37] * cos + offsetY).toNumber();
        var x3 = (_coords[38] * cos - _coords[39] * sin + offsetX).toNumber();
        var y3 = (_coords[38] * sin + _coords[39] * cos + offsetY).toNumber();
        var coords = [[x0, y0], [x1, y1], [x2, y2], [x3, y3]] as Array< Array<Number> >;

        // Draw the shadow, if required
        if (_cd.isAwake and _show3dEffects) {
            dc.setFill(_shadowColor);
            dc.fillPolygon(shadowCoords(coords, 10));
            var shadowCenter = shadowCoords([[x, y]] as Array< Array<Number> >, 10);
            dc.fillCircle(shadowCenter[0][0], shadowCenter[0][1], _secondCircleRadius);
        }

        // Set the clipping region
        var xx1 = x - _secondCircleRadius;
        var yy1 = y - _secondCircleRadius;
        var xx2 = x + _secondCircleRadius;
        var yy2 = y + _secondCircleRadius;
        var minX = 65536;
        var minY = 65536;
        var maxX = 0;
        var maxY = 0;
        // coords[1], coords[2] optimized out: only consider the tail and circle coords, loop unrolled for performance,
        // use only points [x0, y0], [x3, y3], [xx1, yy1], [xx2, yy1], [xx2, yy2], [xx1, yy2], minus duplicate comparisons
        if (x0 < minX) { minX = x0; }
        if (y0 < minY) { minY = y0; }
        if (x0 > maxX) { maxX = x0; }
        if (y0 > maxY) { maxY = y0; }
        if (x3 < minX) { minX = x3; }
        if (y3 < minY) { minY = y3; }
        if (x3 > maxX) { maxX = x3; }
        if (y3 > maxY) { maxY = y3; }
        if (xx1 < minX) { minX = xx1; }
        if (yy1 < minY) { minY = yy1; }
        if (xx1 > maxX) { maxX = xx1; }
        if (yy1 > maxY) { maxY = yy1; }
        if (xx2 < minX) { minX = xx2; }
        if (yy2 < minY) { minY = yy2; }
        if (xx2 > maxX) { maxX = xx2; }
        if (yy2 > maxY) { maxY = yy2; }
        // Add two pixels on each side for good measure
        dc.setClip(minX - 2, minY - 2, maxX - minX + 4, maxY - minY + 4);

        // Finally, draw the second hand
        dc.setColor(_cd.colorMode ? Graphics.COLOR_ORANGE : Graphics.COLOR_RED /* colors[colorMode][C_SECONDS] */, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(coords);
        dc.fillCircle(x, y, _secondCircleRadius);
    }

    //! Rotate the four corner coordinates of a polygon used to draw a watch hand or a tick mark.
    //! 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    //! @param shape Index of the shape
    //! @param angle Rotation angle in radians
    //! @return The rotated coordinates of the polygon (watch hand or tick mark)
    private function rotateCoords(shape as Shape, angle as Float) as Array< Array<Number> > {
        var sin = Math.sin(angle);
        var cos = Math.cos(angle);
        // Optimized: Expanded the loop and avoid repeating the same operations (Thanks Inigo Tolosa for the tip!)
        var offsetX = _screenCenter[0] + 0.5;
		var offsetY = _screenCenter[1] + 0.5;
        var idx = shape * 8;
        var idy = idx + 1;
        var x0 = (_coords[idx] * cos - _coords[idy] * sin + offsetX).toNumber();
        var y0 = (_coords[idx] * sin + _coords[idy] * cos + offsetY).toNumber();
        idx = idy + 1;
        idy += 2;
        var x1 = (_coords[idx] * cos - _coords[idy] * sin + offsetX).toNumber();
        var y1 = (_coords[idx] * sin + _coords[idy] * cos + offsetY).toNumber();
        idx = idy + 1;
        idy += 2;
        var x2 = (_coords[idx] * cos - _coords[idy] * sin + offsetX).toNumber();
        var y2 = (_coords[idx] * sin + _coords[idy] * cos + offsetY).toNumber();
        idx = idy + 1;
        idy += 2;
        var x3 = (_coords[idx] * cos - _coords[idy] * sin + offsetX).toNumber();
        var y3 = (_coords[idx] * sin + _coords[idy] * cos + offsetY).toNumber();

        return [[x0, y0], [x1, y1], [x2, y2], [x3, y3]] as Array< Array<Number> >;
    }

    // TODO: move the shadow shapes by a percentage instead of a number of pixels
    private function shadowCoords(coords as Array< Array<Number> >, len as Number) as Array< Array<Number> > {
        var size = coords.size();
        var result = new Array< Array<Number> >[size];
        // Direction to move points, clockwise from 12 o'clock
        var angle = 3 * Math.PI / 4;
        var dx = (Math.sin(angle) * len + 0.5).toNumber();
        var dy = (-Math.cos(angle) * len + 0.5).toNumber();
        for (var i = 0; i < size; i++) {
            result[i] = [coords[i][0] + dx, coords[i][1] + dy];
        }
        return result;
    }
} // class ClockView

//! Receives watch face events
class ClockDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as ClockView;

    //! Constructor
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

        _view.stopPartialUpdates();
    }
}

/*
    // DEBUG
    (:typecheck(false))
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
//*/