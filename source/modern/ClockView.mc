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

// Implements the Swiss Railway Clock watch face for modern watches, using layers
class ClockView extends WatchUi.WatchFace {
    private const SECOND_HAND_TIMER as Number = 30; // Number of seconds in low-power mode, before the second hand disappears

    private var _isAwake as Boolean = true; // Assume we start awake and depend on onEnterSleep() to fall asleep

    private var _lastDrawnMin as Number = -1; // Minute when the watch face was last completely re-drawn
    private var _doPartialUpdates as Boolean = true; // WatchUi.WatchFace has :onPartialUpdate since API Level 2.3.0
    private var _accentColor as Number = 0;
    private var _doWireHands as Number = 0; // Number of seconds to show the minute and hour hands was wire hands after press
    private var _sleepTimer as Number = SECOND_HAND_TIMER; // Counter for the time in low-power mode, before the second hand disappears
    private var _hideSecondHand as Boolean = false;
    private var _show3dEffects as Boolean = false;
    private var _shadowColor as Number = 0;

    private var _screenShape as Number;
    private var _screenCenter as Array<Number>;
    private var _clockRadius as Number;

    private var _secondLayer as Layer;
    private var _secondShadowLayer as Layer;
    private var _backgroundDc as Dc;
    private var _hourMinuteDc as Dc;
    private var _secondDc as Dc;
    private var _secondShadowDc as Dc;

    private var _indicators as Indicators;

    // Constructor. Initialize the variables for this view.
    public function initialize() {
        WatchFace.initialize();

        if (config.hasCapability(:Alpha)) { _shadowColor = Graphics.createColor(0x80, 0x80, 0x80, 0x80); }
        var deviceSettings = System.getDeviceSettings();
        _screenShape = deviceSettings.screenShape;
        var width = deviceSettings.screenWidth;
        var height = deviceSettings.screenHeight;
        _screenCenter = [width/2, height/2] as Array<Number>;
        _clockRadius = _screenCenter[0] < _screenCenter[1] ? _screenCenter[0] : _screenCenter[1];

        // Instead of a buffered bitmap, this version uses multiple layers (since API Level 3.1.0):
        //
        // 1) A background layer with the tick marks and any indicators.
        // 2) A full screen layer just for the shadow of the second hand (when 3d effects are on)
        // 3) Another full screen layer for the hour and minute hands.
        // 4) A dedicated layer for the second hand.
        //
        // Using layers is elegant and makes it possible to draw some indicators even in low-power
        // mode, e.g., the heart rate is updated every second in high-power mode and every 10 seconds
        // in low power mode.
        // On the other hand, this architecture requires more memory and is only feasible on CIQ 4
        // devices, i.e., on devices with a graphics pool, and on a few older models which have
        // more memory.
        // For improved performance, we're still using a clipping region for both second hands to
        // limit the area affected when clearing the layer.
        // There's potential to reduce the memory footprint by minimizing the size of the second
        // hand layers to about a quarter of the screen size and moving them every 15 seconds.

        // Initialize layers and add them to the view
        var opts = {:locX => 0, :locY => 0, :width => width, :height => height};
        var backgroundLayer = new WatchUi.Layer(opts);
        var hourMinuteLayer = new WatchUi.Layer(opts);
        _secondLayer = new WatchUi.Layer(opts);
        _secondShadowLayer = new WatchUi.Layer(opts);

        addLayer(backgroundLayer);
        addLayer(_secondShadowLayer);
        addLayer(hourMinuteLayer);
        addLayer(_secondLayer);
        _backgroundDc = backgroundLayer.getDc() as Dc;
        _hourMinuteDc = hourMinuteLayer.getDc() as Dc;
        _secondDc = _secondLayer.getDc() as Dc;
        _secondShadowDc = _secondShadowLayer.getDc() as Dc;
        _backgroundDc.setAntiAlias(true); // Graphics.Dc has :setAntiAlias since API Level 3.2.0
        _hourMinuteDc.setAntiAlias(true);
        _secondDc.setAntiAlias(true);
        _secondShadowDc.setAntiAlias(true);

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
        // Update indicator positions, which depend on the watchface shapes and iconfont size
        _indicators.updatePos();
    }

    // Called when this View is brought to the foreground. Restore the state of this view and
    // prepare it to be shown. This includes loading resources into memory.
    public function onShow() as Void {
        // Assuming onShow() is triggered after any settings change, force the watch face
        // to be re-drawn in the next call to onUpdate(). This is to immediately react to
        // changes of the watch settings or a possible change of the DND setting.
        _lastDrawnMin = -1;
    }

    // This method is called when the device re-enters sleep mode
    public function onEnterSleep() as Void {
        _isAwake = false;
        _lastDrawnMin = -1; // Force the watchface to be re-drawn
        WatchUi.requestUpdate();
    }

    // This method is called when the device exits sleep mode
    public function onExitSleep() as Void {
        _isAwake = true;
        _lastDrawnMin = -1; // Force the watchface to be re-drawn
        WatchUi.requestUpdate();
    }

    public function startWireHands() as Void {
        _doWireHands = 6;
        _lastDrawnMin = -1;
        WatchUi.requestUpdate();
    }

    public function stopPartialUpdates() as Void {
        _doPartialUpdates = false;
        config.colors[Config.C_BACKGROUND] = Graphics.COLOR_BLUE; // Hack to make the issue visible
    }

    // Handle the update event. This function is called
    // 1) every second when the device is awake,
    // 2) every full minute in low-power mode, and
    // 3) it's also triggered when the device goes in or out of low-power mode
    //    (from onEnterSleep() and onExitSleep()).
    //
    // In low-power mode, onPartialUpdate() is called every second, except on the full minute,
    // and the system enforces a power budget, which the code must not exceed.
    //
    // The watchface is redrawn every full minute and when the watch enters or exists sleep.
    // During sleep, onPartialUpdate deletes and redraws the second hand.
    public function onUpdate(dc as Dc) as Void {
        dc.clearClip(); // Still needed as the settings menu messes with the clip

        // Update the low-power mode timer
        if (_isAwake) { 
            _sleepTimer = SECOND_HAND_TIMER; // Reset the timer
        } else if (_sleepTimer != 0) {
            _sleepTimer -= 1;
        }

        // Update the wire hands timer
        if (_doWireHands != 0) {
            _doWireHands -= 1;
            if (0 == _doWireHands) {
                _lastDrawnMin = -1;
            }
        }

        var clockTime = System.getClockTime();
        var hour = clockTime.hour; // Using local variables for these saves a bit of memory
        var minute = clockTime.min;
        var second = clockTime.sec;
        var deviceSettings = System.getDeviceSettings();

        // Only re-draw the watch face if the minute changed since the last time
        if (_lastDrawnMin != minute) { 
            _lastDrawnMin = minute;

            // Determine all colors based on the relevant settings
            var colorMode = config.setColors(_isAwake, deviceSettings.doNotDisturb, hour, minute);

            // Note: Whether 3D effects are supported by the device is also ensured by getValue().
            _show3dEffects = config.isEnabled(Config.I_3D_EFFECTS) and Config.M_LIGHT == colorMode;
            _secondShadowLayer.setVisible(_show3dEffects and _isAwake);

            // Handle the setting to disable the second hand in sleep mode after some time
            var secondsOption = config.getOption(Config.I_HIDE_SECONDS);
            _hideSecondHand = :HideSecondsAlways == secondsOption 
                or (:HideSecondsInDm == secondsOption and Config.M_DARK == colorMode);
            _secondLayer.setVisible(_sleepTimer != 0 or !_hideSecondHand);

            // Draw the background
            if (System.SCREEN_SHAPE_ROUND == _screenShape) {
                // Fill the entire background with the background color
                _backgroundDc.setColor(config.colors[Config.C_BACKGROUND], config.colors[Config.C_BACKGROUND]);
                _backgroundDc.clear();
            } else {
                // Fill the entire background with black and draw a circle with the background color
                _backgroundDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                _backgroundDc.clear();
                if (config.colors[Config.C_BACKGROUND] != Graphics.COLOR_BLACK) {
                    _backgroundDc.setColor(config.colors[Config.C_BACKGROUND], config.colors[Config.C_BACKGROUND]);
                    _backgroundDc.fillCircle(_screenCenter[0], _screenCenter[1], _clockRadius);
                }
            }

            // Draw tick marks around the edge of the screen on the background layer
            _backgroundDc.setColor(config.colors[Config.C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < 60; i++) {
                _backgroundDc.fillPolygon(shapes.rotate(i % 5 ? Shapes.S_SMALLTICKMARK : Shapes.S_BIGTICKMARK, i * 0.104719755 /* 2*pi/60 */, _screenCenter[0], _screenCenter[1]));
            }

            // Clear the layer used for the hour and minute hands
            _hourMinuteDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
            _hourMinuteDc.clear();

            // Draw the hour and minute hands and their shadows
            var hourHandAngle = ((hour % 12) * 60.0 + minute) / 12.0 * 0.104719755 /* 2*pi/60 */;
            var hourHandCoords = shapes.rotate(Shapes.S_HOURHAND, hourHandAngle, _screenCenter[0], _screenCenter[1]);
            var minuteHandCoords = shapes.rotate(Shapes.S_MINUTEHAND, minute * 0.104719755 /* 2*pi/60 */, _screenCenter[0], _screenCenter[1]);
            if (_isAwake and _show3dEffects and 0 == _doWireHands) {
                _hourMinuteDc.setFill(_shadowColor);
                _hourMinuteDc.fillPolygon(shadowCoords(hourHandCoords, 7));
                _hourMinuteDc.fillPolygon(shadowCoords(minuteHandCoords, 8));
            }
            if (0 == _doWireHands) {
                _hourMinuteDc.setColor(config.colors[Config.C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
                _hourMinuteDc.fillPolygon(hourHandCoords);
                _hourMinuteDc.fillPolygon(minuteHandCoords);
            } else {
                var pw = 3;
                if (config.hasCapability(:Alpha)) {
                    _hourMinuteDc.setStroke(_shadowColor);
                } else {
                    _hourMinuteDc.setColor(config.colors[Config.C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
                    pw = 1;
                }
                _hourMinuteDc.setPenWidth(pw); // TODO: Should be a percentage of the clock radius
                shapes.drawPolygon(_hourMinuteDc, hourHandCoords);
                shapes.drawPolygon(_hourMinuteDc, minuteHandCoords);
            }
        } // if (_lastDrawnMin != minute)

        if (_isAwake or _doPartialUpdates and (_sleepTimer != 0 or !_hideSecondHand)) {
            // Draw the indicators and the heart rate on the background layer, 
            // every time onUpdate() is called and the second hand is drawn
            _indicators.draw(_backgroundDc, deviceSettings);
            _indicators.drawHeartRate(_backgroundDc, _isAwake);

            // Clear the clip of the second layer to delete the second hand
            _secondDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
            _secondDc.clear();
            if (_isAwake and _show3dEffects) {
                // Clear the clip of the second hand shadow layer to delete the shadow
                _secondShadowDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
                _secondShadowDc.clear();
            }
            // Determine the color of the second hand and draw it and its shadow
            _accentColor = config.getAccentColor(hour, minute, second);
            drawSecondHand(_secondDc, second);
        }
    }

    // Handle the partial update event. This function is called every second when the device is
    // in low-power mode. See onUpdate() for the full story.
    public function onPartialUpdate(dc as Dc) as Void {
        _isAwake = false; // To state the obvious. Workaround for an Enduro 2 firmware bug.
        if (_doWireHands !=  0) {
            _doWireHands -= 1;
            if (0 == _doWireHands) {
                _lastDrawnMin = -1;
                WatchUi.requestUpdate();
            }
        }
        if (_sleepTimer != 0) { 
            _sleepTimer -= 1;
            if (0 == _sleepTimer and _hideSecondHand) {
                // Delete the second hand for the last time
                _secondDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
                _secondDc.clear();
                _secondLayer.setVisible(false);
            }
        }
        if (_sleepTimer != 0 or !_hideSecondHand) {
            var second = System.getClockTime().sec;

            // Continue to draw the heart rate indicator every 10 seconds in onPartialUpdate()
            if (0 == second % 10) {
                _indicators.drawHeartRate(_backgroundDc, _isAwake);
            }

            // Clear the clip of the second layer to delete the second hand, then re-draw it
            _secondDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
            _secondDc.clear();
            drawSecondHand(_secondDc, second);
        }
    }

    // Draw the second hand for the given second, including a shadow, if required, and set the clipping region.
    // This function is performance critical (when !_isAwake) and has been optimized to use only pre-calculated numbers.
    private function drawSecondHand(dc as Dc, second as Number) as Void {
        // Use the pre-calculated numbers for the current second
        var sd = shapes.secondData[second];
        var coords = [[sd[2], sd[3]], [sd[4], sd[5]], [sd[6], sd[7]], [sd[8], sd[9]]] as Array<Point2D>;

        // Set the clipping region
        dc.setClip(sd[10], sd[11], sd[12], sd[13]);

        if (_isAwake and _show3dEffects and 0 == _doWireHands) {
            // Set the clipping region of the shadow by moving the clipping region of the second hand
            var sc = shadowCoords([[sd[0], sd[1]], [sd[10], sd[11]]], 9);
            _secondShadowDc.setClip(sc[1][0], sc[1][1], sd[12], sd[13]);

            // Draw the shadow of the second hand
            _secondShadowDc.setFill(_shadowColor);
            _secondShadowDc.fillPolygon(shadowCoords(coords, 9));
            _secondShadowDc.fillCircle(sc[0][0], sc[0][1], shapes.secondCircleRadius);
        }

        // Draw the second hand
        dc.setColor(_accentColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(coords);
        dc.fillCircle(sd[0], sd[1], shapes.secondCircleRadius);
    }

    // TODO: move the shadow shapes by a percentage instead of a number of pixels
    private function shadowCoords(coords as Array<Point2D>, len as Number) as Array<Point2D> {
        var size = coords.size();
        var result = new Array<Point2D>[size];
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

    // The onPowerBudgetExceeded callback is called by the system if the
    // onPartialUpdate method exceeds the allowed power budget. If this occurs,
    // the system will stop invoking onPartialUpdate each second, so we notify the
    // view here to let the rendering methods know they should not be rendering a
    // second hand.
    public function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        _view.stopPartialUpdates();
    }
}
