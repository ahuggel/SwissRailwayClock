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
import Toybox.ActivityMonitor;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.WatchUi;

// Global variable that keeps track of the settings and makes them available to the app.
var config as Config = new Config();

// This class maintains the color configuration and all application settings.
// Application settings are synchronised to persistent storage.
class Config {
    // Color configuration
    private enum ColorMode { M_LIGHT, M_DARK } // Color modes
    // Indexes into the colors array
    public enum Color {
        C_FOREGROUND, 
        C_BACKGROUND, 
        C_TEXT, 
        C_BLUE_NEUTRAL,
        C_GREEN_OK,
        C_YELLOW_WARN,
        C_ORANGE_WARN,
        C_RED_ALERT,
        C_INDICATOR, 
        C_PHONECONN, 
        C_BATTERY_FRAME,
        C_STRESS_SCORE,
        C_SIZE
    }
    // Colors. Read access is directly through this public variable to save the overhead of a
    // getColor() call, write access is only via setColors(). 
    public var colors as Array<Number> = new Array<Number>[C_SIZE];

    // Configuration item identifiers. Used throughout the app to refer to individual settings.
    // The last one must be I_SIZE, it is used like size(), those after I_SIZE are hacks
    public enum Item {
        I_BATTERY, 
        I_DATE_DISPLAY, 
        I_DARK_MODE, 
        I_ACCENT_COLOR,
        I_ACCENT_CYCLE,
        I_BRIGHTNESS,
        I_DM_CONTRAST,
        I_COMPLICATION_1,
        I_COMPLICATION_2,
        I_COMPLICATION_3,
        I_COMPLICATION_4,
        I_PRESSURE_UNIT,
        I_DM_ON, // the first item that is not a list item
        I_DM_OFF, 
        I_ALARMS, // the first toggle item (see defaults)
        I_NOTIFICATIONS,
        I_CONNECTED,
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
        :Brightness,
        :DimmerLevel, 
        :Complication1,
        :Complication2,
        :Complication3,
        :Complication4,
        :PressureUnit,
        :DmOn, 
        :DmOff,
        :Alarms,
        :Notifications,
        :Connected,
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
        "br", // I_BRIGHTNESS
        "dc", // I_DM_CONTRAST
        "c1", // I_COMPLICATION_1
        "c2", // I_COMPLICATION_2
        "c3", // I_COMPLICATION_3
        "c4", // I_COMPLICATION_4
        "pu", // I_PRESSURE_UNIT
        "dn", // I_DM_ON
        "df", // I_DM_OFF
        "al", // I_ALARMS
        "no", // I_NOTIFICATIONS
        "co", // I_CONNECTED
        "mb", // I_MOVE_BAR
        "bp", // I_BATTERY_PCT
        "bd"  // I_BATTERY_DAYS
    ] as Array<String>;

    // Options for list items. One array of symbols for each of them. These inner arrays are accessed
    // using Item enums, so list items need to be the first ones in the Item enum and in the same order.
    private var _options as Array< Array<Symbol> > = [
        [:Off, :BatteryClassicWarnings, :BatteryModernWarnings, :BatteryClassic, :BatteryModern], // I_BATTERY
        [:Off, :DateDisplayDayOnly, :DateDisplayWeekdayAndDay], // I_DATE_DISPLAY
        [:DarkModeScheduled, :Off, :DarkModeInDnD], // I_DARK_MODE
        [:AccentRed, :AccentOrange, :AccentYellow, :AccentLtGreen, :AccentGreen, :AccentLtBlue, :AccentBlue, :AccentPurple, :AccentPink], // I_ACCENT_COLOR
        [:Off, :Hourly, :EveryMinute, :EverySecond], // I_ACCENT_CYCLE
        [:DimmerLevelWhite, :DimmerLevelLight, :DimmerLevelMedium, :DimmerLevelSlate, :DimmerLevelDark], // I_BRIGHTNESS
        [:DimmerLevelWhite, :DimmerLevelLight, :DimmerLevelMedium, :DimmerLevelSlate, :DimmerLevelDark], // I_DM_CONTRAST
        [:Off, :HeartRate, :RecoveryTime, :Calories, :Steps, :FloorsClimbed, :Elevation, :Pressure, :Temperature], // I_COMPLICATION_1
        [:Off, :HeartRate, :RecoveryTime, :Calories, :Steps, :FloorsClimbed, :Elevation, :Pressure, :Temperature], // I_COMPLICATION_2
        [:Off, :HeartRate, :RecoveryTime, :FloorsClimbed, :Pressure, :Temperature, :StressScore], // I_COMPLICATION_3
        [:Off, :HeartRate, :RecoveryTime, :FloorsClimbed, :Pressure, :Temperature], // I_COMPLICATION_4
        [:PressureUnitMbar, :PressureUnitMmHg, :PressureUnitInHg, :PressureUnitAtm] // I_PRESSURE_UNIT
     ] as Array< Array<Symbol> >;

    private var _values as Array<Number> = new Array<Number>[I_SIZE]; // Values for the configuration items
    private var _hasCapability as Dictionary<Symbol, Boolean>; // Device capabilities

    // Constructor
    public function initialize() {
        // Default values for toggle items, each bit is one. I_ALARMS and I_CONNECTED are on by default.
        var defaults = 0x005; // 0b0000 0101

        // Tests for device capabilities. For complications, the symbol here must be the same as the complication option.
        _hasCapability = {
            // Indicates if the device supports an alpha channel; required for the wire hands.
            // Both should be available from API Level 4.0.0, but the Venu Sq 2 only has :createColor.
            :Alpha => (Graphics has :createColor) and (Graphics.Dc has :setFill),
            :BatteryInDays => (System.Stats has :batteryInDays), 
            :RecoveryTime => (ActivityMonitor.Info has :timeToRecovery), 
            :FloorsClimbed => (ActivityMonitor.Info has :floorsClimbed),
            :Pressure => (SensorHistory has :getPressureHistory),
            :Temperature => (SensorHistory has :getTemperatureHistory),
            :StressScore => (ActivityMonitor.Info has :stressScore)
        };
        
        // Read the configuration values from persistent storage 
        for (var id = 0; id < I_SIZE; id++) {
            var value = Storage.getValue(_itemLabels[id]) as Number or Null;
            if (id >= I_ALARMS) { // toggle items
                if (null == value) { 
                    value = (defaults & (1 << (id - I_ALARMS))) >> (id - I_ALARMS);
                }
                // Make sure the value is compatible with the device capabilities, so the watchface code can rely on getValue() alone.
                if (I_BATTERY_DAYS == id and !hasCapability(:BatteryInDays)) { 
                    value = 0;
                }
            } else if (id < I_DM_ON) { // list items
                if (null == value) { 
                    value = I_DM_CONTRAST == id ? 2 : 0;  // Default dimmer level
                }
                // Make sure the value is compatible with the device capabilities, so the watchface code can rely on getValue() alone.
                if (   I_COMPLICATION_1 == id 
                    or I_COMPLICATION_2 == id
                    or I_COMPLICATION_3 == id
                    or I_COMPLICATION_4 == id) {
                    var opts = _options[id];
                    if (!hasCapability(opts[value])) {
                        value = 0;
                    }
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
    // Does not make sense for I_BRIGHTNESS, I_DM_CONTRAST, I_DM_ON and I_DM_OFF.
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

    // Check if the device supports the required feature and return true if it does, else false.
    // The default return value for options without any special treatment is true.
    public function hasCapability(option as Symbol) as Boolean {
        var ret = _hasCapability[option];
        if (null == ret) {
            ret = true;
        }
        return ret;
    }

    // Return the color (shade of gray) for the current I_BRIGHTNESS or I_DM_CONTRAST (dimmer level) setting
    public function getSettingColor(id as Item) as Number {
        // Graphics.COLOR_WHITE = 0xffffff, Graphics.COLOR_LT_GRAY = 0xaaaaaa, Graphics.COLOR_DK_GRAY = 0x555555
        return [Graphics.COLOR_WHITE, 0xd4d4d4, Graphics.COLOR_LT_GRAY, 0x808080, Graphics.COLOR_DK_GRAY][_values[id] % 5];
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
        } else if (:DarkModeInDnD == darkMode and doNotDisturb) {
            colorMode = M_DARK;
        }
        // Foreground color is based on display mode and the brightness or dimmer setting
        var foreground = Graphics.COLOR_DK_GRAY;
        var lvl = 4;
        if (isAwake) {
            var id = M_LIGHT == colorMode ? I_BRIGHTNESS : I_DM_CONTRAST;
            foreground = getSettingColor(id);
            lvl = getValue(id) % 5;
        }
        var gray = [0xaaaaaa, 0x9f9f9f, 0x8e8e8e, 0x9a9a9a, 0x777777][lvl];
        colors = [
            foreground,                                              // C_FOREGROUND
            Graphics.COLOR_BLACK,                                    // C_BACKGROUND
            gray,                                                    // C_TEXT
            [0x0000ff, 0x0000ec, 0x0000d9, 0x0000bf, 0x000099][lvl], // C_BLUE_NEUTRAL
            [0x00ff00, 0x00ec00, 0x00d900, 0x00bf00, 0x009900][lvl], // C_GREEN_OK
            [0xffff00, 0xecec00, 0xd9d900, 0xbfbf00, 0x999900][lvl], // C_YELLOW_WARN
            [0xff5500, 0xec4f00, 0xd94800, 0xbf4000, 0x993300][lvl], // C_ORANGE_WARN
            [0xff0000, 0xec0000, 0xd90000, 0xbf0000, 0x990000][lvl], // C_RED_ALERT
            [0x00aaff, 0x009dec, 0x0091d9, 0x0080bf, 0x006699][lvl], // C_INDICATOR
            [0x0000ff, 0x0000e6, 0x0000cc, 0x0000b3, 0x0080bf][lvl], // C_PHONECONN
            gray,                                                    // C_BATTERY_FRAME
            gray                                                     // C_STRESS_SCORE
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
        aci *= 2;
        if (Graphics.COLOR_DK_GRAY == colors[C_FOREGROUND]) {
            aci += 1;
        }
        return [
            // Colors for the second hand, in pairs of the actual color and a dimmed version,
            // used with the darkest dimmer setting and always-on mode.
            0xff0055, 0xcc0044, // red
            0xffaa00, 0xcc8800, // orange
            0xffff55, 0xcccc44, // yellow
            0x55ff00, 0x44cc00, // light green
            0x00aa55, 0x008844, // green
            0x55ffff, 0x44cccc, // light blue
            0x00AAFF, 0x0088cc, // blue
            0xaa00ff, 0x8800cc, // purple
            0xff00aa, 0xcc0088  // pink
        ][aci];
    }

    // Helper function to load string resources, just to keep the code simpler and see only one compiler warning. 
    private function getStringResource(id as Symbol) as String {
        return WatchUi.loadResource(Rez.Strings[id] as ResourceId) as String;
    }
} // class Config
