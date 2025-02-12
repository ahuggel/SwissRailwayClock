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
    private var _colorMode as Number = M_LIGHT;

    // Configuration item identifiers. Used throughout the app to refer to individual settings.
    // The last one must be I_SIZE, it is used like size(), those after I_SIZE are hacks
    enum Item {
        I_BATTERY, 
        I_DATE_DISPLAY, 
        I_DARK_MODE, 
        I_HIDE_SECONDS, 
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
        I_3D_EFFECTS, 
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
        :DarkMode, 
        :HideSeconds, 
        :AccentColor, 
        :AccentCycle, 
        :DmContrast, 
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
        :Shadows, 
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
        "hs", // I_HIDE_SECONDS
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
        "3d", // I_3D_EFFECTS
        "bp", // I_BATTERY_PCT
        "bd"  // I_BATTERY_DAYS
    ] as Array<String>;

    // Options for list items. One array of symbols for each of them. These inner arrays are accessed
    // using Item enums, so list items need to be the first ones in the Item enum and in the same order.
    private var _options as Array< Array<Symbol> > = [
        [:Off, :BatteryClassicWarnings, :BatteryModernWarnings, :BatteryClassic, :BatteryModern], // I_BATTERY
        [:Off, :DateDisplayDayOnly, :DateDisplayWeekdayAndDay], // I_DATE_DISPLAY
        [:DarkModeScheduled, :Off, :On, :DarkModeInDnD], // I_DARK_MODE
        [:HideSecondsInDm, :HideSecondsAlways, :HideSecondsNever], // I_HIDE_SECONDS
        [:AccentRed, :AccentOrange, :AccentYellow, :AccentLtGreen, :AccentGreen, :AccentLtBlue, :AccentBlue, :AccentPurple, :AccentPink], // I_ACCENT_COLOR
        [:Off, :Hourly, :EveryMinute, :EverySecond], // I_ACCENT_CYCLE
        [:DmContrastLtGray, :DmContrastDkGray, :DmContrastWhite] // I_DM_CONTRAST
     ] as Array< Array<Symbol> >;

    private var _values as Array<Number> = new Array<Number>[I_SIZE]; // Values for the configuration items
    private var _hasAlpha as Boolean; // Indicates if the device supports an alpha channel; required for the 3D effects
    private var _hasBatteryInDays as Boolean; // Indicates if the device provides battery in days estimates
    private var _hasTimeToRecovery as Boolean; // Indicates if the device provides recovery time

    // Constructor
    public function initialize() {
        // Default values for toggle items, each bit is one. I_ALARMS, I_CONNECTED and I_3D_EFFECTS are on by default.
        var defaults = 0x105; // 0b0001 0000 0101

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
                if (I_3D_EFFECTS == id and !_hasAlpha) { 
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
        } else if (I_HIDE_SECONDS == id) {
            disabled = 2;
        }
        return disabled != _values[id];
    }

    // Return the current value of the specified setting.
    public function getValue(id as Item) as Number {
        var value = _values[id];
        if (I_DM_CONTRAST == id) {
            value = ([Graphics.COLOR_LT_GRAY, Graphics.COLOR_DK_GRAY, Graphics.COLOR_WHITE] as Array<Number>)[value];
        }
        return value;
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

    // Determine the color mode and the colors to use, return the color mode
    public function setColors(isAwake as Boolean, doNotDisturb as Boolean, hour as Number, minute as Number) as Number {        
        // Determine if dark mode is on
        _colorMode = M_LIGHT;
        var darkMode = getOption(I_DARK_MODE);
        if (:DarkModeScheduled == darkMode) {
            var time = hour * 60 + minute;
            if (time >= getValue(I_DM_ON) or time < getValue(I_DM_OFF)) {
                _colorMode = M_DARK;
            }
        } else if (   :On == darkMode
                   or (:DarkModeInDnD == darkMode and doNotDisturb)) {
            _colorMode = M_DARK;
        }

        if (M_LIGHT == _colorMode) {
            colors = [
                Graphics.COLOR_BLACK, // C_FOREGROUND
                Graphics.COLOR_WHITE, // C_BACKGROUND 
                Graphics.COLOR_DK_GRAY, // C_TEXT
                Graphics.COLOR_DK_BLUE, // C_INDICATOR 
                Graphics.COLOR_RED, // C_HEART_RATE 
                Graphics.COLOR_BLUE, // C_PHONECONN 
                Graphics.COLOR_BLUE, // C_MOVE_BAR
                Graphics.COLOR_LT_GRAY, // C_BATTERY_FRAME
                Graphics.COLOR_GREEN, // C_BATTERY_LEVEL_OK
                Graphics.COLOR_YELLOW, // C_BATTERY_LEVEL_WARN
                Graphics.COLOR_RED // C_BATTERY_LEVEL_ALERT
            ];
        } else {
            colors = [
                getValue(I_DM_CONTRAST), // C_FOREGROUND
                Graphics.COLOR_BLACK, // C_BACKGROUND 
                Graphics.COLOR_DK_GRAY, // C_TEXT
                Graphics.COLOR_BLUE, // C_INDICATOR 
                Graphics.COLOR_RED, // C_HEART_RATE 
                Graphics.COLOR_BLUE, // C_PHONECONN 
                Graphics.COLOR_DK_BLUE, // C_MOVE_BAR
                Graphics.COLOR_DK_GRAY, // C_BATTERY_FRAME
                Graphics.COLOR_GREEN, // C_BATTERY_LEVEL_OK
                Graphics.COLOR_ORANGE, // C_BATTERY_LEVEL_WARN
                Graphics.COLOR_RED // C_BATTERY_LEVEL_ALERT
            ];
            // Text color depends on foreground
            if (Graphics.COLOR_WHITE == colors[C_FOREGROUND]) {
                colors[C_TEXT] = Graphics.COLOR_LT_GRAY;
            }
            // Phone connected icon color depends on foreground
            if (Graphics.COLOR_DK_GRAY != colors[C_FOREGROUND]) {
                colors[C_PHONECONN] = Graphics.COLOR_DK_BLUE;
            }
        }

        return _colorMode;
    }

    // Return the accent color for the second hand. If the change color setting is enabled, the 
    // return value is based on the time passed in, else it's based on the accent color setting.
    // If a value of -1 is passed for the hour, return the color based on the setting.
    public function getAccentColor(hour as Number, minute as Number, second as Number) as Number {
        var aci = 0;
        if (hour != -1 and isEnabled(I_ACCENT_CYCLE)) {
            aci = [0, hour, minute, second][getValue(I_ACCENT_CYCLE)] % 9 * 2;
        } else {
            aci = getValue(I_ACCENT_COLOR) * 2;
        }
        return [
            // Colors for the second hand, in pairs with one color for each color mode
            0xFF0000, 0xff0055, // red 
            0xff5500, 0xffaa00, // orange
            0xffff00, 0xffff55, // yellow
            0x55ff00, 0x55ff00, // light green
            0x00AA00, 0x00aa55, // green
            0x00ffff, 0x55ffff, // light blue
            0x0000FF, 0x00AAFF, // blue
            0xaa00aa, 0xaa00ff, // purple
            0xff00aa, 0xff00aa  // pink
        ][M_LIGHT == _colorMode ? aci : aci + 1];
    }

    // Helper function to load string resources, just to keep the code simpler and see only one compiler warning. 
    private function getStringResource(id as Symbol) as String {
        return WatchUi.loadResource(Rez.Strings[id] as ResourceId) as String;
    }
} // class Config
