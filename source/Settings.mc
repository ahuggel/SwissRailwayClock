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

//! Global variable that keeps track of the settings and makes them available to the app.
var config as Config = new Config();

// Global helper function to load string resources, just to keep the code simpler and see only one compiler warning. 
// Decided not to cache the strings.
function getStringResource(id as Symbol) as String {
    return WatchUi.loadResource(Rez.Strings[id] as Symbol) as String;
}

//! This class maintains application settings and synchronises them to persistent storage.
class Config {
    // Configuration item identifiers. Used throughout the app to refer to individual settings. The last one must be I_SIZE, it is used like size(), those after I_SIZE are hacks
    enum Item { I_BATTERY, I_DATE_DISPLAY, I_DARK_MODE, I_DM_CONTRAST, I_HIDE_SECONDS, I_3D_EFFECTS, I_BATTERY_PCT, I_BATTERY_DAYS, I_DM_ON, I_DM_OFF, I_SIZE, I_DONE, I_ALL }
    // Symbols for the configuration item display name resources
	private var _itemSymbols as Array<Symbol> = [:Battery, :DateDisplay, :DarkMode, :DmContrast, :HideSeconds, :Shadows, :BatteryPct, :BatteryDays, :DmOn, :DmOff] as Array<Symbol>;
    // Configuration item labels only used as keys for storing the configuration values. Using these for persistent storage, rather than Item is more robust.
    private var _itemLabels as Array<String> = ["battery", "dateDisplay", "darkMode", "dmContrast", "hideSeconds", "3dEffects", "batteryPct", "batteryDays", "dmOn", "dmOff"] as Array<String>;

    // Options for list and toggle configuration items. Using enums, the compiler can help detect issues like typos or outdated values.
    enum { O_BATTERY_OFF, O_BATTERY_CLASSIC_WARN, O_BATTERY_MODERN_WARN, O_BATTERY_CLASSIC, O_BATTERY_MODERN, O_BATTERY_HYBRID }
    enum { O_DATE_DISPLAY_OFF, O_DATE_DISPLAY_DAY_ONLY, O_DATE_DISPLAY_WEEKDAY_AND_DAY }
    enum { O_DARK_MODE_SCHEDULED, O_DARK_MODE_OFF, O_DARK_MODE_ON, O_DARK_MODE_IN_DND }
    enum { O_HIDE_SECONDS_IN_DM, O_HIDE_SECONDS_ALWAYS, O_HIDE_SECONDS_NEVER }
    enum { O_3D_EFFECTS_ON, O_3D_EFFECTS_OFF } // Default: On
    enum { O_BATTERY_PCT_OFF, O_BATTERY_PCT_ON } // Default: Off
    enum { O_BATTERY_DAYS_OFF, O_BATTERY_DAYS_ON } // Default: Off
    // Colors for the dark mode contrast icon menu item. The index (0, 1 or 2) is stored, but getValue() returns the color.
    static const O_DM_CONTRAST as Array<Number> = [Graphics.COLOR_LT_GRAY, Graphics.COLOR_DK_GRAY, Graphics.COLOR_WHITE] as Array<Number>;

    // Option labels for list items. One for each of the enum values above and in the same order.
    private var _labels as Dictionary<Item, Array<Symbol> > = {
        I_BATTERY      => [:Off, :BatteryClassicWarnings, :BatteryModernWarnings, :BatteryClassic, :BatteryModern, :BatteryHybrid],
        I_DATE_DISPLAY => [:Off, :DateDisplayDayOnly, :DateDisplayWeekdayAndDay],
        I_DARK_MODE    => [:DarkModeScheduled, :Off, :On, :DarkModeInDnD],
        I_DM_CONTRAST  => [:DmContrastLtGray, :DmContrastDkGray, :DmContrastWhite],
        I_HIDE_SECONDS => [:HideSecondsInDm, :HideSecondsAlways, :HideSecondsNever]
    } as Dictionary<Item, Array<Symbol> >;

    private var _values as Dictionary<Item, Number>;  // Values for the configuration items
    private var _hasAlpha as Boolean; // Indicates if the device supports an alpha channel; required for the 3D effects
    private var _hasBatteryInDays as Boolean; // Indicates if the device provides battery in days estimates
    private var _lastAccessed as Array<Number> = new Array<Number>[3];

    //! Constructor
    public function initialize() {
        _hasAlpha = (Graphics has :createColor) and (Graphics.Dc has :setFill); // Both should be available from API Level 4.0.0, but the Venu Sq 2 only has :createColor
        _hasBatteryInDays = (System.Stats has :batteryInDays);
        _values = {} as Dictionary<Item, Number>;
        _lastAccessed = [-1, -1, -1] as Array<Number>;
        // Read the configuration values from persistent storage 
        for (var id = 0; id < I_SIZE; id++) {
            var value = Storage.getValue(_itemLabels[id]) as Number;
            switch (id) {
                case I_DM_ON:
                    if (null == value or value < 0 or value > 1439) {
                        value = 1320; // Default time to turn dark mode on: 22:00
                    }
                    break;
                case I_DM_OFF:
                    if (null == value or value < 0 or value > 1439) {
                        value = 420; // Default time to turn dark more off: 07:00
                    }
                    break;
                case I_3D_EFFECTS:
                    if (null == value) { value = 0; }
                    // Make sure the value is compatible with the device capabilities, so the watchface code can rely on getValue() alone.
                    if (!_hasAlpha and O_3D_EFFECTS_ON == value) { value = O_3D_EFFECTS_OFF; }
                    break;
                case I_BATTERY_DAYS:
                    if (null == value) { value = 0; }
                    // Make sure the value is compatible with the device capabilities, so the watchface code can rely on getValue() alone.
                    if (!_hasBatteryInDays and O_BATTERY_DAYS_ON == value) { value = O_BATTERY_DAYS_OFF; }
                    break;
                default:
                    if (null == value) { value = 0; }
                    break;
            }
            _values[id as Item] = value;
        }
    }

    //! Return the current label for the specified setting.
    //!@param id Setting
    //!@return Label of the currently selected option
    public function getLabel(id as Item) as String {
        var option = "";
        var value = _values[id];
        switch (id) {
            case I_BATTERY:
            case I_DATE_DISPLAY:
            case I_DARK_MODE:
            case I_DM_CONTRAST:
            case I_HIDE_SECONDS:
                var label = _labels[id] as Array<Symbol>;
                option = $.getStringResource(label[value]);
                break;
            case I_DM_ON:
            case I_DM_OFF:
                var pm = "";
                var hour = (value as Number / 60).toNumber();
                if (!System.getDeviceSettings().is24Hour) {
                    pm = hour < 12 ? " am" : " pm";
                    hour %= 12;
                    if (0 == hour) { hour = 12; }
                }
                option = hour + ":" + (value as Number % 60).format("%02d") + pm;
                break;
            default:
                System.println("ERROR: Config.getLabel() is not implemented for id = " + id);
                break;
        }
        return option;
    }

    //! Return the current value of the specified setting.
    //!@param id Setting
    //!@return The current value of the setting
    public function getValue(id as Item) as Number {
        var value = _values[id] as Number;
        switch (id) {
            case I_DM_CONTRAST:
                value = O_DM_CONTRAST[value];
                break;
        }
        return value;
    }

    //! Return the name for the specified setting.
    //!@param id Setting
    //!@return Setting name
    public function getName(id as Item) as String {
        return $.getStringResource(_itemSymbols[id as Number]);
    }

    //! Advance the setting to the next value.
    //!@param id Setting
    public function setNext(id as Item) as Void {
        var value = _values[id];
        switch (id) {
            case I_BATTERY:
            case I_DATE_DISPLAY:
            case I_DARK_MODE:
            case I_DM_CONTRAST:
            case I_HIDE_SECONDS:
                var label = _labels[id] as Array<String>;
                _values[id] = (value as Number + 1) % label.size();
                Storage.setValue(_itemLabels[id as Number], _values[id]);
                break;
            case I_3D_EFFECTS:
            case I_BATTERY_PCT:
            case I_BATTERY_DAYS:
                _values[id] = (value as Number + 1) % 2;
                Storage.setValue(_itemLabels[id as Number], _values[id]);
                break;
            default:
                System.println("ERROR: Config.setNext() is not implemented for id = " + id);
                break;
        }
    }

    public function setValue(id as Item, value as Number) as Void {
        switch (id) {
            case I_DM_ON:
            case I_DM_OFF:
                _values[id] = value;
                Storage.setValue(_itemLabels[id as Number], _values[id]);
                break;
            default:
                System.println("ERROR: Config.seValue() is not implemented for id = " + id);
                break;
        }
    }

    // Returns true if the device supports an alpha channel, false if not.
    public function hasAlpha() as Boolean {
        return _hasAlpha;
    }

    // Returns true if the device provides battery in days estimates, false if not.
    public function hasBatteryInDays() as Boolean {
        return _hasBatteryInDays;
    }

    // Set the timestamp when the menu was last accessed
    public function setLastAccessed() as Void {
        var clockTime = System.getClockTime();
        _lastAccessed = [clockTime.hour, clockTime.min, clockTime.sec] as Array<Number>;
    }

    // Returns the timestamp when the settings menu was last accessed (shown)
    public function lastAccessed() as Array<Number> {
        return _lastAccessed;
    }
} // class Config

//! The app settings menu
class SettingsMenu extends WatchUi.Menu2 {
    //! Constructor
    public function initialize() {
        Menu2.initialize({:title=>$.getStringResource(:Settings)});
        buildMenu($.Config.I_ALL);
    }

    // Called when the menu is brought into the foreground
    public function onShow() as Void {
        Menu2.onShow();
        // Update the last accessed timestamp
        $.config.setLastAccessed();
        // Update sub labels in case the dark mode on or off time changed
        var idx = findItemById($.Config.I_DM_ON);
        if (-1 != idx) {
            var menuItem = getItem(idx) as MenuItem;
            menuItem.setSubLabel($.config.getLabel($.Config.I_DM_ON));
        }
        idx = findItemById($.Config.I_DM_OFF);
        if (-1 != idx) {
            var menuItem = getItem(idx) as MenuItem;
            menuItem.setSubLabel($.config.getLabel($.Config.I_DM_OFF));
        }
    }

    //! Build the menu from a given menu item onwards
    public function buildMenu(id as Config.Item) as Void {
        switch (id) {
            case $.Config.I_ALL:
                addMenuItem($.Config.I_BATTERY);
                // Fallthrough
            case $.Config.I_BATTERY:
                // Add menu items for the battery label options only if battery is not set to "Off"
                if ($.Config.O_BATTERY_OFF != $.config.getValue($.Config.I_BATTERY)) {
                    addToggleMenuItem($.Config.I_BATTERY_PCT, $.Config.O_BATTERY_PCT_ON);
                    if ($.config.hasBatteryInDays()) { 
                        addToggleMenuItem($.Config.I_BATTERY_DAYS, $.Config.O_BATTERY_DAYS_ON); 
                    }
                }
                addMenuItem($.Config.I_DATE_DISPLAY);
                addMenuItem($.Config.I_DARK_MODE);
                //Fallthrough
            case $.Config.I_DARK_MODE:
                // Add menu items for the dark mode on and off times only if dark mode is set to "Scheduled"
                var dm = $.config.getValue($.Config.I_DARK_MODE);
                if ($.Config.O_DARK_MODE_SCHEDULED == dm) {
                    addMenuItem($.Config.I_DM_ON);
                    addMenuItem($.Config.I_DM_OFF);
                }
                // Add the menu item for dark mode contrast only if dark mode is not set to "Off"
                if ($.Config.O_DARK_MODE_OFF != dm) {
                    Menu2.addItem(new WatchUi.IconMenuItem(
                        $.config.getName($.Config.I_DM_CONTRAST), 
                        $.config.getLabel($.Config.I_DM_CONTRAST), 
                        $.Config.I_DM_CONTRAST, 
                        new MenuIcon($.config.getValue($.Config.I_DM_CONTRAST)),
                        {}
                    ));
                }
                addMenuItem($.Config.I_HIDE_SECONDS);
                if ($.config.hasAlpha()) {
                    addToggleMenuItem($.Config.I_3D_EFFECTS, $.Config.O_3D_EFFECTS_ON); 
                }
                Menu2.addItem(new WatchUi.MenuItem($.getStringResource(:Done), $.getStringResource(:DoneLabel), $.Config.I_DONE, {}));
                break;
            default:
                System.println("ERROR: SettingsMenu.buildMenu() is not implemented for id = " + id);
                break;
        }
    }

    //! Delete the menu from a given menu item onwards
    public function deleteMenu(id as Config.Item) as Void {
        switch (id) {
            case $.Config.I_BATTERY:
                deleteAnyItem($.Config.I_BATTERY_PCT);
                deleteAnyItem($.Config.I_BATTERY_DAYS);
                deleteAnyItem($.Config.I_DATE_DISPLAY);
                deleteAnyItem($.Config.I_DARK_MODE);
                // Fallthrough
            case $.Config.I_DARK_MODE:
                // Delete all dark mode and following menu items
                deleteAnyItem($.Config.I_DM_ON);
                deleteAnyItem($.Config.I_DM_OFF);
                deleteAnyItem($.Config.I_DM_CONTRAST);
                deleteAnyItem($.Config.I_HIDE_SECONDS);
                deleteAnyItem($.Config.I_3D_EFFECTS);
                deleteAnyItem($.Config.I_DONE);
                break;
            default:
                System.println("ERROR: SettingsMenu.deleteMenu() is not implemented for id = " + id);
                break;
        }
    }

    //! Add a MenuItem to the menu.
    private function addMenuItem(item as Config.Item) as Void {
        Menu2.addItem(new WatchUi.MenuItem($.config.getName(item), $.config.getLabel(item), item, {}));
    }

    //! Add a ToggleMenuItem to the menu.
    private function addToggleMenuItem(item as Config.Item, isEnabled as Number) as Void {
        Menu2.addItem(new WatchUi.ToggleMenuItem(
            $.config.getName(item), 
            {:enabled=>$.getStringResource(:On), :disabled=>$.getStringResource(:Off)},
            item, 
            isEnabled == $.config.getValue(item), 
            {}
        ));
    }

    //! Delete any menu item. Returns true if an item was deleted, else false
    private function deleteAnyItem(item as Config.Item) as Boolean {
        var idx = findItemById(item);
        var del = -1 != idx;
        if (del) { Menu2.deleteItem(idx); }
        return del;
    }
} // class SettingsMenu

//! Input handler for the app settings menu
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as SettingsMenu;

    //! Constructor
    public function initialize(menu as SettingsMenu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

  	public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    //! Handle a menu item being selected
    //! @param menuItem The menu item selected
    public function onSelect(menuItem as MenuItem) as Void {
        var id = menuItem.getId() as Config.Item;
        switch (id) {
            case $.Config.I_DATE_DISPLAY:
            case $.Config.I_HIDE_SECONDS:
                // Advance to the next option and show the selected option as the sub label
                $.config.setNext(id);
                menuItem.setSubLabel($.config.getLabel(id));
                break;
            case $.Config.I_DM_CONTRAST:
                // Advance to the next option and show the selected option as the sub label
                $.config.setNext(id);
                menuItem.setSubLabel($.config.getLabel(id));
                // Update the color of the icon
                var menuIcon = menuItem.getIcon() as MenuIcon;
                menuIcon.setColor($.config.getValue(id));
                break;
            case $.Config.I_BATTERY:
            case $.Config.I_DARK_MODE:
                // Advance to the next option and show the selected option as the sub label
                $.config.setNext(id);
                menuItem.setSubLabel($.config.getLabel(id));
                // Delete all the following menu items, rebuild the menu with only the items required
                _menu.deleteMenu(id);
                _menu.buildMenu(id);
                break;
            case $.Config.I_BATTERY_PCT:
            case $.Config.I_BATTERY_DAYS:
            case $.Config.I_3D_EFFECTS:
                // Toggle the two possible configuration values
                $.config.setNext(id);
                break;
            case $.Config.I_DM_ON:
            case $.Config.I_DM_OFF:
                // Let the user select the time
                WatchUi.pushView(new TimePicker(id), new TimePickerDelegate(id), WatchUi.SLIDE_IMMEDIATE);
                break;
            case $.Config.I_DONE:
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                break;
            default:
                System.println("ERROR: SettingsMenuDelegate.onSelect() is not implemented for id = " + id);
                break;
        }
  	}
} // class SettingsMenuDelegate

//! The icon class used for the contrast menu item
class MenuIcon extends WatchUi.Drawable {
    private var _color as Number;

    //! Constructor
    public function initialize(color as Number) {
        Drawable.initialize({});
        _color = color;
    }

    //! Set the color for the icon
    public function setColor(color as Number) as Void {
        _color = color;
    }

    //! @param dc Device Context
    public function draw(dc as Dc) as Void {
        dc.clearClip();
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(_color, _color);
        dc.fillPolygon([[0,0], [width, height], [width, 0]] as Array< Array<Number> >);
    }
}
