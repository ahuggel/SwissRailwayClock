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

// Battery level indicator.
class BatteryLevel {

    private var _cd as ClockData;
    
    public function initialize() {
        _cd = ClockData.getInstance();
    }

    // Draw the battery indicator according to the settings, return true if it was actually drawn, else false
    public function draw(dc as Dc, xpos as Number, ypos as Number) as Boolean {
        var ret = false;
        var batterySetting = $.config.getValue($.Config.I_BATTERY);
        var systemStats = System.getSystemStats();
        var level = systemStats.battery;
        var levelInDays = 0.0;
        var warnLevel = 40.0; // Default is 40%
        if (systemStats has :batteryInDays ) { // since API Level 3.3.0
            levelInDays = systemStats.batteryInDays;
            warnLevel = level / levelInDays * 6.0; // If the device has battery in days, use 6 days
        }
        var color = Graphics.COLOR_GREEN;
        if (level < warnLevel / 2) { color = ClockData.M_LIGHT == _cd.colorMode ? Graphics.COLOR_ORANGE : Graphics.COLOR_YELLOW; }
        if (level < warnLevel / 4) { color = Graphics.COLOR_RED; }
        if (level < warnLevel) {
            switch (batterySetting) {
                case $.Config.O_BATTERY_CLASSIC:
                case $.Config.O_BATTERY_CLASSIC_WARN:
                    drawClassicBatteryIndicator(dc, xpos, ypos, level, levelInDays, color);
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
                    drawClassicBatteryIndicator(dc, xpos, ypos, level, levelInDays, color);
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
    private function drawModernBatteryIndicator(dc as Dc, xpos as Number, ypos as Number, level as Float, levelInDays as Float, color as Number) as Void {
        var radius = (3.2 * _cd.clockRadius / 50.0 + 0.5).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(xpos, ypos, radius);
        drawBatteryLabels(dc, xpos - radius, xpos + radius, ypos, level, levelInDays);
    }

    private function drawClassicBatteryIndicator(dc as Dc, xpos as Number, ypos as Number, level as Float, levelInDays as Float, color as Number) as Void {
        // Dimensions of the battery level indicator, based on percentages of the clock diameter
        var pw = (1.2 * _cd.clockRadius / 50.0 + 0.5).toNumber(); // pen size for the battery rectangle 
        if (0 == pw % 2) { pw += 1; }                          // make sure pw is an odd number
        var bw = (1.9 * _cd.clockRadius / 50.0 + 0.5).toNumber(); // width of the battery level segments
        var bh = (4.2 * _cd.clockRadius / 50.0 + 0.5).toNumber(); // height of the battery level segments
        var ts = (0.4 * _cd.clockRadius / 50.0 + 0.5).toNumber(); // tiny space around everything
        var cw = pw;                                           // width of the little knob on the right side of the battery
        var ch = (2.3 * _cd.clockRadius / 50.0 + 0.5).toNumber(); // height of the little knob

        // Draw the battery shape
        var width = 5*bw + 6*ts + pw+1;
        var height = bh + 2*ts + pw+1;
        var x = xpos - width/2 + pw/2;
        var y = ypos - height/2;
        var frameColor = [Graphics.COLOR_LT_GRAY, Graphics.COLOR_DK_GRAY] as Array<Number>;
        dc.setColor(frameColor[_cd.colorMode], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw);
        dc.drawRoundedRectangle(x, y, width, height, pw);
        dc.setPenWidth(1);
        if (1 == height % 2 and 0 == ch % 2) { ch += 1; }      // make sure both, the battery rectangle height and the knob 
        if (0 == height % 2 and 1 == ch % 2) { ch += 1; }      // height, are odd, or both are even
        dc.fillRoundedRectangle(x + width + (pw-1)/2 + ts, y + height/2 - ch/2, cw, ch, (cw-1)/2);

        // Draw battery level segments according to the battery level
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var lv = (level + 0.5).toNumber();
        var xb = x + (pw-1)/2 + 1 + ts;
        var yb = y + (pw-1)/2 + 1 + ts;
        var fb = (lv/20).toNumber();
        for (var i=0; i < fb; i++) {
            dc.fillRectangle(xb + i*(bw+ts), yb, bw, bh);
        }
        var bl = lv % 20 * bw / 20;
        if (bl > 0) {
            dc.fillRectangle(xb + fb*(bw+ts), yb, bl, bh);
        }

        drawBatteryLabels(dc, x - pw, x + width + (pw-1)/2 + cw, ypos, level, levelInDays);
    }

    // Draw battery labels for percentage and days depending on the settings
    private function drawBatteryLabels(dc as Dc, x1 as Number, x2 as Number, y as Number, level as Float, levelInDays as Float) as Void {
        var font = Graphics.FONT_XTINY;
        dc.setColor(_cd.colors[_cd.colorMode][ClockData.C_TEXT], Graphics.COLOR_TRANSPARENT);
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

// Alarm, notification and phone connection indicators
class SimpleIndicators {

    private var _cd as ClockData;
    
    public function initialize() {
        _cd = ClockData.getInstance();
    }

    // Draw alarm and notification symbols, return true if something was drawn, else false
    public function drawSymbols(dc as Dc, xpos as Number, ypos as Number) as Boolean {
        var icons = "";
        var space = "";
        var indicators = [
            $.Config.O_ALARMS_ON == $.config.getValue($.Config.I_ALARMS) and _cd.alarmCount > 0, 
            $.Config.O_NOTIFICATIONS_ON == $.config.getValue($.Config.I_NOTIFICATIONS) and _cd.notificationCount > 0
        ];
        for (var i = 0; i < indicators.size(); i++) {
            if (indicators[i]) {
                icons += space + ["A", "M"][i];
                space = " ";
            }
        }
        var ret = false;
        if (!(icons as String).equals("")) { // Why does the typechecker not know that icons is a String??
            dc.setColor(_cd.colors[_cd.colorMode][ClockData.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(xpos, ypos, _cd.iconFont as FontReference, icons as String, Graphics.TEXT_JUSTIFY_CENTER);
            ret = true;
        }
        return ret;
    }

    // Draw the Bluetooth symbol when the watch is connected to a phone, return true if something was drawn
    public function drawPhoneConnected(dc as Dc, xpos as Number, ypos as Number) as Boolean {
        var ret = false;
        if (_cd.phoneConnected) {
            dc.setColor(_cd.colors[_cd.colorMode][ClockData.C_BLUETOOTH], Graphics.COLOR_TRANSPARENT);
            dc.drawText(xpos, ypos, _cd.iconFont as FontReference, "B" as String, Graphics.TEXT_JUSTIFY_CENTER);
            ret = true;
        }
        return ret;
    }
} // class IndicatorSymbols

// A heart rate indicator.
class HeartRate {

    private const FONT as Graphics.FontDefinition = Graphics.FONT_TINY;

    private var _cd as ClockData;
    private var _width as Number; // Indicator width
    
    // Constructor. Called with the view and the center coordinates where the indicator should be drawn
    public function initialize() {
        _cd = ClockData.getInstance();
        _width = (Graphics.getFontHeight(FONT) * 2.1).toNumber();
    }

    // Draw the heart rate if it is available, return true if it was drawn
    public function draw(dc as Dc, xpos as Number, ypos as Number) as Boolean {
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
            var hr = heartRate.format("%d");
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                heartRate > 99 ? xpos - _width*2/16 - 1 : xpos, ypos, 
                _cd.iconFont as FontReference, 
                _cd.isAwake ? "H" : "I" as String, 
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            dc.setColor(_cd.colors[_cd.colorMode][ClockData.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                xpos + _width/2, 
                ypos, 
                FONT, 
                hr, 
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER
            );
            ret = true;
        }
        return ret;
    }
} // class HeartRate
