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
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Class to draw all the indicators depending on the menu settings at the correct place on the watchface.
// The distinction between modern and legacy devices is mostly because some of the latter are very memory
// constrained. Consequently, not all indicators are available on legacy devices and the implementation
// is optimized to limit the memory use.
class Indicators {
    (:legacy)
    private var _width as Number;
    (:legacy)
    private var _height as Number;
    (:legacy)
    private var _phoneConnectedY as Number = 0;

    private var _batteryLevel as BatteryLevel;
    private var _symbolsDrawn as Boolean = false;

    (:modern)
    private var _batteryDrawn as Boolean = false;
    (:modern)
    private var _drawHeartRate as Number = -1;
    (:modern)
    private var _pos as Array< Array<Number> >; // Positions (x,y) of the indicators

    // Constructor
    (:modern)
    public function initialize(width as Number, height as Number, clockRadius as Number) {
        _batteryLevel = new BatteryLevel(clockRadius);

        // Positions of the various indicators
        _pos = [
            [(width * 0.73).toNumber(), (height * 0.50).toNumber()],       //  0: Heart rate indicator at 3 o'clock
            [(width * 0.48).toNumber(), (height * 0.75).toNumber()],       //  1: Heart rate indicator at 6 o'clock
            [(width * 0.23).toNumber(), (height * 0.50).toNumber()],       //  2: Recovery time indicator at 9 o'clock
            [(width * 0.50).toNumber(), (height * 0.32).toNumber()], //  3: Battery level indicator at 12 o'clock with notifications
            [(width * 0.50).toNumber(), (height * 0.25).toNumber()], //  4: Battery level indicator at 12 o'clock w/o notifications
            [(width * 0.50).toNumber(), (height * 0.18).toNumber()],       //  5: Alarms and notifications at 12 o'clock
            [0.0, 0.0],                                                    //  6: Phone connection indicator on the 6 o'clock tick mark (see updatePos() )
            [(width * 0.75).toNumber(), (height * 0.50 - Graphics.getFontHeight(Graphics.FONT_MEDIUM)/2 - 1).toNumber()], // 7: Date (day format) at 3 o'clock
            [(width * 0.50).toNumber(), (height * 0.65).toNumber()],       //  8: Date (weekday and day format) at 6 o'clock, w/o steps
            [(width * 0.50).toNumber(), (height * 0.69).toNumber()],       //  9: Date (weekday and day format) at 6 o'clock, with steps
            [(width * 0.49).toNumber(), (height * 0.70).toNumber()],       // 10: Steps at 6 o'clock, w/o date (weekday and day format)
            [(width * 0.49).toNumber(), (height * 0.65).toNumber()],       // 11: Steps at 6 o'clock, with date (weekday and day format)
            [(width * 0.49).toNumber(), (height * 0.76).toNumber()]        // 12: Heart rate indicator at 6 o'clock with steps
        ] as Array< Array<Number> >;
    }

    (:legacy)
    public function initialize(width as Number, height as Number, clockRadius as Number) {
        _width = width;
        _height = height;
        _batteryLevel = new BatteryLevel(clockRadius);
    }

    // Update any indicator positions, which depend on numbers that are not available yet when the constructor is called
    (:modern)
    public function updatePos(width as Number, height as Number, s0 as Float, s3 as Float) as Void {
        _pos[6] = [(width * 0.50).toNumber(), (height * 0.50 + s3 + (s0 - Graphics.getFontHeight(ClockView.iconFont as FontResource))/3).toNumber()];
    }

    (:legacy)
    public function updatePos(s0 as Float, s3 as Float) as Void {
        _phoneConnectedY = (_height * 0.50 + s3 + (s0 - Graphics.getFontHeight(ClockView.iconFont as FontResource))/3).toNumber();
    }

    // Draw all the indicators, which are updated once a minute (all except the heart rate).
    // The legacy version checks settings and determines positions within the draw() function itself.
    (:legacy)
    public function draw(dc as Dc, deviceSettings as DeviceSettings) as Void {
        var activityInfo = ActivityMonitor.getInfo();
        var w2 = (_width * 0.50).toNumber();

        // Draw alarm and notification indicators
        _symbolsDrawn = false;
        if (   $.Config.O_ALARMS_ON == $.config.getValue($.Config.I_ALARMS)
            or $.Config.O_NOTIFICATIONS_ON == $.config.getValue($.Config.I_NOTIFICATIONS)) {
            _symbolsDrawn = drawSymbols(
                dc,
                w2, 
                (_height * 0.18).toNumber(), 
                deviceSettings.alarmCount,
                deviceSettings.notificationCount
            );
        }

        // Draw the battery level indicator
        if ($.config.getValue($.Config.I_BATTERY) > $.Config.O_BATTERY_OFF) {
            _batteryLevel.draw(
                dc,
                w2, 
                _symbolsDrawn ? (_height * 0.32).toNumber() : (_height * 0.25).toNumber()
            );
        }

        // Draw the date string
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        dc.setColor(ClockView.colors[ClockView.colorMode][ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
        switch ($.config.getValue($.Config.I_DATE_DISPLAY)) {
            case $.Config.O_DATE_DISPLAY_DAY_ONLY: 
                dc.drawText(
                    (_width * 0.75).toNumber(), 
                    (_height * 0.50 - Graphics.getFontHeight(Graphics.FONT_MEDIUM)/2 - 1).toNumber(), 
                    Graphics.FONT_MEDIUM, 
                    info.day.format("%02d"), 
                    Graphics.TEXT_JUSTIFY_CENTER
                );
                break;
            case $.Config.O_DATE_DISPLAY_WEEKDAY_AND_DAY:
                dc.drawText(
                    w2, 
                    (_height * 0.65).toNumber(), 
                    Graphics.FONT_MEDIUM, 
                    Lang.format("$1$ $2$", [info.day_of_week, info.day]), 
                    Graphics.TEXT_JUSTIFY_CENTER
                );
                break;
        }

        // Draw the phone connection indicator on the 6 o'clock tick mark
        if ($.Config.O_CONNECTED_ON == $.config.getValue($.Config.I_CONNECTED)) { 
            drawPhoneConnected(
                dc,
                w2,
                _phoneConnectedY,
                deviceSettings.phoneConnected
            );
        }

        // Draw the heart rate indicator
        if ($.Config.O_HEART_RATE_ON == $.config.getValue($.Config.I_HEART_RATE)) {
            var xpos = (_width * 0.73).toNumber();
            var ypos = (_height * 0.50).toNumber();
            if ($.Config.O_DATE_DISPLAY_DAY_ONLY == $.config.getValue($.Config.I_DATE_DISPLAY)) {
                xpos = (_width * 0.48).toNumber();
                ypos = (_height * 0.75).toNumber();
            }
            drawHeartRate2(dc, xpos, ypos);
            dc.clearClip();
        }

        // Draw the recovery time indicator
        if ($.Config.O_RECOVERY_TIME_ON == $.config.getValue($.Config.I_RECOVERY_TIME)) { 
            if (ActivityMonitor.Info has :timeToRecovery) {
                drawRecoveryTime(
                    dc,
                    (_width * 0.23).toNumber(),
                    (_height * 0.50).toNumber(),
                    activityInfo.timeToRecovery
                );
            }
        }
    }

    // Draw all the indicators, which are updated once a minute (all except the heart rate).
    // The modern version uses a helper function to determine if and where each indicator is drawn.
    (:modern)
    public function draw(dc as Dc, deviceSettings as DeviceSettings) as Void {
        var activityInfo = ActivityMonitor.getInfo();

        // Draw alarm and notification indicators
        _symbolsDrawn = false;
        var idx = -1;
        idx = getIndicatorPosition(:symbols);
        if (-1 != idx) {
            _symbolsDrawn = drawSymbols(
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
        dc.setColor(ClockView.colors[ClockView.colorMode][ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
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

        // Determine if and where the heart rate should be drawn
        _drawHeartRate = getIndicatorPosition(:heartRate);

        // Draw the recovery time indicator
        idx = getIndicatorPosition(:recoveryTime);
        if (-1 != idx) {
            if (ActivityMonitor.Info has :timeToRecovery) {
                drawRecoveryTime(
                    dc,
                    _pos[idx][0],
                    _pos[idx][1],
                    activityInfo.timeToRecovery
                );
            }
        }

        // Draw the steps indicator
        idx = getIndicatorPosition(:footsteps);
        if (-1 != idx) {
            if (ActivityMonitor.Info has :steps) {
                drawSteps(
                    dc,
                    _pos[idx][0],
                    _pos[idx][1],
                    activityInfo.steps
                );
            }
        }
    }

    // Draw the heart rate if it is available, return true if it was drawn.
    // Modern devices call this every few seconds, also when the watch is not awake.
    (:modern)
    public function drawHeartRate(dc as Dc) as Boolean {
        return -1 == _drawHeartRate ? false : drawHeartRate2(dc, _pos[_drawHeartRate][0], _pos[_drawHeartRate][1]);
    }

    // Determine if a given indicator should be shown and its position on the screen. 
    // This function exists to have all decisions regarding indicator placing, some of which are 
    // interdependent, in one place.
    // The position returned is an index into _pos. -1 means the indicator should not be drawn.
    (:modern)
    private function getIndicatorPosition(indicator as Symbol) as Number {
        var idx = -1;
        switch (indicator) {
            case :recoveryTime:
                if ($.Config.O_RECOVERY_TIME_ON == $.config.getValue($.Config.I_RECOVERY_TIME)) { 
                    idx = 2; 
                }
                break;
            case :battery:
                if ($.config.getValue($.Config.I_BATTERY) > $.Config.O_BATTERY_OFF) {
                   idx = _symbolsDrawn ? 3 : 4;
                }
                break;
            case :symbols:
                if (   $.Config.O_ALARMS_ON == $.config.getValue($.Config.I_ALARMS)
                    or $.Config.O_NOTIFICATIONS_ON == $.config.getValue($.Config.I_NOTIFICATIONS)) {
                    idx = 5;
                }
                break;
            case :phoneConnected:
                if ($.Config.O_CONNECTED_ON == $.config.getValue($.Config.I_CONNECTED)) { 
                    idx = 6; 
                }
                break;
            case :shortDate:
                if ($.Config.O_DATE_DISPLAY_DAY_ONLY == $.config.getValue($.Config.I_DATE_DISPLAY)) { 
                    idx = 7; 
                }
                break;
            case :longDate:
                if ($.Config.O_DATE_DISPLAY_WEEKDAY_AND_DAY == $.config.getValue($.Config.I_DATE_DISPLAY)) {
                    idx = ($.Config.O_STEPS_ON == $.config.getValue($.Config.I_STEPS) and _batteryDrawn) ? 9 : 8;
                }
                break;
            case :heartRate:
                if ($.Config.O_HEART_RATE_ON == $.config.getValue($.Config.I_HEART_RATE)) {
                    idx = 0;
                    if ($.Config.O_DATE_DISPLAY_DAY_ONLY == $.config.getValue($.Config.I_DATE_DISPLAY)) {
                        idx = ($.Config.O_STEPS_ON == $.config.getValue($.Config.I_STEPS)) ? 12 : 1;
                    }
                }
                break;
            case :footsteps:
                /*
                   Date display Heart rate Steps Positions
                   ------------ ---------- ----- ---------
                   Off          Off        Off    -  -  -
                   Off          Off        On     -  - 10
                   Off          On         Off    -  0  -
                   Off          On         On     -  0 10
                   Short        Off        Off    7  -  -
                   Short        Off        On     7  - 10
                   Short        On         Off    7  1  -
                   Short        On         On     7 12 11
                   Long         Off        Off    8  -  -
                   Long         Off        On     9  - 11 or 3
                   Long         On         Off    8  0  -
                   Long         On         On     9  0 11 or 3

                   Positions
                   ---------
                    0: Heart rate indicator at 3 o'clock
                    1: Heart rate indicator at 6 o'clock
                    2: Recovery time indicator at 9 o'clock
                    3: Battery level indicator at 12 o'clock with notifications
                    4: Battery level indicator at 12 o'clock w/o notifications
                    5: Alarms and notifications at 12 o'clock
                    6: Phone connection indicator on the 6 o'clock tick mark
                    7: Date (day format) at 3 o'clock
                    8: Date (weekday and day format) at 6 o'clock, w/o steps
                    9: Date (weekday and day format) at 6 o'clock, with steps
                   10: Steps at 6 o'clock, w/o date (weekday and day format)
                   11: Steps at 6 o'clock, with date (weekday and day format)
                   12: Heart rate indicator at 6 o'clock with steps
                */
                if ($.Config.O_STEPS_ON == $.config.getValue($.Config.I_STEPS)) {
                    if ($.Config.O_DATE_DISPLAY_WEEKDAY_AND_DAY == $.config.getValue($.Config.I_DATE_DISPLAY)) {
                        idx = _batteryDrawn ? 11 : 3;
                    } else if (    $.Config.O_DATE_DISPLAY_DAY_ONLY == $.config.getValue($.Config.I_DATE_DISPLAY)
                               and $.Config.O_HEART_RATE_ON == $.config.getValue($.Config.I_HEART_RATE)) {
                        idx = 11;
                    } else {
                        idx = 10;
                    }
                }
                break;
            default:
                System.println("ERROR: ClockView.getIndicatorPos() is not implemented for indicator = " + indicator);
                break;
        }
        return idx;
    }

    // Draw the heart rate if it is available, return true if it was drawn.
    // This private function is used by both, the legacy and modern code.
    private function drawHeartRate2(dc as Dc, xpos as Number, ypos as Number) as Boolean {
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

            dc.setClip(xpos - width*0.48, ypos - fontHeight*0.38, width, fontHeight*0.85);
            var bgColor = ClockView.colors[ClockView.colorMode][ClockView.C_BACKGROUND];
            dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
            dc.clear();
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                heartRate > 99 ? xpos - width*2/16 - 1 : xpos, ypos - 1, 
                ClockView.iconFont as FontResource, 
                ClockView.isAwake ? "H" : "I" as String, 
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(ClockView.colors[ClockView.colorMode][ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
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

    // Draw alarm and notification symbols, return true if something was drawn, else false
    private function drawSymbols(
        dc as Dc,
        xpos as Number, 
        ypos as Number, 
        alarmCount as Number,
        notificationCount as Number
    ) as Boolean {
        var icons = "";
        var space = "";
        var indicators = [
            $.Config.O_ALARMS_ON == $.config.getValue($.Config.I_ALARMS) and alarmCount > 0, 
            $.Config.O_NOTIFICATIONS_ON == $.config.getValue($.Config.I_NOTIFICATIONS) and notificationCount > 0
        ];
        for (var i = 0; i < indicators.size(); i++) {
            if (indicators[i]) {
                icons += space + ["A", "M"][i];
                space = " ";
            }
        }
        var ret = false;
        if (!(icons as String).equals("")) { // Why does the typechecker not know that icons is a String??
            dc.setColor(ClockView.colors[ClockView.colorMode][ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(xpos, ypos, ClockView.iconFont as FontResource, icons as String, Graphics.TEXT_JUSTIFY_CENTER);
            ret = true;
        }
        return ret;
    }

    // Draw the Bluetooth symbol when the watch is connected to a phone, return true if something was drawn
    private function drawPhoneConnected(
        dc as Dc,
        xpos as Number, 
        ypos as Number, 
        phoneConnected as Boolean
    ) as Boolean {
        var ret = false;
        var symbolColor = Graphics.COLOR_BLUE;
        var bgColor = ClockView.colors[ClockView.colorMode][ClockView.C_BACKGROUND];
        if (Graphics.COLOR_LT_GRAY == bgColor or Graphics.COLOR_WHITE == bgColor) {
            symbolColor = Graphics.COLOR_DK_BLUE;
        }
        if (phoneConnected) {
            dc.setColor(symbolColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xpos, ypos, ClockView.iconFont as FontResource, "B" as String, Graphics.TEXT_JUSTIFY_CENTER);
            ret = true;
        }
        return ret;
    }

    // Draw the recovery time, return true if it was drawn
    private function drawRecoveryTime(
        dc as Dc,
        xpos as Number, 
        ypos as Number,
        timeToRecovery as Number?
    ) as Boolean {
        var ret = false;
        if (timeToRecovery != null and timeToRecovery > 0) {
            //timeToRecovery = 85;
            //timeToRecovery = 123;
            var font = Graphics.FONT_TINY;
            var fontHeight = Graphics.getFontHeight(font);
            var width = (fontHeight * 2.1).toNumber(); // Indicator width
            var rt = timeToRecovery.format("%d");
            dc.setColor(ClockView.colors[ClockView.colorMode][ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                timeToRecovery > 99 ? xpos + width*10/32 : xpos + width*4/32, 
                ypos, 
                font, 
                rt,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(ClockView.colorMode ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                timeToRecovery > 99 ? xpos + width*23/32 : xpos + width*17/32, ypos - 1, 
                ClockView.iconFont as FontResource, 
                "R" as String, 
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            ret = true;
        }
        return ret;
    }

    // Draw the steps, return true if it was drawn
    (:modern)
    private function drawSteps(
        dc as Dc,
        xpos as Number, 
        ypos as Number,
        steps as Number?
    ) as Boolean {
        var ret = false;
        //steps = 123;
        //steps = 87654;
        //steps = 3456;
        if (steps != null and steps > 0) {
            var font = Graphics.FONT_TINY;
            var fontHeight = Graphics.getFontHeight(font);
            var width = (fontHeight * 2.1).toNumber(); // Indicator width
            var rt = steps.format("%d");
            dc.setColor(ClockView.colorMode ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                steps > 999 ? steps > 9999 ? xpos - width*22/32 : xpos - width*19/32 : xpos - width*16/32,
                ypos - 1, 
                ClockView.iconFont as FontResource, 
                "F" as String, 
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(ClockView.colors[ClockView.colorMode][ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                steps > 999 ? steps > 9999 ? xpos - width*9/32 : xpos - width*6/32 : xpos - width*3/32, 
                ypos, 
                font, 
                rt,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            ret = true;
        }
        return ret;
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
        var batterySetting = $.config.getValue($.Config.I_BATTERY);
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
        var color = Graphics.COLOR_GREEN;
        if (level < warnLevel / 2) { color = ClockView.M_LIGHT == ClockView.colorMode ? Graphics.COLOR_ORANGE : Graphics.COLOR_YELLOW; }
        if (level < warnLevel / 4) { color = Graphics.COLOR_RED; }
        if (level < warnLevel) {
            switch (batterySetting) {
                case $.Config.O_BATTERY_CLASSIC:
                case $.Config.O_BATTERY_CLASSIC_WARN:
                    drawClassicBatteryIndicator(dc, xpos, ypos, level, levelInDays, ClockView.colorMode, color);
                    ret = true;
                    break;
                case $.Config.O_BATTERY_MODERN:
                case $.Config.O_BATTERY_MODERN_WARN:
                case $.Config.O_BATTERY_HYBRID:
                    drawModernBatteryIndicator(dc, xpos, ypos, level, levelInDays, color);
                    ret = true;
                    break;
            }
        } else if (batterySetting >= $.Config.O_BATTERY_CLASSIC) {
            switch (batterySetting) {
                case $.Config.O_BATTERY_CLASSIC:
                case $.Config.O_BATTERY_HYBRID:
                    drawClassicBatteryIndicator(dc, xpos, ypos, level, levelInDays, ClockView.colorMode, color);
                    ret = true;
                    break;
                case $.Config.O_BATTERY_MODERN:
                    drawModernBatteryIndicator(dc, xpos, ypos, level, levelInDays, color);
                    ret = true;
                    break;
            }
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
        color as Number
    ) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xpos, ypos, _mRadius);
        drawBatteryLabels(dc, xpos - _mRadius, xpos + _mRadius, ypos, level, levelInDays);
    }

    private function drawClassicBatteryIndicator(
        dc as Dc,
        xpos as Number, 
        ypos as Number, 
        level as Float, 
        levelInDays as Float, 
        colorMode as Number,
        color as Number
    ) as Void {
        // Draw the battery shape
        var x = xpos - _cWidth/2 + _cT1;
        var y = ypos - _cT3;
        var frameColor = [Graphics.COLOR_LT_GRAY, Graphics.COLOR_DK_GRAY] as Array<Number>;
        dc.setColor(frameColor[colorMode], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_cPw);
        dc.drawRoundedRectangle(x, y, _cWidth, _cHeight, _cPw);
        dc.setPenWidth(1);
        dc.fillRoundedRectangle(x + _cWidth + _cT1 + _cTs, y + _cT3 - _cCh/2, _cCw, _cCh, (_cCw-1)/2);

        // Draw battery level segments according to the battery level
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
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

        drawBatteryLabels(dc, x - _cPw, x + _cWidth + _cT1 + _cCw, ypos, level, levelInDays);
    }

    // Draw battery labels for percentage and days depending on the settings
    private function drawBatteryLabels(
        dc as Dc,
        x1 as Number, 
        x2 as Number, 
        y as Number, 
        level as Float, 
        levelInDays as Float
    ) as Void {
        var font = Graphics.FONT_XTINY;
        y += 1; // Looks better aligned on the actual device (fr955) like this
        dc.setColor(ClockView.colors[ClockView.colorMode][ClockView.C_TEXT], Graphics.COLOR_TRANSPARENT);
        if ($.Config.O_BATTERY_PCT_ON == $.config.getValue($.Config.I_BATTERY_PCT)) {
            var str = (level + 0.5).toNumber() + "% ";
            dc.drawText(x1, y - Graphics.getFontHeight(font)/2, font, str, Graphics.TEXT_JUSTIFY_RIGHT);
        }
        // Note: Whether the device provides battery in days is also ensured by getValue().
        if ($.Config.O_BATTERY_DAYS_ON == $.config.getValue($.Config.I_BATTERY_DAYS)) {
            var str = " " + (levelInDays + 0.5).toNumber() + WatchUi.loadResource(Rez.Strings.DayUnit);
            dc.drawText(x2, y - Graphics.getFontHeight(font)/2, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
} // class BatteryLevel
