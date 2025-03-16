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
import Toybox.ActivityMonitor;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Global variable that keeps track of the settings and makes them available to the app.
var config as Config = new Config();

// This class maintains the color configuration and all application settings.
// Application settings are synchronised to persistent storage.
class Config {
    // Color configuration
    enum ColorMode { M_LIGHT, M_DARK } // Color modes
    // Indexes into the colors array
    enum Color {
        C_FOREGROUND, 
        C_BACKGROUND, 
        C_TEXT, 
        C_INDICATOR, 
        C_HEART_RATE, 
        C_PHONECONN, 
        C_MOVE_BAR,
        C_BATTERY_FRAME,
        C_BATTERY_LEVEL_OK,
        C_BATTERY_LEVEL_WARN,
        C_BATTERY_LEVEL_ALERT,
        C_SIZE
    }
    // Colors. Read access is directly through this public variable to save the overhead of a
    // getColor() call, write access is only via setColors(). 
    public var colors as Array<Number> = new Array<Number>[C_SIZE];

    // Configuration item identifiers. Used throughout the app to refer to individual settings.
    // The last one must be I_SIZE, it is used like size(), those after I_SIZE are hacks
    enum Item {
        I_BATTERY, 
        I_DATE_DISPLAY, 
        I_DARK_MODE, 
        I_ACCENT_COLOR,
        I_ACCENT_CYCLE,
        I_DM_CONTRAST,
        I_DM_ON, // the first item that is not a list item
        I_DM_OFF, 
        I_ALARMS, // the first toggle item (see defaults)
        I_NOTIFICATIONS,
        I_CONNECTED,
        I_HEART_RATE,
        I_RECOVERY_TIME,
        I_STEPS,
        I_CALORIES,
        I_MOVE_BAR,
        I_BATTERY_PCT, 
        I_BATTERY_DAYS, 
        I_SIZE, 
        I_DONE, 
        I_ALL 
    }

    // Symbols for the configuration item display name resources.
    // Must be in the same sequence as Item, above.
	private var _itemSymbols as Array<Symbol> = [
        :Battery, 
        :DateDisplay, 
        :Dimmer, 
        :AccentColor, 
        :AccentCycle, 
        :DimmerLevel, 
        :DmOn, 
        :DmOff,
        :Alarms,
        :Notifications,
        :Connected,
        :HeartRate,
        :RecoveryTime,
        :Steps,
        :Calories,
        :MoveBar,
        :BatteryPct, 
        :BatteryDays
    ] as Array<Symbol>;

    // Configuration item labels only used as keys for storing the configuration values.
    // Also must be in the same sequence as Item.
    // Using these for persistent storage, rather than Item, is more robust.
    private var _itemLabels as Array<String> = [
        "ba", // I_BATTERY
        "dd", // I_DATE_DISPLAY
        "dm", // I_DARK_MODE
        "ac", // I_ACCENT_COLOR
        "ay", // I_ACCENT_CYCLE
        "dc", // I_DM_CONTRAST
        "dn", // I_DM_ON
        "df", // I_DM_OFF
        "al", // I_ALARMS
        "no", // I_NOTIFICATIONS
        "co", // I_CONNECTED
        "hr", // I_HEART_RATE
        "rt", // I_RECOVERY_TIME
        "st", // I_STEPS
        "ca", // I_CALORIES
        "mb", // I_MOVE_BAR
        "bp", // I_BATTERY_PCT
        "bd"  // I_BATTERY_DAYS
    ] as Array<String>;

    // Options for list items. One array of symbols for each of them. These inner arrays are accessed
    // using Item enums, so list items need to be the first ones in the Item enum and in the same order.
    private var _options as Array< Array<Symbol> > = [
        [:Off, :BatteryClassicWarnings, :BatteryModernWarnings, :BatteryClassic, :BatteryModern], // I_BATTERY
        [:Off, :DateDisplayDayOnly, :DateDisplayWeekdayAndDay], // I_DATE_DISPLAY
        [:DarkModeScheduled, :Off, :On, :DarkModeInDnD], // I_DARK_MODE
        [:AccentRed, :AccentOrange, :AccentYellow, :AccentLtGreen, :AccentGreen, :AccentLtBlue, :AccentBlue, :AccentPurple, :AccentPink], // I_ACCENT_COLOR
        [:Off, :Hourly, :EveryMinute, :EverySecond], // I_ACCENT_CYCLE
        [:DimmerLevelLight, :DimmerLevelMedium, :DimmerLevelSlate, :DimmerLevelDark] // I_DM_CONTRAST
     ] as Array< Array<Symbol> >;

    private var _values as Array<Number> = new Array<Number>[I_SIZE]; // Values for the configuration items
    private var _hasAlpha as Boolean; // Indicates if the device supports an alpha channel; required for the wire hands
    private var _hasBatteryInDays as Boolean; // Indicates if the device provides battery in days estimates
    private var _hasTimeToRecovery as Boolean; // Indicates if the device provides recovery time

    // Constructor
    public function initialize() {
        // Default values for toggle items, each bit is one. I_ALARMS and I_CONNECTED are on by default.
        var defaults = 0x005; // 0b000 0000 0101

        _hasAlpha = (Graphics has :createColor) and (Graphics.Dc has :setFill); // Both should be available from API Level 4.0.0, but the Venu Sq 2 only has :createColor
        _hasBatteryInDays = (System.Stats has :batteryInDays);
        _hasTimeToRecovery = (ActivityMonitor.Info has :timeToRecovery);
        // Read the configuration values from persistent storage 
        for (var id = 0; id < I_SIZE; id++) {
            var value = Storage.getValue(_itemLabels[id]) as Number;
            if (id >= I_ALARMS) { // toggle items
                if (null == value) { 
                    value = (defaults & (1 << (id - I_ALARMS))) >> (id - I_ALARMS);
                }
                // Make sure the value is compatible with the device capabilities, so the watchface code can rely on getValue() alone.
                if (I_BATTERY_DAYS == id and !_hasBatteryInDays) { 
                    value = 0;
                }
                if (I_RECOVERY_TIME == id and !_hasTimeToRecovery) {
                    value = 0;
                }
            } else if (id < I_DM_ON) { // list items
                if (null == value) { 
                    value = 0;
                }
            } else { // I_DM_ON or I_DM_OFF
                if (I_DM_ON == id and (null == value or value < 0 or value > 1439)) {
                    value = 1320; // Default time to turn dark mode on: 22:00
                }
                if (I_DM_OFF == id and (null == value or value < 0 or value > 1439)) {
                    value = 420; // Default time to turn dark more off: 07:00
                }
            }
            _values[id] = value;
        }
    }

    // Return a string resource for the setting (the name of the setting).
    public function getName(id as Item) as String {
        return getStringResource(_itemSymbols[id]);
    }

    // Return a string resource for the current value of the setting (the name of the option).
    public function getLabel(id as Item) as String {
        var label = getOption(id);
        if (label instanceof Lang.Symbol) {
            label = getStringResource(label);
        }
        return label;
    }

    // Return the symbol corresponding to the current value of the setting, 
    // or the value formatted as a time string.
    public function getOption(id as Item) as Symbol or String {
        var ret;
        var value = _values[id];
        if (id >= I_ALARMS) { // toggle items
            ret = isEnabled(id) ? :On : :Off;            
        } else if (id < I_DM_ON) { // list items
            var opts = _options[id];
            ret = opts[value];
        } else { // if (I_DM_ON == id or I_DM_OFF == id) {
            var pm = "";
            var hour = (value / 60).toNumber();
            if (!System.getDeviceSettings().is24Hour) {
                pm = hour < 12 ? " am" : " pm";
                hour %= 12;
                if (0 == hour) { hour = 12; }
            }
            ret = hour + ":" + (value % 60).format("%02d") + pm;
        }
        return ret;
    }

    // Return true if the setting is enabled, else false.
    // Does not make sense for I_DM_CONTRAST, I_DM_ON and I_DM_OFF.
    public function isEnabled(id as Item) as Boolean {
        var disabled = 0; // value when the setting is disabled
        if (I_DARK_MODE == id) {
            disabled = 1;
        }
        return disabled != _values[id];
    }

    // Return the current value of the specified setting.
    public function getValue(id as Item) as Number {
        return _values[id];
    }

    // Advance the setting to the next value. Does not make sense for I_DM_ON, I_DM_OFF.
    public function setNext(id as Item) as Void {
        var d = 2; // toggle items have two options
        if (id < I_DM_ON) { // for list items get the number of options
            d = _options[id].size();
        }
        var value = (_values[id] + 1) % d;
        _values[id] = value;
        Storage.setValue(_itemLabels[id], value);
    }

    // Set the value of a setting. Only used for I_DM_ON and I_DM_OFF.
    public function setValue(id as Item, value as Number) as Void {
        _values[id] = value;
        Storage.setValue(_itemLabels[id], value);
    }

    // Returns true if the device supports an alpha channel, false if not.
    public function hasAlpha() as Boolean {
        return _hasAlpha;
    }

    // Returns true if the device provides battery in days estimates, false if not.
    public function hasBatteryInDays() as Boolean {
        return _hasBatteryInDays;
    }

    // Returns true if the device provides recovery time, false if not.
    public function hasTimeToRecovery() as Boolean {
        return _hasTimeToRecovery;
    }

    // Return the color (shade of gray) for the current I_DM_CONTRAST (dimmer level) setting  
    public function getContrastColor() as Number {
        // Graphics.COLOR_LT_GRAY = 0xaaaaaa, Graphics.COLOR_DK_GRAY = 0x555555
        return [0xd4d4d4, Graphics.COLOR_LT_GRAY, 0x808080, Graphics.COLOR_DK_GRAY][_values[I_DM_CONTRAST] % 4];
    }

    // Determine the colors to use
    public function setColors(isAwake as Boolean, doNotDisturb as Boolean, hour as Number, minute as Number) as Void {        
        // Determine if dark/dimmer mode is on
        var colorMode = M_LIGHT;
        var darkMode = getOption(I_DARK_MODE);
        if (:DarkModeScheduled == darkMode) {
            var time = hour * 60 + minute;
            if (time >= getValue(I_DM_ON) or time < getValue(I_DM_OFF)) {
                colorMode = M_DARK;
            }
        } else if (   :On == darkMode
                   or (:DarkModeInDnD == darkMode and doNotDisturb)) {
            colorMode = M_DARK;
        }

        // Foreground color is based on display mode and dimmer setting
        var foreground = Graphics.COLOR_WHITE;
        var idx = 0;
        if (isAwake) {
            if (M_DARK == colorMode) {
                // In dark/dimmer mode, set the foreground color based on the dimmer (contrast) setting
                foreground = getContrastColor();
                idx = getValue(I_DM_CONTRAST) + 1;
            }
        } else { // !isAwake
            foreground = Graphics.COLOR_DK_GRAY;
            idx = 4;
        }

        // Phone connected icon color
        var phoneconn = idx < 4 ? Graphics.COLOR_DK_BLUE : Graphics.COLOR_BLUE;
        // Brightness factors for each foreground color (in the order white, light, medium, slate, dark)
        var fDef = [1.00, 0.925,0.85, 0.75, 0.60][idx]; // default
        var fTxt = [0.667,0.75, 0.833,1.20, 1.40][idx]; // for text and battery frame
        var fPco = [1.00, 0.90, 0.80, 0.70, 0.75][idx]; // for the color of the phone connected icon
        colors = [
            foreground, // C_FOREGROUND
            Graphics.COLOR_BLACK, // C_BACKGROUND 
            adjustBrightness(foreground, fTxt), // C_TEXT
            adjustBrightness(Graphics.COLOR_BLUE, fDef), // C_INDICATOR 
            adjustBrightness(Graphics.COLOR_RED, fDef), // C_HEART_RATE 
            adjustBrightness(phoneconn, fPco), // C_PHONECONN 
            adjustBrightness(Graphics.COLOR_DK_BLUE, fDef), // C_MOVE_BAR
            adjustBrightness(foreground, fTxt), // C_BATTERY_FRAME  TODO: This color should be removed - use C_TEXT instead
            adjustBrightness(Graphics.COLOR_GREEN, fDef), // C_BATTERY_LEVEL_OK
            adjustBrightness(Graphics.COLOR_ORANGE, fDef), // C_BATTERY_LEVEL_WARN
            adjustBrightness(Graphics.COLOR_RED, fDef) // C_BATTERY_LEVEL_ALERT
        ];
    }

    // Return the accent color for the second hand. If the change color setting is enabled, the 
    // return value is based on the time passed in, else it's based on the accent color setting.
    // If a value of -1 is passed for the hour, return the color based on the setting.
    public function getAccentColor(hour as Number, minute as Number, second as Number) as Number {
        var aci = 0;
        if (hour != -1 and isEnabled(I_ACCENT_CYCLE)) {
            aci = [0, hour, minute, second][getValue(I_ACCENT_CYCLE)] % 9;
        } else {
            aci = getValue(I_ACCENT_COLOR);
        }
        var color = [
            // Colors for the second hand
            0xff0055, // red 
            0xffaa00, // orange
            0xffff55, // yellow
            0x55ff00, // light green
            0x00aa55, // green
            0x55ffff, // light blue
            0x00AAFF, // blue
            0xaa00ff, // purple
            0xff00aa  // pink
            ][aci];
        // For the darkest dimmer setting and always-on mode, reduce the brightness slightly
        if (Graphics.COLOR_DK_GRAY == colors[C_FOREGROUND]) {
            color = adjustBrightness(color, 0.80);
        }
        return color;
    }

    // Adjust the brightness of color by factor f, return the adjusted color
    // 0 < f < 1 decreases brightness, f = 0 returns black, f = 1 leaves color unchanged,
    // f > 1 increases brightness, for large values, the resulting color will approach white
    private function adjustBrightness(color as Number, f as Float) as Number {
        // Colors are 24-bit numbers of the form 0xRRGGBB
        var r = clamp((color & 0xff0000 >> 16 * f + 0.5).toNumber(), 0x00 , 0xff);
        var g = clamp((color & 0x00ff00 >> 8 * f + 0.5).toNumber(), 0x00 , 0xff);
        var b = clamp((color & 0x0000ff * f + 0.5).toNumber(), 0x00 , 0xff);
        return r << 16 | g << 8 | b;
    }

    // Limit value to min and max
    private function clamp(value as Number, min as Number, max as Number) as Number {
        if (value < min) {
            value = min;
        } else if (value > max) {
            value = max;
        }
        return value;
    }

    // Helper function to load string resources, just to keep the code simpler and see only one compiler warning. 
    private function getStringResource(id as Symbol) as String {
        return WatchUi.loadResource(Rez.Strings[id] as ResourceId) as String;
    }
} // class Config
