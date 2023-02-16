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
import Toybox.Lang;
import Toybox.WatchUi;

//! Global variable that keeps track of the settings and makes them available to the app.
var config as Config = new $.Config();

//! This class maintains application settings and synchronises them to persistent storage.
class Config {
    // Configuration item identifiers
    enum Item { I_BATTERY, I_DARK_MODE, I_DATE_DISPLAY, I_SECOND_HAND, I_3D_EFFECTS, I_DM_ON, I_DM_OFF }
    // Configuration item labels used as keys for storing the configuration values
    private var _itemLabels as Array<String> = ["battery", "darkMode", "dateDisplay", "secondHand", "3deffects", "dmOn", "dmOff"] as Array<String>;
    // Configuration item display names
    private var _itemNames as Array<String> = ["Battery Level", "Dark Mode", "Date Display", "Seconds in Sleep", "3D Effects", "Turn On", "Turn Off"] as Array<String>;

    // Options for list and toggle items
    enum { S_BATTERY_OFF, S_BATTERY_CLASSIC_WARN, S_BATTERY_MODERN_WARN, S_BATTERY_CLASSIC, S_BATTERY_MODERN, S_BATTERY_HYBRID }
    enum { S_DATE_DISPLAY_OFF, S_DATE_DISPLAY_DAY_ONLY, S_DATE_DISPLAY_WEEKDAY_AND_DAY }
    enum { S_DARK_MODE_SCHEDULED, S_DARK_MODE_OFF, S_DARK_MODE_ON }
    enum { S_SECOND_HAND_ON, S_SECOND_HAND_OFF }
    enum { S_3D_EFFECTS_ON, S_3D_EFFECTS_OFF }

    // Option labels for simple On/Off toggle items
    static const ON_OFF_OPTIONS = {:enabled=>"On", :disabled=>"Off"};

    // Option labels for list items
    private var _batteryOptions as Array<String> = ["Off", "Classic Warnings", "Modern Warnings", "Classic", "Modern", "Hybrid"] as Array<String>;
    private var _darkModeOptions as Array<String> = ["Scheduled", "Off", "On"] as Array<String>;
    private var _dateDisplayOptions as Array<String> = ["Off", "Day Only", "Weekday and Day"] as Array<String>;

    // Values for the configuration items
    private var _batteryIdx as Number;
    private var _darkModeIdx as Number;
    private var _dateDisplayIdx as Number;
    private var _secondHandIdx as Number;
    private var _3dEffectsIdx as Number;
    private var _dmOnTime as Number;
    private var _dmOffTime as Number;

    //! Constructor
    public function initialize() {
        _batteryIdx = Storage.getValue(_itemLabels[I_BATTERY]) as Number;
        if (_batteryIdx == null) {
            _batteryIdx = 0;
        }
        _darkModeIdx = Storage.getValue(_itemLabels[I_DARK_MODE]) as Number;
        if (_darkModeIdx == null) {
            _darkModeIdx = 0;
        }
        _dateDisplayIdx = Storage.getValue(_itemLabels[I_DATE_DISPLAY]) as Number;
        if (_dateDisplayIdx == null) {
            _dateDisplayIdx = 0;
        }
        _secondHandIdx = Storage.getValue(_itemLabels[I_SECOND_HAND]) as Number;
        if (_secondHandIdx == null) {
            _secondHandIdx = 0;
        }
        _3dEffectsIdx = Storage.getValue(_itemLabels[I_3D_EFFECTS]) as Number;
        if (_3dEffectsIdx == null) {
            _3dEffectsIdx = 0;
        }
        _dmOnTime = Storage.getValue(_itemLabels[I_DM_ON]) as Number;
        if (_dmOnTime == null or _dmOnTime < 0 or _dmOnTime > 1439) {
            _dmOnTime = 1320; // Default time to turn dark mode on: 22:00
        }
        _dmOffTime = Storage.getValue(_itemLabels[I_DM_OFF]) as Number;
        if (_dmOffTime == null or _dmOffTime < 0 or _dmOffTime > 1439) {
            _dmOffTime = 420; // Default time to turn dark more off: 07:00
        }
    }

    //! Return the current label for the specified setting.
    //!@param id Setting
    //!@return Label of the currently selected option
    public function getLabel(id as Item) as String {
        var option = "";
        switch (id) {
            case I_BATTERY:
                option = _batteryOptions[_batteryIdx];
                break;
            case I_DARK_MODE:
                option = _darkModeOptions[_darkModeIdx];
                break;
            case I_DATE_DISPLAY:
                option = _dateDisplayOptions[_dateDisplayIdx];
                break;
            case I_DM_ON:
                option = (_dmOnTime / 60).toNumber() + ":" + (_dmOnTime % 60).format("%02d");
                break;
            case I_DM_OFF:
                option = (_dmOffTime / 60).toNumber() + ":" + (_dmOffTime % 60).format("%02d");
                break;
            case I_SECOND_HAND:
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
        var value = -1;
        switch (id) {
            case I_BATTERY:
                value = _batteryIdx;
                break;
            case I_DARK_MODE:
                value = _darkModeIdx;
                break;
            case I_DATE_DISPLAY:
                value = _dateDisplayIdx;
                break;
            case I_SECOND_HAND:
                value = _secondHandIdx;
                break;
            case I_3D_EFFECTS:
                value = _3dEffectsIdx;
                break;
            case I_DM_ON:
                value = _dmOnTime;
                break;
            case I_DM_OFF:
                value = _dmOffTime;
        }
        return value;
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
        switch (id) {
            case I_BATTERY:
                _batteryIdx = (_batteryIdx + 1) % _batteryOptions.size();
                Storage.setValue(_itemLabels[I_BATTERY], _batteryIdx);
                break;
            case I_DARK_MODE:
                _darkModeIdx = (_darkModeIdx + 1) % _darkModeOptions.size();
                Storage.setValue(_itemLabels[I_DARK_MODE], _darkModeIdx);
                break;
            case I_DATE_DISPLAY:
                _dateDisplayIdx = (_dateDisplayIdx + 1) % _dateDisplayOptions.size();
                Storage.setValue(_itemLabels[I_DATE_DISPLAY], _dateDisplayIdx);
                break;
            case I_SECOND_HAND:
                _secondHandIdx = (_secondHandIdx + 1) % 2;
                Storage.setValue(_itemLabels[I_SECOND_HAND], _secondHandIdx);
                break;
            case I_3D_EFFECTS:
                _3dEffectsIdx = (_3dEffectsIdx + 1) % 2;
                Storage.setValue(_itemLabels[I_3D_EFFECTS], _3dEffectsIdx);
                break;
            case I_DM_ON:
            case I_DM_OFF:
                System.println("ERROR: Config.setNext() is not implemented for id = " + id);
                break;
        }
    }

    public function setValue(id as Item, value as Number) as Void {
        switch (id) {
            case I_DM_ON:
                _dmOnTime = value;
                Storage.setValue(_itemLabels[I_DM_ON], _dmOnTime);
                break;
            case I_DM_OFF:
                _dmOffTime = value;
                Storage.setValue(_itemLabels[I_DM_OFF], _dmOffTime);
                break;
            case I_BATTERY:
            case I_DARK_MODE:
            case I_DATE_DISPLAY:
            case I_SECOND_HAND:
            case I_3D_EFFECTS:
                System.println("ERROR: Config.setValue() is not implemented for id = " + id);
                break;
        }
    }
}

//! The app settings menu
class SettingsMenu extends WatchUi.Menu2 {
    //! Constructor
    public function initialize() {
        Menu2.initialize({:title=>"Settings"});
        Menu2.addItem(new WatchUi.MenuItem(config.getName(Config.I_BATTERY), config.getLabel(Config.I_BATTERY), Config.I_BATTERY, {}));
        Menu2.addItem(new WatchUi.MenuItem(config.getName(Config.I_DATE_DISPLAY), config.getLabel(Config.I_DATE_DISPLAY), Config.I_DATE_DISPLAY, {}));
        Menu2.addItem(new WatchUi.MenuItem(config.getName(Config.I_DARK_MODE), config.getLabel(Config.I_DARK_MODE), Config.I_DARK_MODE, {}));
        // Add menu items for the dark mode on and off times only if dark mode is set to "Scheduled"
        if (Config.S_DARK_MODE_SCHEDULED == config.getValue(Config.I_DARK_MODE)) {
            Menu2.addItem(new WatchUi.MenuItem(config.getName(Config.I_DM_ON), config.getLabel(Config.I_DM_ON), Config.I_DM_ON, {}));
            Menu2.addItem(new WatchUi.MenuItem(config.getName(Config.I_DM_OFF), config.getLabel(Config.I_DM_OFF), Config.I_DM_OFF, {}));
        }
        Menu2.addItem(new WatchUi.ToggleMenuItem(
            config.getName(Config.I_SECOND_HAND), 
            Config.ON_OFF_OPTIONS,
            Config.I_SECOND_HAND, 
            Config.S_SECOND_HAND_ON == config.getValue(Config.I_SECOND_HAND), 
            {}
        ));
        Menu2.addItem(new WatchUi.ToggleMenuItem(
            config.getName(Config.I_3D_EFFECTS), 
            Config.ON_OFF_OPTIONS,
            Config.I_3D_EFFECTS, 
            Config.S_3D_EFFECTS_ON == config.getValue(Config.I_3D_EFFECTS), 
            {}
        ));
    }

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
            case Config.I_BATTERY:
            case Config.I_DATE_DISPLAY:
                // Advance to the next option and show the selected option as the sub label
                config.setNext(id);
                menuItem.setSubLabel(config.getLabel(id));
                break;
            case Config.I_DARK_MODE:
                // Advance to the next option and show the selected option as the sub label
                config.setNext(id);
                menuItem.setSubLabel(config.getLabel(id));
                // If "Scheduled" is selected, add menu items to set the dark mode on and off times, else delete them
                if (Config.S_DARK_MODE_SCHEDULED == config.getValue(id)) {
                    // Delete and then re-add the second hand and 3D effects menu items, to keep them after the dark mode schedule times
                    var idx = _menu.findItemById(Config.I_SECOND_HAND);
                    if (-1 != idx) { _menu.deleteItem(idx); }
                    idx = _menu.findItemById(Config.I_3D_EFFECTS);
                    if (-1 != idx) { _menu.deleteItem(idx); }
                    _menu.addItem(new WatchUi.MenuItem(config.getName(Config.I_DM_ON), config.getLabel(Config.I_DM_ON), Config.I_DM_ON, {}));
                    _menu.addItem(new WatchUi.MenuItem(config.getName(Config.I_DM_OFF), config.getLabel(Config.I_DM_OFF), Config.I_DM_OFF, {}));
                    _menu.addItem(new WatchUi.ToggleMenuItem(
                        config.getName(Config.I_SECOND_HAND), 
                        Config.ON_OFF_OPTIONS,
                        Config.I_SECOND_HAND,
                        Config.S_SECOND_HAND_ON == config.getValue(Config.I_SECOND_HAND), 
                        {}
                    ));
                    _menu.addItem(new WatchUi.ToggleMenuItem(
                        config.getName(Config.I_3D_EFFECTS), 
                        Config.ON_OFF_OPTIONS,
                        Config.I_3D_EFFECTS, 
                        Config.S_3D_EFFECTS_ON == config.getValue(Config.I_3D_EFFECTS), 
                        {}
                    ));
                } else {
                    var idx = _menu.findItemById(Config.I_DM_ON);
                    if (-1 != idx) { _menu.deleteItem(idx); }
                    idx = _menu.findItemById(Config.I_DM_OFF);
                    if (-1 != idx) { _menu.deleteItem(idx); }
                }
                break;
            case Config.I_SECOND_HAND:
            case Config.I_3D_EFFECTS:
                // Toggle the two possible configuration values
                config.setNext(id);
                break;
            case Config.I_DM_ON:
            case Config.I_DM_OFF:
                // Let the user select the time
                WatchUi.pushView(new TimePicker(id), new TimePickerDelegate(id), WatchUi.SLIDE_IMMEDIATE);
                break;
        }
  	}
}
