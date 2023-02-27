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
import Toybox.WatchUi;

//! Global variable that keeps track of the settings and makes them available to the app.
var config as Config = new Config();

//! This class maintains application settings and synchronises them to persistent storage.
class Config {
    // Configuration item identifiers. Used throughout the app to refer to individual settings.
    enum Item { I_BATTERY, I_DATE_DISPLAY, I_DARK_MODE, I_SECOND_HAND, I_3D_EFFECTS, I_DM_ON, I_DM_OFF, I_SIZE }
    // Configuration item display names
    private var _itemNames as Array<String> = ["Battery Level", "Date Display", "Dark Mode", "Seconds in Sleep", "3D Effects", "Turn On", "Turn Off"] as Array<String>;
    // Configuration item labels only used as keys for storing the configuration values. Using these for persistent storage, rather than Item is more robust.
    private var _itemLabels as Array<String> = ["battery", "dateDisplay", "darkMode", "secondHand", "3deffects", "dmOn", "dmOff"] as Array<String>;

    // Options for list and toggle configuration items. Using enums, the compiler can help detect issues like typos or outdated values.
    enum { O_BATTERY_OFF, O_BATTERY_CLASSIC_WARN, O_BATTERY_MODERN_WARN, O_BATTERY_CLASSIC, O_BATTERY_MODERN, O_BATTERY_HYBRID }
    enum { O_DATE_DISPLAY_OFF, O_DATE_DISPLAY_DAY_ONLY, O_DATE_DISPLAY_WEEKDAY_AND_DAY }
    enum { O_DARK_MODE_SCHEDULED, O_DARK_MODE_OFF, O_DARK_MODE_ON }
    enum { O_SECOND_HAND_ON, O_SECOND_HAND_LIGHT, O_SECOND_HAND_OFF }
    enum { O_3D_EFFECTS_ON, O_3D_EFFECTS_OFF }

    // Option labels for list items. One for each of the enum values above.
    private var _labels as Dictionary<Item, Array<String> > = {
        I_BATTERY      => ["Off", "Classic Warnings", "Modern Warnings", "Classic", "Modern", "Hybrid"],
        I_DATE_DISPLAY => ["Off", "Day Only", "Weekday and Day"],
        I_DARK_MODE    => ["Scheduled", "Off", "On"],
        I_SECOND_HAND  => ["Off in Dark Mode", "Off", "On"]
    } as Dictionary<Item, Array<String> >;

    // Option labels for simple On/Off toggle items. Used in ToggleMenuItem.
    static const ON_OFF_OPTIONS = {:enabled=>"On", :disabled=>"Off"};

    private var _values as Dictionary<Item, Number>;  // Values for the configuration items
    private var _hasAlpha as Boolean; // Indicates if the device supports an alpha channel; required for the 3D effects

    //! Constructor
    public function initialize() {
        _hasAlpha = (Graphics has :createColor) and (Graphics.Dc has :setFill); // Both should be available from API Level 4.0.0, but the Venu Sq 2 only has :createColor
        _values = {} as Dictionary<Item, Number>;
        // Read the configuration values from persistent storage 
        for (var id = 0; id < I_SIZE; id++) {
            var value = Storage.getValue(_itemLabels[id]) as Number;
            switch (id) {
                case: I_3D_EFFECTS:
                    if (null == value) { value = 0; }
                    // Make sure the value is compatible with the device capabilities, so the watchface code can rely on getValue() alone.
                    if (!_hasAlpha and O_3D_EFFECTS_ON == value) { value = O_3D_EFFECTS_OFF; }
                    break;
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
            }
            if (null == value) { value = 0; }
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
            case I_SECOND_HAND:
                var label = _labels[id] as Array<String>;
                option = label[value];
                break;
            case I_DM_ON:
            case I_DM_OFF:
                option = (value as Number / 60).toNumber() + ":" + (value as Number % 60).format("%02d");
                break;
            case I_3D_EFFECTS:
                System.println("ERROR: Config.getLabel() is not implemented for id = " + id);
                break;
        }
        return option;
    }

    //! Return the current value of the specified setting.
    //!@param id Setting
    //!@return The current value of the setting
    public function getValue(id as Item) as Number {
        return _values[id] as Number;
    }

    //! Return the name for the specified setting.
    //!@param id Setting
    //!@return Setting name
    public function getName(id as Item) as String {
        return _itemNames[id as Number];
    }

    //! Advance the setting to the next value.
    //!@param id Setting
    public function setNext(id as Item) as Void {
        var value = _values[id];
        switch (id) {
            case I_BATTERY:
            case I_DATE_DISPLAY:
            case I_DARK_MODE:
            case I_SECOND_HAND:
                var label = _labels[id] as Array<String>;
                _values[id] = (value as Number + 1) % label.size();
                Storage.setValue(_itemLabels[id as Number], _values[id]);
                break;
            case I_3D_EFFECTS:
                _values[id] = (value as Number + 1) % 2;
                Storage.setValue(_itemLabels[id as Number], _values[id]);
                break;
            case I_DM_ON:
            case I_DM_OFF:
                System.println("ERROR: Config.setNext() is not implemented for id = " + id);
                break;
        }
    }

    public function setValue(id as Item, value as Number) as Void {
        _values[id] = value;
        Storage.setValue(_itemLabels[id as Number], _values[id]);
    }

    // Returns true if the device supports an alpha channel, false if not.
    public function hasAlpha() as Boolean {
        return _hasAlpha;
    }
}

//! The app settings menu
class SettingsMenu extends WatchUi.Menu2 {
    //! Constructor
    public function initialize() {
        Menu2.initialize({:title=>"Settings"});
        Menu2.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_BATTERY), $.config.getLabel($.Config.I_BATTERY), $.Config.I_BATTERY, {}));
        Menu2.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_DATE_DISPLAY), $.config.getLabel($.Config.I_DATE_DISPLAY), $.Config.I_DATE_DISPLAY, {}));
        Menu2.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_DARK_MODE), $.config.getLabel($.Config.I_DARK_MODE), $.Config.I_DARK_MODE, {}));
        // Add menu items for the dark mode on and off times only if dark mode is set to "Scheduled"
        if ($.Config.O_DARK_MODE_SCHEDULED == $.config.getValue($.Config.I_DARK_MODE)) {
            Menu2.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_DM_ON), $.config.getLabel($.Config.I_DM_ON), $.Config.I_DM_ON, {}));
            Menu2.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_DM_OFF), $.config.getLabel($.Config.I_DM_OFF), $.Config.I_DM_OFF, {}));
        }
        Menu2.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_SECOND_HAND), $.config.getLabel($.Config.I_SECOND_HAND), $.Config.I_SECOND_HAND, {}));
        if ($.config.hasAlpha()) {
            Menu2.addItem(new WatchUi.ToggleMenuItem(
                $.config.getName($.Config.I_3D_EFFECTS), 
                $.Config.ON_OFF_OPTIONS,
                $.Config.I_3D_EFFECTS, 
                $.Config.O_3D_EFFECTS_ON == $.config.getValue($.Config.I_3D_EFFECTS), 
                {}
            ));
        }
    }

    public function onShow() as Void {
        Menu2.onShow();
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
}

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
            case $.Config.I_BATTERY:
            case $.Config.I_DATE_DISPLAY:
            case $.Config.I_SECOND_HAND:
                // Advance to the next option and show the selected option as the sub label
                $.config.setNext(id);
                menuItem.setSubLabel($.config.getLabel(id));
                break;
            case $.Config.I_DARK_MODE:
                // Advance to the next option and show the selected option as the sub label
                $.config.setNext(id);
                menuItem.setSubLabel($.config.getLabel(id));
                // If "Scheduled" is selected, add menu items to set the dark mode on and off times, else delete them
                if ($.Config.O_DARK_MODE_SCHEDULED == $.config.getValue(id)) {
                    // Delete and then re-add the second hand and 3D effects menu items, to keep them after the dark mode schedule times
                    var idx = _menu.findItemById($.Config.I_SECOND_HAND);
                    if (-1 != idx) { _menu.deleteItem(idx); }
                    idx = _menu.findItemById($.Config.I_3D_EFFECTS);
                    if (-1 != idx) { _menu.deleteItem(idx); }
                    _menu.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_DM_ON), $.config.getLabel($.Config.I_DM_ON), $.Config.I_DM_ON, {}));
                    _menu.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_DM_OFF), $.config.getLabel($.Config.I_DM_OFF), $.Config.I_DM_OFF, {}));
                    _menu.addItem(new WatchUi.MenuItem($.config.getName($.Config.I_SECOND_HAND), $.config.getLabel($.Config.I_SECOND_HAND), $.Config.I_SECOND_HAND, {}));
                    if ($.config.hasAlpha()) {
                        _menu.addItem(new WatchUi.ToggleMenuItem(
                            $.config.getName($.Config.I_3D_EFFECTS), 
                            $.Config.ON_OFF_OPTIONS,
                            $.Config.I_3D_EFFECTS, 
                            $.Config.O_3D_EFFECTS_ON == $.config.getValue($.Config.I_3D_EFFECTS), 
                            {}
                        ));
                    }
                } else {
                    var idx = _menu.findItemById($.Config.I_DM_ON);
                    if (-1 != idx) { _menu.deleteItem(idx); }
                    idx = _menu.findItemById($.Config.I_DM_OFF);
                    if (-1 != idx) { _menu.deleteItem(idx); }
                }
                break;
            case $.Config.I_3D_EFFECTS:
                // Toggle the two possible configuration values
                $.config.setNext(id);
                break;
            case $.Config.I_DM_ON:
            case $.Config.I_DM_OFF:
                // Let the user select the time
                WatchUi.pushView(new TimePicker(id), new TimePickerDelegate(id), WatchUi.SLIDE_IMMEDIATE);
                break;
        }
  	}
}
