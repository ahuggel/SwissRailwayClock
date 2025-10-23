/*
   Swiss Railway Clock - an analog watchface for Garmin watches

   Copyright (C) 2023-2025 Andreas Huggel <ahuggel@gmx.net>

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
import Toybox.WatchUi;

// Global variable for the icon font. Initialized in ClockView.onLayout().
var iconFont as FontResource?;

// Implements the Swiss Railway Clock watch face for watches with an AMOLED display.
class ClockView extends WatchUi.WatchFace {
    private var _isAwake as Boolean = true; // Assume we start awake and depend on onEnterSleep() to fall asleep
    private var _doWireHands as Number = 0; // Number of seconds to show the minute and hour hands as wire hands after press

    private var _screenCenter as Array<Number>;
    private var _clockRadius as Number;

    private var _indicators as Indicators;

    // Constructor. Initialize the variables for this view.
    public function initialize() {
        WatchFace.initialize();

        var deviceSettings = System.getDeviceSettings();
        var width = deviceSettings.screenWidth;
        var height = deviceSettings.screenHeight;
        _screenCenter = [width/2, height/2] as Array<Number>;
        _clockRadius = _screenCenter[0] < _screenCenter[1] ? _screenCenter[0] : _screenCenter[1];

        _indicators = new Indicators(width, height, _screenCenter, _clockRadius);
    }

    // Load resources and configure the layout of the watchface for this device
    public function onLayout(dc as Dc) as Void {
        // Load the custom font with the symbols
        if (Graphics has :FontReference) {
            var fontRef = WatchUi.loadResource(Rez.Fonts.Icons) as FontReference;
            iconFont = fontRef.get() as FontResource;
        } else {
            iconFont = WatchUi.loadResource(Rez.Fonts.Icons) as FontResource;
        }
        // Update any indicator positions, which depend on the watchface shapes
        _indicators.updatePos();
    }

    // This method is called when the device re-enters sleep mode
    public function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    // This method is called when the device exits sleep mode
    public function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    public function startWireHands() as Void {
        _doWireHands = 6;
        WatchUi.requestUpdate();
    }

    // Handle the update event. This function is called
    // 1) every second when the device is awake,
    // 2) every full minute in always-on (low-power) mode, and
    // 3) it's also triggered when the device goes in or out of low-power mode
    //    (from onEnterSleep() and onExitSleep()).
    //
    // This version is kept simple. It always draws the watch face from scratch,
    // directly on the display. Amoled watches do not support updates every second
    // in always-on mode, so this is all that's required.
    // Using a buffered bitmap or layers would only serve to try to be more energy
    // efficient during a prolonged use in high-power mode.
    public function onUpdate(dc as Dc) as Void {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour; // Using local variables for these saves a bit of memory
        var minute = clockTime.min;
        var second = clockTime.sec;
        var deviceSettings = System.getDeviceSettings();

        // Determine all colors based on the relevant settings
        var colorMode = config.setColors(_isAwake, deviceSettings.doNotDisturb, hour, minute);

        // Initialise the dc and fill the entire background with the background color (black)
        dc.clearClip(); // Still needed as the settings menu messes with the clip
        dc.setAntiAlias(true); // Graphics.Dc has :setAntiAlias since API Level 3.2.0
        dc.setColor(config.colors[Config.C_BACKGROUND], config.colors[Config.C_BACKGROUND]);
        dc.clear();

        // Draw tick marks around the edge of the screen
        dc.setColor(config.colors[Config.C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i++) {
            dc.fillPolygon(shapes.rotate(i % 5 ? Shapes.S_SMALLTICKMARK : Shapes.S_BIGTICKMARK, i * 0.104719755 /* 2*pi/60 */, _screenCenter[0], _screenCenter[1]));
        }

        var indicatorOption = config.getOption(Config.I_HIDE_INDICATORS);
        var hideIndicators = :HideIndicatorsAlways == indicatorOption 
            or (:HideIndicatorsInDm == indicatorOption and Config.M_DARK == colorMode);
        if (_isAwake or !hideIndicators) {
            // Draw the indicators
            _indicators.draw(dc, deviceSettings);
            _indicators.drawHeartRate(dc, _isAwake);
        }

        // Draw the hour and minute hands
        var hourHandAngle = ((hour % 12) * 60.0 + minute) / 12.0 * 0.104719755 /* 2*pi/60 */;
        var hourHandCoords = shapes.rotate(Shapes.S_HOURHAND, hourHandAngle, _screenCenter[0], _screenCenter[1]);
        var minuteHandCoords = shapes.rotate(Shapes.S_MINUTEHAND, minute * 0.104719755 /* 2*pi/60 */, _screenCenter[0], _screenCenter[1]);
        if (_doWireHands != 0) { _doWireHands -= 1; } // Update the wire hands timer
        if (0 == _doWireHands) { // draw regular hour and minute hands
            dc.setColor(config.colors[Config.C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(hourHandCoords);
            dc.fillPolygon(minuteHandCoords);
        } else { // draw only the outline of the hands
            var pw = 3;
            if (config.hasCapability(:Alpha)) {
                dc.setStroke(Graphics.createColor(0x80, 0x80, 0x80, 0x80));
            } else {
                dc.setColor(config.colors[Config.C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
                pw = 1;
            }
            dc.setPenWidth(pw); // TODO: Should be a percentage of the clock radius
            drawPolygon(dc, hourHandCoords);
            drawPolygon(dc, minuteHandCoords);
        }

        if (_isAwake) {
            var accentColor = config.getAccentColor(hour, minute, second);
            drawSecondHand(dc, second, accentColor);
        }
    }

    // Draw the edges of a polygon
    private function drawPolygon(dc as Dc, pts as Array<Point2D>) as Void {
        var size = pts.size();
        for (var i = 0; i < size; i++) {
            var startPoint = pts[i];
            var endPoint = pts[(i + 1) % size];
            dc.drawLine(startPoint[0], startPoint[1], endPoint[0], endPoint[1]);
        }
    }

    // Draw the second hand for the given second.
    // This function has been optimized to use only pre-calculated numbers.
    private function drawSecondHand(dc as Dc, second as Number, accentColor as Number) as Void {
        // Use the pre-calculated numbers for the current second
        var sd = shapes.secondData[second];
        var coords = [[sd[2], sd[3]], [sd[4], sd[5]], [sd[6], sd[7]], [sd[8], sd[9]]];

        // Draw the second hand
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(coords);
        dc.fillCircle(sd[0], sd[1], shapes.secondCircleRadius);
    }
} // class ClockView

// Receives watch face events
class ClockDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as ClockView;

    // Constructor
    public function initialize(view as ClockView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    // The onPress callback is called when user does a touch and hold (Since API Level 4.2.0)
    public function onPress(clickEvent as ClickEvent) as Boolean {
        _view.startWireHands();
        return true;
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
