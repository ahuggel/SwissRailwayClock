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
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Global variable that keeps track of the settings and makes them available to the app.
var config as Config = new Config();

// Global helper function to load string resources, just to keep the code simpler and see only one compiler warning. 
function getStringResource(id as Symbol) as String {
    return WatchUi.loadResource(Rez.Strings[id] as ResourceId) as String;
}

// This class maintains all application settings and synchronises them to persistent storage.
// Having a Setting class (hierarchy) to model individual settings and an array of these for the entire
// collection would be better design. As objects are expensive in Monkey C, that approach uses way too 
// much memory though.
class Config {
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
        I_ALARMS, // the first toggle item (see _defaults)
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

    // Options for list items. One array of symbols for each of the them. These inner arrays are accessed
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

    // Default values for toggle items, each bit is one. I_ALARMS, I_CONNECTED and I_3D_EFFECTS are on by default.
    private var _defaults as Number = 0x105; // 0b0001 0000 0101

    private var _values as Array<Number> = new Array<Number>[I_SIZE]; // Values for the configuration items
    private var _hasAlpha as Boolean; // Indicates if the device supports an alpha channel; required for the 3D effects
    private var _hasBatteryInDays as Boolean; // Indicates if the device provides battery in days estimates

    // Constructor
    public function initialize() {
        _hasAlpha = (Graphics has :createColor) and (Graphics.Dc has :setFill); // Both should be available from API Level 4.0.0, but the Venu Sq 2 only has :createColor
        _hasBatteryInDays = (System.Stats has :batteryInDays);
        // Read the configuration values from persistent storage 
        for (var id = 0; id < I_SIZE; id++) {
            var value = Storage.getValue(_itemLabels[id]) as Number;
            if (id >= I_ALARMS) { // toggle items
                if (null == value) { 
                    value = (_defaults & (1 << (id - I_ALARMS))) >> (id - I_ALARMS);
                }
                // Make sure the value is compatible with the device capabilities, so the watchface code can rely on getValue() alone.
                if (I_BATTERY_DAYS == id and !_hasBatteryInDays) { 
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
            label = getStringResource(getOption(id) as Symbol);
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
            var opts = _options[id] as Array<Symbol>;
            ret = opts[value];
        } else { // if (I_DM_ON == id or I_DM_OFF == id) {
            var pm = "";
            var hour = (value as Number / 60).toNumber();
            if (!System.getDeviceSettings().is24Hour) {
                pm = hour < 12 ? " am" : " pm";
                hour %= 12;
                if (0 == hour) { hour = 12; }
            }
            ret = hour + ":" + (value as Number % 60).format("%02d") + pm;
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
} // class Config

// The app settings menu
class SettingsMenu extends WatchUi.Menu2 {
    // Constructor
    public function initialize() {
        Menu2.initialize({:title=>Rez.Strings.Settings});
        buildMenu(Config.I_ALL);
    }

    // Called when the menu is brought into the foreground
    public function onShow() as Void {
        Menu2.onShow();
        // Update sub labels in case the dark mode on or off time changed
        var idx = findItemById(Config.I_DM_ON);
        if (-1 != idx) {
            var menuItem = getItem(idx) as MenuItem;
            menuItem.setSubLabel(config.getLabel(Config.I_DM_ON));
        }
        idx = findItemById(Config.I_DM_OFF);
        if (-1 != idx) {
            var menuItem = getItem(idx) as MenuItem;
            menuItem.setSubLabel(config.getLabel(Config.I_DM_OFF));
        }
    }

    // Build the menu from a given menu item onwards
    public function buildMenu(id as Config.Item) as Void {
        switch (id) {
            case Config.I_ALL:
                addMenuItem(Config.I_BATTERY);
                // Fallthrough
            case Config.I_BATTERY:
                // Add menu items for the battery label options only if battery is not set to "Off"
                if (config.isEnabled(Config.I_BATTERY)) {
                    addToggleMenuItem(Config.I_BATTERY_PCT);
                    if (config.hasBatteryInDays()) { 
                        addToggleMenuItem(Config.I_BATTERY_DAYS); 
                    }
                }
                addMenuItem(Config.I_DATE_DISPLAY);
                addToggleMenuItem(Config.I_ALARMS);
                addToggleMenuItem(Config.I_NOTIFICATIONS);
                addToggleMenuItem(Config.I_CONNECTED);
                addToggleMenuItem(Config.I_HEART_RATE);
                addToggleMenuItem(Config.I_RECOVERY_TIME);
                addToggleMenuItem(Config.I_STEPS);
                addToggleMenuItem(Config.I_CALORIES);
                addToggleMenuItem(Config.I_MOVE_BAR);
                addMenuItem(Config.I_DARK_MODE);
                //Fallthrough
            case Config.I_DARK_MODE:
                // Add menu items for the dark mode on and off times only if dark mode is set to "Scheduled"
                if (:DarkModeScheduled == config.getOption(Config.I_DARK_MODE)) {
                    addMenuItem(Config.I_DM_ON);
                    addMenuItem(Config.I_DM_OFF);
                }
                // Add the menu item for dark mode contrast only if dark mode is not set to "Off"
                if (config.isEnabled(Config.I_DARK_MODE)) {
                    Menu2.addItem(new WatchUi.IconMenuItem(
                        config.getName(Config.I_DM_CONTRAST), 
                        config.getLabel(Config.I_DM_CONTRAST), 
                        Config.I_DM_CONTRAST,
                        new MenuIcon(config.getValue(Config.I_DM_CONTRAST)),
                        {}
                    ));
                }
                addMenuItem(Config.I_HIDE_SECONDS);
                addMenuItem(Config.I_ACCENT_COLOR);
                addMenuItem(Config.I_ACCENT_CYCLE);
                if (config.hasAlpha()) {
                    addToggleMenuItem(Config.I_3D_EFFECTS); 
                }
                Menu2.addItem(new WatchUi.MenuItem(Rez.Strings.Done, Rez.Strings.DoneLabel, Config.I_DONE, {}));
                break;
        }
    }

    // Delete the menu from a given menu item onwards
    public function deleteMenu(id as Config.Item) as Void {
        switch (id) {
            case Config.I_BATTERY:
                deleteAnyItem(Config.I_BATTERY_PCT);
                deleteAnyItem(Config.I_BATTERY_DAYS);
                deleteAnyItem(Config.I_DATE_DISPLAY);
                deleteAnyItem(Config.I_ALARMS);
                deleteAnyItem(Config.I_NOTIFICATIONS);
                deleteAnyItem(Config.I_CONNECTED);
                deleteAnyItem(Config.I_HEART_RATE);
                deleteAnyItem(Config.I_RECOVERY_TIME);
                deleteAnyItem(Config.I_STEPS);
                deleteAnyItem(Config.I_CALORIES);
                deleteAnyItem(Config.I_MOVE_BAR);
                deleteAnyItem(Config.I_DARK_MODE);
                // Fallthrough
            case Config.I_DARK_MODE:
                // Delete all dark mode and following menu items
                deleteAnyItem(Config.I_DM_ON);
                deleteAnyItem(Config.I_DM_OFF);
                deleteAnyItem(Config.I_DM_CONTRAST);
                deleteAnyItem(Config.I_HIDE_SECONDS);
                deleteAnyItem(Config.I_ACCENT_COLOR);
                deleteAnyItem(Config.I_ACCENT_CYCLE);
                deleteAnyItem(Config.I_3D_EFFECTS);
                deleteAnyItem(Config.I_DONE);
                break;
        }
    }

    // Add a MenuItem to the menu.
    private function addMenuItem(item as Config.Item) as Void {
        Menu2.addItem(new WatchUi.MenuItem(config.getName(item), config.getLabel(item), item, {}));
    }

    // Add a ToggleMenuItem to the menu.
    private function addToggleMenuItem(item as Config.Item) as Void {
        Menu2.addItem(new WatchUi.ToggleMenuItem(
            config.getName(item), 
            {:enabled=>Rez.Strings.On, :disabled=>Rez.Strings.Off},
            item, 
            config.isEnabled(item), 
            {}
        ));
    }

    // Delete any menu item. Returns true if an item was deleted, else false
    private function deleteAnyItem(item as Config.Item) as Boolean {
        var idx = findItemById(item);
        var del = -1 != idx;
        if (del) { Menu2.deleteItem(idx); }
        return del;
    }
} // class SettingsMenu

// Input handler for the app settings menu
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as SettingsMenu;

    // Constructor
    public function initialize(menu as SettingsMenu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

  	public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    // Handle a menu item being selected
    public function onSelect(menuItem as MenuItem) as Void {
        var id = menuItem.getId() as Config.Item;
        if (Config.I_DONE == id) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (id >= Config.I_ALARMS) { // toggle items
            // Toggle the two possible configuration values
            config.setNext(id);
        } else if (id < Config.I_DM_ON) { // list items
            // Advance to the next option and show the selected option as the sub label
            config.setNext(id);
            menuItem.setSubLabel(config.getLabel(id));
            if (Config.I_BATTERY == id or Config.I_DARK_MODE == id) {
                // Delete all the following menu items, rebuild the menu with only the items required
                _menu.deleteMenu(id);
                _menu.buildMenu(id);
            }
            if (Config.I_DM_CONTRAST == id) {
                // Update the color of the icon
                var menuIcon = menuItem.getIcon() as MenuIcon;
                menuIcon.setColor(config.getValue(id));
            }
        } else { // I_DM_ON or I_DM_OFF
            // Let the user select the time
            WatchUi.pushView(new TimePicker(id), new TimePickerDelegate(id), WatchUi.SLIDE_IMMEDIATE);
        }
  	}
} // class SettingsMenuDelegate

// The icon class used for the contrast menu item
class MenuIcon extends WatchUi.Drawable {
    private var _color as Number;

    // Constructor
    public function initialize(color as Number) {
        Drawable.initialize({});
        _color = color;
    }

    // Set the color for the icon
    public function setColor(color as Number) as Void {
        _color = color;
    }

    // Draw the icon
    public function draw(dc as Dc) as Void {
        dc.clearClip();
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(_color, _color);
        dc.fillPolygon([[0,0], [width, height], [width, 0]]);
    }
}
