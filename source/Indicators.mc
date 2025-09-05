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
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Class to draw all the indicators depending on the menu settings at the correct place on the watchface.
// Legacy devices have a fixed number of indicators, while modern and amoled devices have four 
// complications, which can each show one of a list of indicators. 
// Modern devices use a lookup-array of positions for different things and a dedicated function in which
// the decision is made if and where to draw a given indicator - a more maintainable design. 
// Legacy devices have all of this jumbled up in a single function that orchestrates the drawing. It's a
// bit less critical for these, as they support a limited number of indicators, so there are fewer 
// interdependencies for the positions and it's necessary to minimize memory usage.
class Indicators {
    private var _batteryLevel as BatteryLevel;
    private var _width as Number;
    private var _height as Number;

    (:modern) private var _batteryDrawn as Boolean = false;
    (:modern) private var _iconsDrawn as Boolean = false;
    (:modern) private var _complication2Drawn as Boolean = false;
    (:modern) private var _hrat6 as Boolean = false;
    (:modern) private var _dtat6 as Boolean = false;
    (:modern) private var _screenCenter as Array<Number>;
    (:modern) private var _clockRadius as Number;
    (:modern) private var _drawHeartRate as Number = -1;
    (:modern) private var _pos as Array< Array<Number> >; // Positions (x,y) of the indicators

    (:legacy) private var _phoneConnectedY as Number = 0;

    // Constructor
    (:modern) public function initialize(
        width as Number, 
        height as Number, 
        screenCenter as Array<Number>,
        clockRadius as Number
    ) {
        _width = width;
        _height = height;
        _screenCenter = screenCenter;
        _clockRadius = clockRadius;
        _batteryLevel = new BatteryLevel(clockRadius);
        // Most displays are round, but two supported watches have rectangular displays with height > width, which results in top and bottom borders
        var b = (height-width)/2; 

        // Positions of the various indicators
        _pos = [
            [(width * 0.73).toNumber(), (b + width * 0.50).toNumber()], //  0: 4th complication at 3 o'clock
            [(width * 0.50).toNumber(), (b + width * 0.75).toNumber()], //  1: 4th complication at 6 o'clock
            [(width * 0.27).toNumber(), (b + width * 0.50).toNumber()], //  2: 3rd complication at 9 o'clock
            [(width * 0.50).toNumber(), (b + width * 0.30).toNumber()], //  3: Battery level indicator at 12 o'clock with notifications
            [(width * 0.50).toNumber(), (b + width * 0.25).toNumber()], //  4: Battery level indicator at 12 o'clock w/o notifications
            [(width * 0.50).toNumber(), (b + width * 0.165).toNumber()],//  5: Alarms and notifications at 12 o'clock
            [0, 0],                                                     //  6: Phone connection indicator on the 6 o'clock tick mark (see updatePos() )
            [(width * 0.75).toNumber(), (b + width * 0.50 - Graphics.getFontHeight(Graphics.FONT_MEDIUM)/2 - 1).toNumber()], // 7: Date (day format) at 3 o'clock
            [(width * 0.50).toNumber(), (b + width * 0.65).toNumber()], //  8: Date (weekday and day format) at 6 o'clock, w/o steps
            [(width * 0.50).toNumber(), (b + width * 0.69).toNumber()], //  9: Date (weekday and day format) at 6 o'clock, with steps
            [(width * 0.50).toNumber(), (b + width * 0.70).toNumber()], // 10: 2nd complication at 6 o'clock, w/o date (weekday and day format)
            [(width * 0.50).toNumber(), (b + width * 0.65).toNumber()], // 11: 2nd complication at 6 o'clock, with date (weekday and day format)
            [(width * 0.50).toNumber(), (b + width * 0.76).toNumber()], // 12: 4th complication at 6 o'clock with steps
            [(width * 0.50).toNumber(), (b + width * 0.39).toNumber()], // 13: 1st complication in upper half, with notifications and battery
            [(width * 0.50).toNumber(), (b + width * 0.35).toNumber()]  // 14: 1st complication in upper half, w/o notifications but with battery
        ] as Array< Array<Number> >;
    }

    (:legacy) public function initialize(width as Number, height as Number, clockRadius as Number) {
        _width = width;
        _height = height;
        _batteryLevel = new BatteryLevel(clockRadius);
    }

    // Update any indicator positions, which depend on numbers that are not available yet when the constructor is called
    (:modern) public function updatePos(s0 as Float, s3 as Float) as Void {
        _pos[6] = [(_width * 0.50).toNumber(), (_height * 0.50 + s3 + (s0 - Graphics.getFontHeight(iconFont as FontResource))/3).toNumber()];
    }

    (:legacy) public function updatePos(s0 as Float, s3 as Float) as Void {
        _phoneConnectedY = (_height * 0.50 + s3 + (s0 - Graphics.getFontHeight(iconFont as FontResource))/3).toNumber();
    }

    // Draw all indicators. The legacy version checks settings and determines positions within this function as well.
    (:legacy) public function draw(dc as Dc, deviceSettings as DeviceSettings, isAwake as Boolean) as Void {
        var activityMonitorInfo = ActivityMonitor.getInfo();
        var w2 = (_width * 0.50).toNumber();
        var iconsDrawn = false;
        var batteryDrawn = false;
        var stepsDrawn = false;
        var indicatorColor = config.colors[Config.C_INDICATOR];

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
        dc.setColor(config.colors[Config.C_TEXT], Graphics.COLOR_TRANSPARENT);
        var dateDisplay = config.getOption(Config.I_DATE_DISPLAY);
        if (:DateDisplayDayOnly == dateDisplay) {
            dc.drawText(
                (_width * 0.75).toNumber(), // idx = 7
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
                w2, // idx = 6
                _phoneConnectedY,
                deviceSettings.phoneConnected
            );
        }

        // Draw the heart rate indicator
        if (config.isEnabled(Config.I_HEART_RATE)) {
            var w = 0.73; // idx = 0
            var h = 0.50;
            if (:DateDisplayDayOnly == dateDisplay) {
                w = 0.50; // idx = 1, 12
                if (config.isEnabled(Config.I_STEPS)) {
                    h = 0.76; // idx = 12
                } else {
                    h = 0.75; // idx = 1
                }
            }
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
            drawIndicator(
                dc,
                (_width * w).toNumber(),
                (_height * h).toNumber(),
                config.colors[Config.C_HEART_RATE],
                isAwake ? "H" : "I", 
                heartRate
            );
        }

        // Draw the recovery time indicator
        if (config.isEnabled(Config.I_RECOVERY_TIME) and ActivityMonitor.Info has :timeToRecovery) {
            drawIndicator(
                dc,
                (_width * 0.27).toNumber(), // idx = 2
                (_height * 0.50).toNumber(),
                indicatorColor,
                "R", 
                activityMonitorInfo.timeToRecovery
            );
        }

        // Helper - is the heart rate indicator at 6 o'clock?
        var hrat6 =     :DateDisplayDayOnly == dateDisplay
                    and config.isEnabled(Config.I_HEART_RATE);
        // Helper - is the (long) date at 6 o'clock?
        var dtat6 = :DateDisplayWeekdayAndDay == dateDisplay;

        // Draw the steps indicator
        if (config.isEnabled(Config.I_STEPS)) {
            var h = 0.70; // idx = 10
            if (hrat6 or dtat6) {
                if (config.isEnabled(Config.I_CALORIES) or batteryDrawn) {
                    h = 0.65; // idx = 11
                } else {
                    h = 0.30; // idx = 3
                }
            } else {
                if (config.isEnabled(Config.I_CALORIES) and batteryDrawn and iconsDrawn) {
                    h = 0.65; // idx = 11
                } // else idx = 10
            }
            stepsDrawn = drawIndicator(
                dc,
                w2, // idx = 3, 10, 11
                (_height * h).toNumber(),
                indicatorColor,
                "F", 
                activityMonitorInfo.steps // since API Level 1.0.0
            );
        }

        // Draw the calories indicator
        if (config.isEnabled(Config.I_CALORIES)) {
            var h = 0.30; // idx = 3
            if (!stepsDrawn) { // place calories where steps would usually be
                if (hrat6 or dtat6) {
                    if (batteryDrawn) {
                        h = 0.65; // idx = 11
                    } // else idx = 3
                } else {
                    h = 0.70; // idx = 10
                }
            } else {
                // if steps are drawn, (mostly) place calories in the upper half of the screen.
                // Do not squeeze the calories in the upper half (13), if battery and icons are
                // on and only the steps are at the bottom. Instead, draw calories below steps 
                // at the bottom then (12).
                if (batteryDrawn) {
                    if (iconsDrawn) {
                        h = hrat6 or dtat6 ? 0.39 : 0.76; // idx = 13 : 12
                    } else {
                        h = 0.35; // idx = 14
                    }
                } // else idx = 3
            }
            drawIndicator(
                dc,
                w2, // idx = 3, 10, 11, 12, 13, 14
                (_height * h).toNumber(),
                indicatorColor,
                "C", 
                activityMonitorInfo.calories  // since API Level 1.0.0
            );
        }
    }

    // Draw a simple indicator, return true if it was drawn. Legacy version for a fixed number of indicators
    (:legacy) private function drawIndicator(
        dc as Dc,
        xpos as Number, 
        ypos as Number,
        color as ColorType,
        icon as String,
        value as Number?
    ) as Boolean {
        var ret = false;
        //value = "123";
        //value = "87654";
        //value = "3456";
        if (value != null and value > 0) {
            // Adjust the x-coordinate for the location of the indicator and the value
            var xpos2 = xpos;
            var w2 = _width / 2;
            if (xpos < w2) { // left align the indicator at 9 o'clock
                xpos2 += _width * -0.024;
            } else if (xpos > w2) { // right align the indicator at 3 o'clock
                var i = value > 9 ? value > 99 ? 2 : 1 : 0;            
                xpos2 += _width * [0.068, 0.019, -0.030][i];
            } else { // center the indicator if it is on the line from 12 o'clock - 6 o'clock
                var i = value > 9 ? value > 99 ? value > 999 ? value > 9999 ? 4 : 3 : 2 : 1 : 0;
                xpos2 += _width * [0.024, 0.000, -0.026, -0.048, -0.074][i];
            }
            // Draw the indicator symbol and its value
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                xpos2, 
                ypos - 1, 
                iconFont as FontResource, 
                icon + "~", 
                Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_RIGHT
            );
            dc.setColor(config.colors[Config.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                xpos2, 
                ypos, 
                Graphics.FONT_TINY,
                value.format("%d"), 
                Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_LEFT
            );
/*
            // Debug output
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(xpos, ypos - 1, 1);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(xpos2, ypos - 1, 1);
*/
            ret = true;
        }
        return ret;
    }

    // Draw all the indicators, which are updated when the watch is awake or once a minute 
    // (all except the heart rate).
    // The modern version uses a helper function to determine if and where each indicator is drawn.
    (:modern) public function draw(dc as Dc, deviceSettings as DeviceSettings) as Void {
        var activityMonitorInfo = ActivityMonitor.getInfo();

        // Helper - is the 4th complication at 6 o'clock?
        _hrat6 =     :DateDisplayDayOnly == config.getOption(Config.I_DATE_DISPLAY)
                 and config.isEnabled(Config.I_COMPLICATION_4);
        // Helper - is the (long) date at 6 o'clock?
        _dtat6 = :DateDisplayWeekdayAndDay == config.getOption(Config.I_DATE_DISPLAY);

        // Draw the move bar (at a fixed position, so we don't need getDataFieldPosition() here)
        if (config.isEnabled(Config.I_MOVE_BAR)) {
            drawMoveBar(dc, _screenCenter[0], _screenCenter[1], _clockRadius, activityMonitorInfo.moveBarLevel);
        }

        // Draw alarm and notification indicators
        _iconsDrawn = false;
        var idx = -1;
        idx = getDataFieldPosition(:dfIcons);
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
        idx = getDataFieldPosition(:dfBattery);
        if (-1 != idx) {
            _batteryDrawn = _batteryLevel.draw(
                dc,
                _pos[idx][0], 
                _pos[idx][1]
            );
        }

        // Draw the date string
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        dc.setColor(config.colors[Config.C_TEXT], Graphics.COLOR_TRANSPARENT);
        idx = getDataFieldPosition(:dfLongDate);
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
            idx = getDataFieldPosition(:dfShortDate);
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
        idx = getDataFieldPosition(:dfPhoneConnected);
        if (-1 != idx) {
            drawPhoneConnected(
                dc,
                _pos[idx][0],
                _pos[idx][1],
                deviceSettings.phoneConnected
            );
        }

        // Draw the complications
        _drawHeartRate = -1;
        _complication2Drawn = false;
        var dataField = [:dfComplication1, :dfComplication2, :dfComplication3, :dfComplication4];
        var complicationId = [Config.I_COMPLICATION_1, Config.I_COMPLICATION_2, Config.I_COMPLICATION_3, Config.I_COMPLICATION_4];
        var indicatorColor = config.colors[Config.C_INDICATOR];
        for (var i = 3; i >= 0; i--) {
            idx = getDataFieldPosition(dataField[i]);
            if (-1 != idx) {
                var ret = false;
                var option = config.getOption(complicationId[i]) as Symbol;
                if (:HeartRate == option) {
                    // Determine if and where the heart rate should be drawn, but don't
                    // draw it here. The indicator is drawn in drawHeartRate(), which
                    // needs to be called after this function, once the position is set.
                    // This is done to minimize the work necessary in drawHeartRate(), 
                    // as that is also called in low-power mode, from onPartialUpdate(),
                    // when the position always remains the same.
                    _drawHeartRate = idx;
                    ret = true;
                } else {
                    var val = getDisplayValues(option, activityMonitorInfo, deviceSettings);
                    ret = drawIndicator(
                        dc,
                        _pos[idx][0],
                        _pos[idx][1],
                        indicatorColor,
                        val[0],
                        val[1]
                    );
                }
                if (:dfComplication2 == dataField[i]) { _complication2Drawn = ret; }
            }
        }
    }

    // Draw the heart rate if it is available, return true if it was drawn.
    // Modern devices call this every few seconds, also in low-power mode.
    (:modern) public function drawHeartRate(dc as Dc, isAwake as Boolean) as Boolean {
        var ret = false; 
        if (_drawHeartRate != -1) {
            // Doing this here instead of in getDisplayValues() to save a function call
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
            //heartRate = 8888;
            //heartRate = System.getClockTime().sec + 60;
            if (heartRate != null) {
                ret = drawIndicator(
                    dc,
                    _pos[_drawHeartRate][0], 
                    _pos[_drawHeartRate][1],
                    config.colors[Config.C_HEART_RATE],
                    isAwake ? "H" : "I",
                    heartRate.format("%d")
                );
            }
        }
        return ret;
    }

    // Determine if a given data field should be drawn and its position on the screen. 
    // This function exists to have all decisions regarding data field placing, some of which
    // are interdependent, in one place.
    // The position returned is an index into _pos. -1 means the data field should not be drawn.
    (:modern) private function getDataFieldPosition(dataField as Symbol) as Number {
        var idx = -1;
        switch (dataField) {
            case :dfBattery:
                if (config.isEnabled(Config.I_BATTERY)) {
                    idx = _iconsDrawn ? 3 : 4;
                }
                break;
            case :dfIcons:
                if (   config.isEnabled(Config.I_ALARMS)
                    or config.isEnabled(Config.I_NOTIFICATIONS)) {
                    idx = 5;
                }
                break;
            case :dfPhoneConnected:
                if (config.isEnabled(Config.I_CONNECTED)) { 
                    idx = 6; 
                }
                break;
            case :dfShortDate:
                if (:DateDisplayDayOnly == config.getOption(Config.I_DATE_DISPLAY)) { 
                    idx = 7; 
                }
                break;
            case :dfLongDate:
                if (:DateDisplayWeekdayAndDay == config.getOption(Config.I_DATE_DISPLAY)) {
                    if (config.isEnabled(Config.I_COMPLICATION_2)) {
                        idx = _batteryDrawn or config.isEnabled(Config.I_COMPLICATION_1) ? 9 : 8;
                    } else {
                        idx = _batteryDrawn and config.isEnabled(Config.I_COMPLICATION_1) ? 9 : 8;
                    }
                }
                break;
            case :dfComplication4:
                if (config.isEnabled(Config.I_COMPLICATION_4)) {
                    idx = 0;
                    if (:DateDisplayDayOnly == config.getOption(Config.I_DATE_DISPLAY)) {
                        idx = (config.isEnabled(Config.I_COMPLICATION_2)) ? 12 : 1;
                    }
                }
                break;
            case :dfComplication3:
                if (config.isEnabled(Config.I_COMPLICATION_3)) { 
                    idx = 2; 
                }
                break;
            case :dfComplication2:
                if (config.isEnabled(Config.I_COMPLICATION_2)) {
                    if (_hrat6 or _dtat6) {
                        idx = config.isEnabled(Config.I_COMPLICATION_1) or _batteryDrawn ? 11 : 3;
                    } else {
                        idx = config.isEnabled(Config.I_COMPLICATION_1) and _batteryDrawn and _iconsDrawn ? 11 : 10;
                    }
                }
                break;
            case :dfComplication1:
                if (config.isEnabled(Config.I_COMPLICATION_1)) {
                    if (!_complication2Drawn) { // Place the 1st complication where the 2nd complication would usually be
                        if (_hrat6 or _dtat6) {
                            idx = _batteryDrawn ? 11 : 3;
                        } else {
                            idx = 10;
                        }
                    } else {
                        // If the 2nd complication is drawn, (mostly) place the 1st complication in the upper
                        // half of the screen. Do not squeeze the 1st complication in the upper half (13), if 
                        // battery and icons are on and only the 2nd complication are at the bottom. Instead,
                        // draw the 1st complication below the 2nd complication at the bottom then (12).
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
                System.println("ERROR: Indicators.getDataFieldPos() is not implemented for data field = " + dataField);
                break;
        }
        return idx;
    }

    // To add a new indicator for amoled and modern watches:
    //
    // - Choose a new symbol name for the new indicator (like :Elevation, :Pressure).
    //
    // resources*/strings/strings.xml
    // - Add string resources for the new symbol.
    //
    // resources*/fonts/swissrailwayclock-icons-*
    // - Create one or more icons and add them to the Icons font.
    //
    // source-{amoled,modern}/Config.mc
    // - Add the new symbol to the Config._options arrays for the four complications. 
    //   (Complications 1 and 2 are for indicators with up to 5 digits, the other two only
    //   accommodate up to 4 digits.)
    // - In Config.hasRequiredFeature(), add a check if the new indicator is not available on all 
    //   supported devices.
    //
    // source/Indicators.mc
    // - In Indicators.getDisplayValues(), implement the logic to determine the value and an icon
    //   for the new indicator.
    //
    // Voilà.

    // Return the character for the indicator icon and the current value of the indicator formatted as a string
    (:modern) private function getDisplayValues(
        option as Symbol, 
        activityMonitorInfo as ActivityMonitor.Info,
        deviceSettings as DeviceSettings
    ) as [String, String] {
        var icon = "";
        var value = "";
        var v = null;
        switch (option) {
            case :RecoveryTime:
                icon = "R";
                //v = 8888;
                v = config.hasRequiredFeature(option) ? activityMonitorInfo.timeToRecovery : null;
                break;
            case :Calories:
                icon = "C";
                //v = 88888;
                v = activityMonitorInfo.calories;
                break;
            case :Steps:
                icon = "F";
                //v = 88888;
                v = activityMonitorInfo.steps;
                break;
            case :FloorsClimbed:
                icon = "S";   // TODO: Switch S and F icons in all fonts
                v = config.hasRequiredFeature(option) ? activityMonitorInfo.floorsClimbed : null;
                break;
            case :Elevation:
                icon = "E";
                var altitude = null;
                var activityInfo = Activity.getActivityInfo();
                if (activityInfo != null) {
                    altitude = activityInfo.altitude;
                }
                if (null == altitude and SensorHistory has :getElevationHistory) {
                    var sample = SensorHistory.getElevationHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST}).next();
			        if (sample != null) {
				        altitude = sample.data;
			        }
                }
		        if (altitude != null) {
                    if (System.UNIT_STATUTE == deviceSettings.elevationUnits) {
			            altitude *= 3.28084; // convert meters to feet
                    }
                    value = altitude.format("%d"); // Can be 0 or negative
                }
                break;
            case :Pressure:
                // The current atmospheric pressure value and an icon that shows the recent pressure trend.
                // The trend line emulates Garmin's own definition:
                // "The barometer trend line considers the last 6 hours, broken into two 3 hour segments.
                // If there is a 2.3 millibar change over the 3-hour segment, the line will curve up or 
                // down depending on the direction of change."
                // Source: https://support.garmin.com/en-GB/?faq=agZJiZRjhX2adgWkBVOHI9
                if (SensorHistory has :getPressureHistory) {
                    var pressureHistory = SensorHistory.getPressureHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
                    var sample1 = pressureHistory.next();
                    pressureHistory = SensorHistory.getPressureHistory({:period => new Time.Duration(10300), :order => SensorHistory.ORDER_OLDEST_FIRST});
                    var sample2 = pressureHistory.next();
                    pressureHistory = SensorHistory.getPressureHistory({:period => new Time.Duration(21600), :order => SensorHistory.ORDER_OLDEST_FIRST});
                    var sample3 = pressureHistory.next();
                    if (    sample1 != null and sample1.data != null
                        and sample2 != null and sample2.data != null
                        and sample3 != null and sample3.data != null) {

                        // Select the icon for the trend line. Sample data is in Pascals (Pa). 1 mbar = 100 Pa.
                        var d1 = sample1.data - sample2.data;
                        var i1 = d1 >= -230 ? d1 >= 230 ? 0 : 1 : 2; // up, level, down
                        var d2 = sample2.data - sample3.data;
                        var i2 = d2 >= -230 ? d2 >= 230 ? 0 : 1 : 2;
                        // icon = ["0","1","2","3","4","5","6","7","8"][i2*3 + i1];
                        icon = (i2*3 + i1).format("%d");

                        // Current pressure value as an integer in mbar. TODO: Support other units 
                        // TODO: The cast is required due to what seems a type checker bug (sdk-8.2.2)
                        value = (sample1.data as Number or Float / 100.0 + 0.5).toNumber().format("%d");

                        // Debug output
/*                      var sec = System.getClockTime().sec;
                        icon = ((sec / 3).toNumber() % 9).format("%d");
*/
/*                      var gi = Gregorian.info(sample1.when, Time.FORMAT_MEDIUM);
                        var whenStr = Lang.format("$1$:$2$:$3$ $4$-$5$-$6$", [gi.hour, gi.min, gi.sec, gi.day, gi.month, gi.year]);
                        System.println("sample1: data = " + sample1.data + ", when = " + whenStr);
                        gi = Gregorian.info(sample2.when, Time.FORMAT_MEDIUM);
                        whenStr = Lang.format("$1$:$2$:$3$ $4$-$5$-$6$", [gi.hour, gi.min, gi.sec, gi.day, gi.month, gi.year]);
                        System.println("sample2: data = " + sample2.data + ", when = " + whenStr);
                        gi = Gregorian.info(sample3.when, Time.FORMAT_MEDIUM);
                        whenStr = Lang.format("$1$:$2$:$3$ $4$-$5$-$6$", [gi.hour, gi.min, gi.sec, gi.day, gi.month, gi.year]);
                        System.println("sample3: data = " + sample3.data + ", when = " + whenStr);
                        System.println("d1 = " + d1 + ", d2 = " + d2 + ", icon = " + icon + ", value = " + value);
*/
                    }
                }
                break;
            default:
                System.println("ERROR: Indicators.getDisplayValue() is not implemented for option = " + option);
                break;
        }
        if (value.equals("") and v != null and v > 0) {
            value = v.format("%d");
        }
        return [icon, value];
    }

    // Draw a simple indicator, return true if it was drawn.
    // Note: Sets and clears the clipping region of the device context.
    (:modern) private function drawIndicator(
        dc as Dc,
        xpos as Number, 
        ypos as Number,
        color as ColorType,
        icon as String,
        value as String
    ) as Boolean {
        var ret = false;
        //value = "123";
        //value = "87654";
        //value = "3456";
        var len = value.length();
        if (len > 0) {
            // Adjust the position for the location of the indicator and the length of the value
            var xpos2 = xpos; // adjusted x position for the current value
            var xpos3 = xpos; // x position for the largest value
            var maxLen = 4; // length of the largest value
            var w2 = _width / 2;
            if (xpos < w2) { // left align the indicator at 9 o'clock
                xpos2 += _width * -0.024;
                xpos3 = xpos2;
            } else if (xpos > w2) { // right align the indicator at 3 o'clock
                xpos2 += _width * [0.068, 0.019, -0.030, -0.070][(len > maxLen ? maxLen : len) - 1];
                xpos3 += _width * -0.070;
            } else { // center the indicator if it is on the line from 12 o'clock - 6 o'clock
                maxLen = 5;
                xpos2 += _width * [0.024, 0.000, -0.026, -0.048, -0.074][(len > maxLen ? maxLen : len) - 1];
                xpos3 += _width * -0.074;
            }
            // Clear the indicator area
            icon += "~";
            var wl = dc.getTextWidthInPixels(icon, iconFont as FontResource);
            var font = Graphics.FONT_TINY;
            var wr = dc.getTextWidthInPixels("8", font) * maxLen;
            var h = dc.getFontHeight(iconFont as FontResource); 
            dc.setClip(xpos3 - wl, ypos - h*0.5, wl + wr, h);
            dc.setColor(Graphics.COLOR_TRANSPARENT, config.colors[Config.C_BACKGROUND]);
            dc.clear();
            dc.clearClip();
            // Draw the indicator symbol and its value
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                xpos2, 
                ypos - 1, 
                iconFont as FontResource, 
                icon, 
                Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_RIGHT
            );
            dc.setColor(config.colors[Config.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                xpos2, 
                ypos, 
                font,
                value, 
                Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_LEFT
            );
/*
            // Debug output
            dc.drawRectangle(xpos3 - wl, ypos - h*0.5, wl + wr, h);
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(xpos, ypos - 1, 1);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(xpos2, ypos - 1, 1);
*/
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
            dc.setColor(config.colors[Config.C_TEXT], Graphics.COLOR_TRANSPARENT);
            dc.drawText(xpos, ypos, iconFont as FontResource, icons as String, Graphics.TEXT_JUSTIFY_CENTER);
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
        if (phoneConnected) {
            dc.setColor(config.colors[Config.C_PHONECONN], Graphics.COLOR_TRANSPARENT);
            dc.drawText(xpos, ypos, iconFont as FontResource, "B" as String, Graphics.TEXT_JUSTIFY_CENTER);
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
        	    dc.setColor(config.colors[Config.C_MOVE_BAR], Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(width);
                dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, angle, angle-bar);

                var color = (1 == i or 3 == i) ? Config.C_FOREGROUND : Config.C_BACKGROUND;
        		dc.setColor(config.colors[color], Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(1);
                dc.fillPolygon(arrowPoints(x, y, radius, width, angle));

		    	angle = angle - bar - 3;
            }
            // Draw the arrow tips in a second loop, so they are drawn over the background color arrow tails 
            angle = 152;
        	dc.setColor(config.colors[Config.C_MOVE_BAR], Graphics.COLOR_TRANSPARENT);
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
