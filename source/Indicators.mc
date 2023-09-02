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
import Toybox.WatchUi;

// Draw alarm and notification symbols, return true if something was drawn, else false
function drawSymbols(
    dc as Dc, 
    xpos as Number, 
    ypos as Number, 
    textColor as Number,
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
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xpos, ypos, ClockView.iconFont as FontResource, icons as String, Graphics.TEXT_JUSTIFY_CENTER);
        ret = true;
    }
    return ret;
}

// Draw the Bluetooth symbol when the watch is connected to a phone, return true if something was drawn
function drawPhoneConnected(
    dc as Dc, 
    xpos as Number, 
    ypos as Number, 
    bgColor as Number, 
    phoneConnected as Boolean
) as Boolean {
    var ret = false;
    var symbolColor = Graphics.COLOR_BLUE;
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
// TODO: Combine this into an ActivityIndicators class, with drawHeartRate for synergies?
function drawRecoveryTime(
    dc as Dc, 
    xpos as Number, 
    ypos as Number,
    colorMode as Number,
    textColor as Number
) as Boolean {
    var ret = false;
    var timeToRecovery = null;
    var info = ActivityMonitor.getInfo();
    if (ActivityMonitor.Info has :timeToRecovery) {
        timeToRecovery = info.timeToRecovery;
    }
    if (timeToRecovery != null and timeToRecovery > 0) {
        //timeToRecovery = 85;
        //timeToRecovery = 123;
        var font = Graphics.FONT_TINY;
        var fontHeight = Graphics.getFontHeight(font);
        var width = (fontHeight * 2.1).toNumber(); // Indicator width
        var rt = timeToRecovery.format("%d");
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            timeToRecovery > 99 ? xpos + width*10/32 : xpos + width*4/32, 
            ypos, 
            font, 
            rt,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(colorMode ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
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

// Draw the heart rate if it is available, return true if it was drawn
function drawHeartRate(
    dc as Dc, 
    xpos as Number, 
    ypos as Number, 
    isAwake as Boolean, 
    textColor as Number, 
    bgColor as Number
) as Boolean {
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
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            heartRate > 99 ? xpos - width*2/16 - 1 : xpos, ypos - 1, 
            ClockView.iconFont as FontResource, 
            isAwake ? "H" : "I" as String, 
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
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

class BatteryLevel {
    private var _textColor as Number;
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
        _textColor = Graphics.COLOR_TRANSPARENT;
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
        ypos as Number,
        isAwake as Boolean,
        colorMode as Number,
        textColor as Number,
        bgColor as Number
    ) as Boolean {
        _textColor = textColor;
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
        if (level < warnLevel / 2) { color = ClockView.M_LIGHT == colorMode ? Graphics.COLOR_ORANGE : Graphics.COLOR_YELLOW; }
        if (level < warnLevel / 4) { color = Graphics.COLOR_RED; }
        if (level < warnLevel) {
            switch (batterySetting) {
                case $.Config.O_BATTERY_CLASSIC:
                case $.Config.O_BATTERY_CLASSIC_WARN:
                    drawClassicBatteryIndicator(dc, xpos, ypos, level, levelInDays, colorMode, color);
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
                    drawClassicBatteryIndicator(dc, xpos, ypos, level, levelInDays, colorMode, color);
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
        dc.setColor(_textColor, Graphics.COLOR_TRANSPARENT);
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
