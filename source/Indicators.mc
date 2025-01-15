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
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Class to draw all the indicators depending on the menu settings at the correct place on the watchface.
// All devices share the same implementations of the functions which draw the indicators. However, not 
// all of the indicators are available on legacy devices, and there is different code for both, due to
// memory constraints on the latter: Modern devices use a lookup-array of positions for different things
// and a dedicated function in which the decision is made if and where to draw a given indicator - a
// more maintainable design. Legacy devices have all of this jumbled up in a single function that
// orchestrates the drawing. It's a bit less critical for these, as they support a limited number of
// indicators, so there are fewer interdependencies for the positions and it's necessary to minimize
// memory usage.
class Indicators {
    private var _batteryLevel as BatteryLevel;

    (:modern) private var _batteryDrawn as Boolean = false;
    (:modern) private var _iconsDrawn as Boolean = false;
    (:modern) private var _stepsDrawn as Boolean = false;
    (:modern) private var _hrat6 as Boolean = false;
    (:modern) private var _dtat6 as Boolean = false;
    (:modern) private var _screenCenter as Array<Number>;
    (:modern) private var _clockRadius as Number;
    (:modern) private var _drawHeartRate as Number = -1;
    (:modern) private var _pos as Array< Array<Number> >; // Positions (x,y) of the indicators

    (:legacy) private var _width as Number;
    (:legacy) private var _height as Number;
    (:legacy) private var _phoneConnectedY as Number = 0;

    // Constructor
    (:modern) public function initialize(
        width as Number, 
        height as Number, 
        screenCenter as Array<Number>,
        clockRadius as Number
    ) {
        _screenCenter = screenCenter;
        _clockRadius = clockRadius;
        _batteryLevel = new BatteryLevel(clockRadius);

        // Positions of the various indicators
        _pos = [
            [(width * 0.73).toNumber(), (height * 0.50).toNumber()], //  0: Heart rate indicator at 3 o'clock
            [(width * 0.48).toNumber(), (height * 0.75).toNumber()], //  1: Heart rate indicator at 6 o'clock
            [(width * 0.23).toNumber(), (height * 0.50).toNumber()], //  2: Recovery time indicator at 9 o'clock
            [(width * 0.50).toNumber(), (height * 0.30).toNumber()], //  3: Battery level indicator at 12 o'clock with notifications
            [(width * 0.50).toNumber(), (height * 0.25).toNumber()], //  4: Battery level indicator at 12 o'clock w/o notifications
            [(width * 0.50).toNumber(), (height * 0.165).toNumber()], //  5: Alarms and notifications at 12 o'clock
            [0, 0],                                                  //  6: Phone connection indicator on the 6 o'clock tick mark (see updatePos() )
            [(width * 0.75).toNumber(), (height * 0.50 - Graphics.getFontHeight(Graphics.FONT_MEDIUM)/2 - 1).toNumber()], // 7: Date (day format) at 3 o'clock
            [(width * 0.50).toNumber(), (height * 0.65).toNumber()], //  8: Date (weekday and day format) at 6 o'clock, w/o steps
            [(width * 0.50).toNumber(), (height * 0.69).toNumber()], //  9: Date (weekday and day format) at 6 o'clock, with steps
            [(width * 0.49).toNumber(), (height * 0.70).toNumber()], // 10: Steps at 6 o'clock, w/o date (weekday and day format)
            [(width * 0.49).toNumber(), (height * 0.65).toNumber()], // 11: Steps at 6 o'clock, with date (weekday and day format)
            [(width * 0.49).toNumber(), (height * 0.76).toNumber()], // 12: Heart rate indicator at 6 o'clock with steps
            [(width * 0.49).toNumber(), (height * 0.39).toNumber()], // 13: Calories in upper half, with notifications and battery
            [(width * 0.49).toNumber(), (height * 0.35).toNumber()]  // 14: Calories in upper half, w/o notifications but with battery
        ] as Array< Array<Number> >;
    }

    (:legacy) public function initialize(width as Number, height as Number, clockRadius as Number) {
        _width = width;
        _height = height;
        _batteryLevel = new BatteryLevel(clockRadius);
    }

    // Update any indicator positions, which depend on numbers that are not available yet when the constructor is called
    (:modern) public function updatePos(width as Number, height as Number, s0 as Float, s3 as Float) as Void {
        _pos[6] = [(width * 0.50).toNumber(), (height * 0.50 + s3 + (s0 - Graphics.getFontHeight(ClockView.iconFont as FontResource))/3).toNumber()];
    }

    (:legacy) public function updatePos(s0 as Float, s3 as Float) as Void {
        _phoneConnectedY = (_height * 0.50 + s3 + (s0 - Graphics.getFontHeight(ClockView.iconFont as FontResource))/3).toNumber();
    }

    // Draw all indicators. The legacy version checks settings and determines positions within this function as well.
    (:legacy) public function draw(dc as Dc, deviceSettings as DeviceSettings, isAwake as Boolean) as Void {
        var activityInfo = ActivityMonitor.getInfo();
        var w2 = (_width * 0.50).toNumber();
        var iconsDrawn = false;
        var batteryDrawn = false;
        var stepsDrawn = false;

        // Draw alarm and notification indicators
        if (config.isEnabled(Config.I_ALARMS) or config.isEnabled(Config.I_NOTIFICATIONS)) {
            iconsDrawn = drawIcons(
                dc,
                w2, 
                (_height * 0.165).toNumber(), // idx = 5
                deviceSettings.alarmCount,
                deviceSettings.notificationCount
            );
        }

        // Draw the battery level indicator
        if (config.isEnabled(Config.I_BATTERY)) {
            var h = iconsDrawn ? 0.30 : 0.25; // idx = 3 : 4
            batteryDrawn = _batteryLevel.draw(
                dc,
                w2, 
                (_height * h).toNumber()
            );
        }

        // Draw the date string
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        dc.setColor(ClockView.colors[ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
        var dateDisplay = config.getOption(Config.I_DATE_DISPLAY);
        if (:DateDisplayDayOnly == dateDisplay) {
            dc.drawText(
                (_width * 0.75).toNumber(), 
                (_height * 0.50 - Graphics.getFontHeight(Graphics.FONT_MEDIUM)/2 - 1).toNumber(), 
                Graphics.FONT_MEDIUM, 
                info.day.format("%02d"), 
                Graphics.TEXT_JUSTIFY_CENTER
            );
        } else if (:DateDisplayWeekdayAndDay == dateDisplay) {
            var h = 0.65; // idx = 8
            if (config.isEnabled(Config.I_STEPS)) {
                if (batteryDrawn or config.isEnabled(Config.I_CALORIES)) {
                    h = 0.69; // idx = 9
                } // else idx = 8
            } else {
                if (batteryDrawn and config.isEnabled(Config.I_CALORIES)) {
                    h = 0.69; // idx = 9
                } // else idx = 8
            }
            dc.drawText(
                w2, 
                (_height * h).toNumber(), 
                Graphics.FONT_MEDIUM, 
                Lang.format("$1$ $2$", [info.day_of_week, info.day]), 
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }

        // Draw the phone connection indicator on the 6 o'clock tick mark
        if (config.isEnabled(Config.I_CONNECTED)) { 
            drawPhoneConnected(
                dc,
                w2,
                _phoneConnectedY,
                deviceSettings.phoneConnected
            );
        }

        // Draw the heart rate indicator
        if (config.isEnabled(Config.I_HEART_RATE)) {
            var w = 0.73; // idx = 0
            var h = 0.50;
            if (:DateDisplayDayOnly == dateDisplay) {
                if (config.isEnabled(Config.I_STEPS)) {
                    w = 0.49; // idx = 12
                    h = 0.76;
                } else {
                    w = 0.48; // idx = 1
                    h = 0.75;
                }
            }
            drawHeartRate2(
                dc, 
                (_width * w).toNumber(), 
                (_height * h).toNumber(),
                isAwake
            );
        }

        // Draw the recovery time indicator
        if (config.isEnabled(Config.I_RECOVERY_TIME)) { 
            if (ActivityMonitor.Info has :timeToRecovery) {
                drawIndicator(
                    dc,
                    (_width * 0.23).toNumber(),
                    (_height * 0.50).toNumber(),
                    "R",
                    false,
                    activityInfo.timeToRecovery
                );
            }
        }

        // Helper - is the heart rate indicator at 6 o'clock?
        var hrat6 =     :DateDisplayDayOnly == dateDisplay
                    and config.isEnabled(Config.I_HEART_RATE);
        // Helper - is the (long) date at 6 o'clock?
        var dtat6 = :DateDisplayWeekdayAndDay == dateDisplay;

        // Draw the steps indicator
        if (config.isEnabled(Config.I_STEPS)) {
            var w = 0.49; // idx = 10, 11
            var h = 0.70; // idx = 10
            if (hrat6 or dtat6) {
                if (config.isEnabled(Config.I_CALORIES) or batteryDrawn) {
                    h = 0.65; // idx = 11
                } else {
                    w = 0.50; // idx = 3
                    h = 0.30;
                }
            } else {
                if (config.isEnabled(Config.I_CALORIES) and batteryDrawn and iconsDrawn) {
                    h = 0.65; // idx = 11
                } // else idx = 10
            }
            stepsDrawn = drawIndicator(
                dc,
                (_width * w).toNumber(),
                (_height * h).toNumber(),
                "F",
                true,
                activityInfo.steps // since API Level 1.0.0
            );
        }

        // Draw the calories indicator
        if (config.isEnabled(Config.I_CALORIES)) {
            var w = 0.50; // idx = 3
            var h = 0.30;
            if (!stepsDrawn) { // place calories where steps would usually be
                if (hrat6 or dtat6) {
                    if (batteryDrawn) {
                        w = 0.49; // idx = 11
                        h = 0.65;
                    } // else idx = 3
                } else {
                    w = 0.49; // idx = 10
                    h = 0.70;
                }
            } else {
                // if steps are drawn, (mostly) place calories in the upper half of the screen.
                // Do not squeeze the calories in the upper half (13), if battery and icons are
                // on and only the steps are at the bottom. Instead, draw calories below steps 
                // at the bottom then (12).
                if (batteryDrawn) {
                    w = 0.49; // idx = 12, 13, 14
                    if (iconsDrawn) {
                        h = hrat6 or dtat6 ? 0.39 : 0.76; // idx = 13 : 12
                    } else {
                        h = 0.35; // idx = 14
                    }
                } // else idx = 3
            }
            drawIndicator(
                dc,
                (_width * w).toNumber(),
                (_height * h).toNumber(),
                "C",
                true,
                activityInfo.calories // since API Level 1.0.0
            );
        }
    }

    // Draw all the indicators, which are updated once a minute (all except the heart rate).
    // The modern version uses a helper function to determine if and where each indicator is drawn.
    (:modern) public function draw(dc as Dc, deviceSettings as DeviceSettings, isAwake as Boolean) as Void {
        var activityInfo = ActivityMonitor.getInfo();

        // Helper - is the heart rate indicator at 6 o'clock?
        _hrat6 =     :DateDisplayDayOnly == config.getOption(Config.I_DATE_DISPLAY)
                 and config.isEnabled(Config.I_HEART_RATE);
        // Helper - is the (long) date at 6 o'clock?
        _dtat6 = :DateDisplayWeekdayAndDay == config.getOption(Config.I_DATE_DISPLAY);

        // Draw the move bar (at a fixed position, so we don't need getIndicatorPosition() here)
        if (config.isEnabled(Config.I_MOVE_BAR)) {
            drawMoveBar(dc, _screenCenter[0], _screenCenter[1], _clockRadius, activityInfo.moveBarLevel);
        }

        // Draw alarm and notification indicators
        _iconsDrawn = false;
        var idx = -1;
        idx = getIndicatorPosition(:icons);
        if (-1 != idx) {
            _iconsDrawn = drawIcons(
                dc,
                _pos[idx][0], 
                _pos[idx][1], 
                deviceSettings.alarmCount,
                deviceSettings.notificationCount
            );
        }

        // Draw the battery level indicator
        _batteryDrawn = false;
        idx = getIndicatorPosition(:battery);
        if (-1 != idx) {
            _batteryDrawn = _batteryLevel.draw(
                dc,
                _pos[idx][0], 
                _pos[idx][1]
            );
        }

        // Draw the date string
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        dc.setColor(ClockView.colors[ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
        idx = getIndicatorPosition(:longDate);
        if (-1 != idx) {
            dc.drawText(
                _pos[idx][0], 
                _pos[idx][1], 
                Graphics.FONT_MEDIUM, 
                Lang.format("$1$ $2$", [info.day_of_week, info.day]), 
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        else {
            idx = getIndicatorPosition(:shortDate);
            if (-1 != idx) {
                dc.drawText(
                    _pos[idx][0], 
                    _pos[idx][1], 
                    Graphics.FONT_MEDIUM, 
                    info.day.format("%02d"), 
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
        }

        // Draw the phone connection indicator on the 6 o'clock tick mark
        idx = getIndicatorPosition(:phoneConnected);
        if (-1 != idx) {
            drawPhoneConnected(
                dc,
                _pos[idx][0],
                _pos[idx][1],
                deviceSettings.phoneConnected
            );
        }

        // Determine if and where the heart rate should be drawn, but don't
        // draw it here. The indicator is drawn in drawHeartRate(), which
        // needs to be called after this function, once the position is set.
        // This is done to minimize the work necessary in drawHeartRate(), 
        // as that is also called in low-power mode, from onPartialUpdate(),
        // when the position always remains the same.
        _drawHeartRate = getIndicatorPosition(:heartRate);

        // Draw the recovery time indicator
        idx = getIndicatorPosition(:recoveryTime);
        if (-1 != idx) {
            if (ActivityMonitor.Info has :timeToRecovery) {
                System.println("ActivityMonitor.Info has :timeToRecovery");
                drawIndicator(
                    dc,
                    _pos[idx][0],
                    _pos[idx][1],
                    "R",
                    false,
                    19 // activityInfo.timeToRecovery
                );
            } else { System.println("ActivityMonitor.Info does not have :timeToRecovery"); }
        }

        // Draw the steps indicator
        _stepsDrawn = false;
        idx = getIndicatorPosition(:footsteps);
        if (-1 != idx) {
            _stepsDrawn = drawIndicator(
                dc,
                _pos[idx][0],
                _pos[idx][1],
                "F",
                true,
                activityInfo.steps // since API Level 1.0.0
            );
        }

        // Draw the calories indicator
        idx = getIndicatorPosition(:calories);
        if (-1 != idx) {
            drawIndicator(
                dc,
                _pos[idx][0],
                _pos[idx][1],
                "C",
                true,
                activityInfo.calories // since API Level 1.0.0
            );
        }
    }

    // Draw the heart rate if it is available, return true if it was drawn.
    // Modern devices call this every few seconds, also in low-power mode.
    (:modern) public function drawHeartRate(dc as Dc, isAwake as Boolean) as Boolean {
        return -1 == _drawHeartRate ? false : drawHeartRate2(dc, _pos[_drawHeartRate][0], _pos[_drawHeartRate][1], isAwake);
    }

    // Determine if a given indicator should be shown and its position on the screen. 
    // This function exists to have all decisions regarding indicator placing, some of which are 
    // interdependent, in one place.
    // The position returned is an index into _pos. -1 means the indicator should not be drawn.
    (:modern) private function getIndicatorPosition(indicator as Symbol) as Number {
        var idx = -1;
        switch (indicator) {
            case :recoveryTime:
                if (config.isEnabled(Config.I_RECOVERY_TIME)) { 
                    idx = 2; 
                }
                break;
            case :battery:
                if (config.isEnabled(Config.I_BATTERY)) {
                    idx = _iconsDrawn ? 3 : 4;
                }
                break;
            case :icons:
                if (   config.isEnabled(Config.I_ALARMS)
                    or config.isEnabled(Config.I_NOTIFICATIONS)) {
                    idx = 5;
                }
                break;
            case :phoneConnected:
                if (config.isEnabled(Config.I_CONNECTED)) { 
                    idx = 6; 
                }
                break;
            case :shortDate:
                if (:DateDisplayDayOnly == config.getOption(Config.I_DATE_DISPLAY)) { 
                    idx = 7; 
                }
                break;
            case :longDate:
                if (:DateDisplayWeekdayAndDay == config.getOption(Config.I_DATE_DISPLAY)) {
                    if (config.isEnabled(Config.I_STEPS)) {
                        idx = _batteryDrawn or config.isEnabled(Config.I_CALORIES) ? 9 : 8;
                    } else {
                        idx = _batteryDrawn and config.isEnabled(Config.I_CALORIES) ? 9 : 8;
                    }
                }
                break;
            case :heartRate:
                if (config.isEnabled(Config.I_HEART_RATE)) {
                    idx = 0;
                    if (:DateDisplayDayOnly == config.getOption(Config.I_DATE_DISPLAY)) {
                        idx = (config.isEnabled(Config.I_STEPS)) ? 12 : 1;
                    }
                }
                break;
            case :footsteps:
                if (config.isEnabled(Config.I_STEPS)) {
                    if (_hrat6 or _dtat6) {
                        idx = config.isEnabled(Config.I_CALORIES) or _batteryDrawn ? 11 : 3;
                    } else {
                        idx = config.isEnabled(Config.I_CALORIES) and _batteryDrawn and _iconsDrawn ? 11 : 10;
                    }
                }
                break;
            case :calories:
                if (config.isEnabled(Config.I_CALORIES)) {
                    if (!_stepsDrawn) { // place calories where steps would usually be
                        if (_hrat6 or _dtat6) {
                            idx = _batteryDrawn ? 11 : 3;
                        } else {
                            idx = 10;
                        }
                    } else {
                        // if steps are drawn, (mostly) place calories in the upper half of the screen.
                        // Do not squeeze the calories in the upper half (13), if battery and icons are
                        // on and only the steps are at the bottom. Instead, draw calories below steps 
                        // at the bottom then (12).
                        if (_batteryDrawn) {
                            if (_iconsDrawn) {
                                idx = _hrat6 or _dtat6 ? 13 : 12;
                            } else {
                                idx = 14;
                            }
                        } else {
                            idx = 3;
                        }
                    }
                }
                break;
            default:
                System.println("ERROR: Indicators.getIndicatorPos() is not implemented for indicator = " + indicator);
                break;
        }
        return idx;
    }

    // Draw the heart rate if it is available, return true if it was drawn.
    // This private function is used by both, the legacy and modern code.
    // Note: Sets and clears the clipping region of the device context.
    private function drawHeartRate2(dc as Dc, xpos as Number, ypos as Number, isAwake as Boolean) as Boolean {
        var ret = false;
        var heartRate = null;
        var activityInfo = Activity.getActivityInfo();
        if (activityInfo != null) {
            heartRate = activityInfo.currentHeartRate;
        }
        if (null == heartRate) {
            var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (sample != null and sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) { 
                heartRate = sample.heartRate;
            }
        }
        if (heartRate != null) {
            //heartRate = 123;
            //heartRate = System.getClockTime().sec + 60;
            var font = Graphics.FONT_TINY;
            var fontHeight = Graphics.getFontHeight(font);
            var width = (fontHeight * 2.1).toNumber(); // Indicator width
            var hr = heartRate.format("%d");

            var bgColor = ClockView.colors[ClockView.C_BACKGROUND];
            dc.setClip(xpos - width*0.48, ypos - fontHeight*0.38, width, fontHeight*0.85);
            dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
            dc.clear();
            dc.clearClip();
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                heartRate > 99 ? xpos - width*2/16 - 1 : xpos, ypos - 1, 
                ClockView.iconFont as FontResource, 
                isAwake ? "H" : "I" as String, 
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(ClockView.colors[ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                xpos + width/2, 
                ypos,
                font, 
                hr, 
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            ret = true;
        }
        return ret;
    }

    // Draw alarm and notification icons, return true if something was drawn, else false
    private function drawIcons(
        dc as Dc,
        xpos as Number, 
        ypos as Number, 
        alarmCount as Number,
        notificationCount as Number
    ) as Boolean {
        var icons = "";
        var space = "";
        var indicators = [
            config.isEnabled(Config.I_ALARMS) and alarmCount > 0, 
            config.isEnabled(Config.I_NOTIFICATIONS) and notificationCount > 0
        ];
        for (var i = 0; i < indicators.size(); i++) {
            if (indicators[i]) {
                icons += space + ["A", "M"][i];
                space = " ";
            }
        }
        var ret = false;
        if (!icons.equals("")) {
            dc.setColor(ClockView.colors[ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(xpos, ypos, ClockView.iconFont as FontResource, icons as String, Graphics.TEXT_JUSTIFY_CENTER);
            ret = true;
        }
        return ret;
    }

    // Draw the Bluetooth icon when the watch is connected to a phone, return true if something was drawn
    private function drawPhoneConnected(
        dc as Dc,
        xpos as Number, 
        ypos as Number, 
        phoneConnected as Boolean
    ) as Boolean {
        var ret = false;
        var iconColor = Graphics.COLOR_BLUE;
        var fgColor = ClockView.colors[ClockView.C_FOREGROUND];
        if (Graphics.COLOR_LT_GRAY == fgColor or Graphics.COLOR_WHITE == fgColor) {
            iconColor = Graphics.COLOR_DK_BLUE;
        }
        if (phoneConnected) {
            dc.setColor(iconColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xpos, ypos, ClockView.iconFont as FontResource, "B" as String, Graphics.TEXT_JUSTIFY_CENTER);
            ret = true;
        }
        return ret;
    }

    // Draw a simple indicator, return true if it was drawn. Used for recovery time, steps and calories.
    private function drawIndicator(
        dc as Dc,
        xpos as Number, 
        ypos as Number,
        icon as String,
        iconLeft as Boolean,
        value as Number?
    ) as Boolean {
        var ret = false;
        //value = 123;
        //value = 87654;
        //value = 3456;
        if (value != null and value > 0) {
            var font = Graphics.FONT_TINY;
            var fontHeight = Graphics.getFontHeight(font);
            var width = (fontHeight * 2.1).toNumber(); // Indicator width
            var xposText = xpos;
            var xposIcon = xpos;
            var textAlign = Graphics.TEXT_JUSTIFY_VCENTER;
            if (iconLeft) {
                xposText -= value > 999 ? value > 9999 ? width*9/32 : width*6/32 : width*3/32;
                xposIcon -= value > 999 ? value > 9999 ? width*22/32 : width*19/32 : width*16/32;
                textAlign |= Graphics.TEXT_JUSTIFY_LEFT;
            } else {
                xposText += value > 99 ? width*10/32 : width*4/32;
                xposIcon += value > 99 ? width*23/32 : width*17/32;
                textAlign |= Graphics.TEXT_JUSTIFY_RIGHT;
            }
            dc.setColor(ClockView.colorMode ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xposIcon, ypos - 1, ClockView.iconFont as FontResource, icon as String, textAlign);
            dc.setColor(ClockView.colors[ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(xposText, ypos, font, value.format("%d"), textAlign);
            ret = true;
        }
        return ret;
    }

    // Draw the move bar, return true if it was drawn
    (:modern) private function drawMoveBar(
        dc as Dc,
        x as Number,
        y as Number,
        radius as Number,
        moveBarLevel as Number?
    ) as Boolean {
//      moveBarLevel = 5;
        var ret = false;
        if (moveBarLevel != null and moveBarLevel > 0) {
            var width = (0.10 * radius).toNumber();
            if (0 == width % 2) { width -= 1; } // make sure width is an odd number
            radius = (0.83 * radius).toNumber();
//          System.println("radius = " + radius + ", width = " + width);
            var angle = 152;
            var bar = 0;
            for (var i = 1; i <= moveBarLevel; i++) {
                bar = i == 1 ? 36 : 18; // bar length in degrees
        	    dc.setColor(ClockView.colorMode ? Graphics.COLOR_DK_BLUE : Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(width);
                dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, angle, angle-bar);

                var color = (1 == i or 3 == i) ? ClockView.C_FOREGROUND : ClockView.C_BACKGROUND;
        		dc.setColor(ClockView.colors[color], Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
                dc.fillPolygon(arrowPoints(x, y, radius, width, angle));

		    	angle = angle - bar - 3;
            }
            // Draw the arrow tips in a second loop, so they are drawn over the background color arrow tails 
            angle = 152;
        	dc.setColor(ClockView.colorMode ? Graphics.COLOR_DK_BLUE : Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
//          dc.setColor(ClockView.colorMode ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
            for (var i = 1; i <= moveBarLevel; i++) {
                bar = i == 1 ? 36 : 18; // bar length in degrees
                dc.setPenWidth(1);
                dc.fillPolygon(arrowPoints(x, y, radius, width, angle-bar));

		    	angle = angle - bar - 3;
            }
            ret = true;
        }
        return ret;
    }

    // Compute the coordinates of the rotated polygon used for the tails and tips of the move bar arcs
    (:modern) private function arrowPoints(
        x as Number,
        y as Number,
        radius as Numeric, 
        width as Numeric, 
        angle as Numeric
    ) as Array<Point2D> {
        var pts = new Array<Point2D>[4];
        var r = (radius - width/2).toNumber();
        var beta = (180 - angle).toFloat() / 180.0 * Math.PI;
        var cos = Math.cos(beta);
        var sin = Math.sin(beta);
        pts[0] = [(x - r * cos + 0.5).toNumber(), (y - r * sin + 0.5).toNumber()];
        beta = (180 - angle - 1).toFloat() / 180.0 * Math.PI;
        pts[1] = [(x - radius * Math.cos(beta) + 0.5).toNumber(), (y - radius * Math.sin(beta) + 0.5).toNumber()];
        r = (radius + width/2 + 0.5).toNumber();
        pts[2] = [(x - r * cos + 0.5).toNumber(), (y - r * sin + 0.5).toNumber()];
        beta = (180 - angle + 4).toFloat() / 180.0 * Math.PI;
        pts[3] = [(x - radius * Math.cos(beta) + 0.5).toNumber(), (y - radius * Math.sin(beta) + 0.5).toNumber()];

        return pts;
    }

} // class Indicators

class BatteryLevel {
    private var _mRadius as Number;
    private var _cPw as Number;
    private var _cBw as Number;
    private var _cBh as Number;
    private var _cTs as Number;
    private var _cCw as Number;
    private var _cCh as Number;
    private var _cWidth as Number;
    private var _cHeight as Number;
    private var _cT1 as Number;
    private var _cT2 as Number;
    private var _cT3 as Number;

    public function initialize(clockRadius as Number) {
        // Radius of the modern battery indicator circle in pixels
        _mRadius = (3.2 * clockRadius / 50.0 + 0.5).toNumber();
        // Dimensions of the classic battery level indicator in pixels, calculated from percentages of the clock diameter
        _cPw = (1.2 * clockRadius / 50.0 + 0.5).toNumber(); // pen size for the battery rectangle 
        if (0 == _cPw % 2) { _cPw += 1; }                   // make sure pen size is an odd number
        _cBw = (1.9 * clockRadius / 50.0 + 0.5).toNumber(); // width of the battery level segments
        _cBh = (4.2 * clockRadius / 50.0 + 0.5).toNumber(); // height of the battery level segments
        _cTs = (0.4 * clockRadius / 50.0 + 0.5).toNumber(); // tiny space around everything
        _cCw = _cPw;                                        // width of the little knob on the right side of the battery
        _cCh = (2.3 * clockRadius / 50.0 + 0.5).toNumber(); // height of the little knob
        _cWidth = 5*_cBw + 6*_cTs + _cPw+1;
        _cHeight = _cBh + 2*_cTs + _cPw+1;
        if (1 == _cHeight % 2 and 0 == _cCh % 2) { _cCh += 1; } // make sure both, the battery rectangle height and the knob 
        if (0 == _cHeight % 2 and 1 == _cCh % 2) { _cCh += 1; } // height, are odd, or both are even
        _cT1 = (_cPw-1)/2;
        _cT2 = _cT1 + 1 + _cTs;
        _cT3 = _cHeight/2;
    }

    // Draw the battery indicator according to the settings, return true if it was actually drawn, else false
    public function draw(
        dc as Dc, 
        xpos as Number, 
        ypos as Number
    ) as Boolean {
        var ret = false;
        var batterySetting = config.getOption(Config.I_BATTERY);
        var systemStats = System.getSystemStats();
        var level = systemStats.battery;
        var levelInDays = 0.0;
        var warnLevel = 40.0; // Default is 40%
        if (systemStats has :batteryInDays ) { // since API Level 3.3.0
            levelInDays = systemStats.batteryInDays;
/* Ursli didn't like this
            warnLevel = level / levelInDays * 6.0; // If the device has battery in days, use 6 days
 */
        }
        var levelColor = Graphics.COLOR_GREEN;
        if (level < warnLevel / 2) { levelColor = ClockView.M_LIGHT == ClockView.colorMode ? Graphics.COLOR_ORANGE : Graphics.COLOR_YELLOW; }
        if (level < warnLevel / 4) { levelColor = Graphics.COLOR_RED; }

        // level \ Setting   Classic ClassicWarnings Modern ModernWarnings
        // < warnLevel          C          C           M          M       
        // >= warnLevel         C          -           M          -       
        if (   :BatteryClassic == batterySetting 
            or (level < warnLevel and :BatteryClassicWarnings == batterySetting)) {
            var frameColor = [Graphics.COLOR_LT_GRAY, Graphics.COLOR_DK_GRAY] as Array<Number>;
            drawClassicBatteryIndicator(dc, xpos, ypos, level, levelInDays, frameColor[ClockView.colorMode], levelColor, ClockView.colors[ClockView.C_TEXT]);
            ret = true;
        } else if (   :BatteryModern == batterySetting
                   or (level < warnLevel and :BatteryModernWarnings == batterySetting)) {
            drawModernBatteryIndicator(dc, xpos, ypos, level, levelInDays, levelColor, ClockView.colors[ClockView.C_TEXT]);
            ret = true;
        }
        return ret;
    }

    // Very simple battery indicator showing just a colored dot
    private function drawModernBatteryIndicator(
        dc as Dc,
        xpos as Number, 
        ypos as Number, 
        level as Float, 
        levelInDays as Float, 
        levelColor as Number,
        textColor as Number
    ) as Void {
        dc.setColor(levelColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xpos, ypos, _mRadius);
        drawBatteryLabels(dc, xpos - _mRadius, xpos + _mRadius, ypos, level, levelInDays, textColor);
    }

    private function drawClassicBatteryIndicator(
        dc as Dc,
        xpos as Number, 
        ypos as Number, 
        level as Float, 
        levelInDays as Float, 
        frameColor as Number,
        levelColor as Number,
        textColor as Number
    ) as Void {
        // Draw the battery shape
        var x = xpos - _cWidth/2 + _cT1;
        var y = ypos - _cT3;
        dc.setColor(frameColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_cPw);
        dc.drawRoundedRectangle(x, y, _cWidth, _cHeight, _cPw);
        dc.setPenWidth(1);
        dc.fillRoundedRectangle(x + _cWidth + _cT1 + _cTs, y + _cT3 - _cCh/2, _cCw, _cCh, (_cCw-1)/2);

        // Draw battery level segments according to the battery level
        dc.setColor(levelColor, Graphics.COLOR_TRANSPARENT);
        var xb = x + _cT2;
        var yb = y + _cT2;
        var lv = (level + 0.5).toNumber();
        var fb = (lv / 20).toNumber();
        for (var i=0; i < fb; i++) {
            dc.fillRectangle(xb + i*(_cBw+_cTs), yb, _cBw, _cBh);
        }
        var bl = lv % 20 * _cBw / 20;
        if (bl > 0) {
            dc.fillRectangle(xb + fb*(_cBw+_cTs), yb, bl, _cBh);
        }

        drawBatteryLabels(dc, x - _cPw, x + _cWidth + _cT1 + _cCw, ypos, level, levelInDays, textColor);
    }

    // Draw battery labels for percentage and days depending on the settings
    private function drawBatteryLabels(
        dc as Dc,
        x1 as Number, 
        x2 as Number, 
        y as Number, 
        level as Float, 
        levelInDays as Float,
        textColor as Number
    ) as Void {
        var font = Graphics.FONT_XTINY;
        y += 1; // Looks better aligned on the actual device (fr955) like this
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        if (config.isEnabled(Config.I_BATTERY_PCT)) {
            var str = (level + 0.5).toNumber() + "% ";
            dc.drawText(x1, y - Graphics.getFontHeight(font)/2, font, str, Graphics.TEXT_JUSTIFY_RIGHT);
        }
        // Note: Whether the device provides battery in days is also ensured by getValue().
        if (config.isEnabled(Config.I_BATTERY_DAYS)) {
            var str = " " + (levelInDays + 0.5).toNumber() + WatchUi.loadResource(Rez.Strings.DayUnit);
            dc.drawText(x2, y - Graphics.getFontHeight(font)/2, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
} // class BatteryLevel
