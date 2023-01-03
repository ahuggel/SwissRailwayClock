//
// Swiss Railway Clock
// https://www.eguide.ch/de/objekt/sbb-bahnhofsuhr/
//
// Copyright 2022 by Andreas Huggel
// 
// This started from the Garmin Analog sample program; there may be some terminology from that left.
// That sample program is Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables Application Developer Agreement.
//
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.WatchUi;

//! Global variable that keeps track of the settings and makes them available to the app.
var settings as ClockSettings = new $.ClockSettings();

//! This class maintains application settings and synchronises them to persistent storage.
class ClockSettings {
    enum { S_DARK_MODE_AUTO, S_DARK_MODE_OFF, S_DARK_MODE_ON }
    enum { S_DATE_DISPLAY_OFF, S_DATE_DISPLAY_DAY_ONLY, S_DATE_DISPLAY_WEEKDAY_AND_DAY }

    private var _darkModeOptions as Array<String> = ["Auto", "Off", "On"] as Array<String>;
    private var _dateDisplayOptions as Array<String> = ["Off", "Day Only", "Weekday and Day"] as Array<String>;
    private var _darkModeIdx as Number;
    private var _dateDisplayIdx as Number;
    private var _dmOnTime as Number;
    private var _dmOffTime as Number;

    //! Constructor
    public function initialize() {
        _darkModeIdx = Storage.getValue("darkMode") as Number;
        if (_darkModeIdx == null) {
            _darkModeIdx = 0;
        }
        _dateDisplayIdx = Storage.getValue("dateDisplay") as Number;
        if (_dateDisplayIdx == null) {
            _dateDisplayIdx = 0;
        }
        _dmOnTime = Storage.getValue("dmOn") as Number;
        if (_dmOnTime == null) {
            _dmOnTime = 1200; // Default time to turn dark mode on: 20:00
        }
        _dmOffTime = Storage.getValue("dmOff") as Number;
        if (_dmOffTime == null) {
            _dmOffTime = 420; // Default time to turn dark more off: 07:00
        }
    }

    //! Return the current label for the specified setting.
    //!@param id Setting
    //!@return Label of the currently selected option
    public function getLabel(id as String) as String {
        var option = "";
        switch (id) {
            case "darkMode":
                option = _darkModeOptions[_darkModeIdx];
                break;
            case "dateDisplay":
                option = _dateDisplayOptions[_dateDisplayIdx];
                break;
            case "dmOn":
                option = (_dmOnTime / 60).toNumber() + ":" + (_dmOnTime % 60).format("%02d");
                break;
            case "dmOff":
                option = (_dmOffTime / 60).toNumber() + ":" + (_dmOffTime % 60).format("%02d");
                break;
        }
        return option;
    }

    //! Return the current value of the specified setting.
    //!@param id Setting
    //!@return The current value of the setting
    public function getValue(id as String) as Number {
        var value = -1;
        switch (id) {
            case "darkMode":
                value = _darkModeIdx;
                break;
            case "dateDisplay":
                value = _dateDisplayIdx;
                break;
            case "dmOn":
                value = _dmOnTime;
                break;
            case "dmOff":
                value = _dmOffTime;
        }
        return value;
    }

    //! Return the name for the specified setting.
    //!@param id Setting
    //!@return Setting name
    public function getName(id as String) as String {
        var name = "";
        switch (id) {
            case "darkMode":
                name = "Dark Mode";
                break;
            case "dateDisplay":
                name = "Date Display";
                break;
            case "dmOn":
                name = "Turn On";
                break;
            case "dmOff":
                name = "Turn Off";
                break;
        }
        return name;
    }

    //! Advance the setting to the next value.
    //!@param id Setting
    public function setNext(id as String) as Void {
        switch (id) {
            case "darkMode":
                _darkModeIdx = (_darkModeIdx + 1) % _darkModeOptions.size();
                Storage.setValue(id, _darkModeIdx);
                break;
            case "dateDisplay":
                _dateDisplayIdx = (_dateDisplayIdx + 1) % _dateDisplayOptions.size();
                Storage.setValue(id, _dateDisplayIdx);
                break;
        }
    }

    public function setValue(id as String, value as Number) as Void {
        switch (id) {
            case "dmOn":
                _dmOnTime = value;
                Storage.setValue(id, _dmOnTime);
                break;
            case "dmOff":
                _dmOffTime = value;
                Storage.setValue(id, _dmOffTime);
                break;
        }
    }
}

//! The app settings menu
class SettingsMenu extends WatchUi.Menu2 {
    //! Constructor
    public function initialize() {
        Menu2.initialize({:title=>"Settings"});
        Menu2.addItem(new WatchUi.MenuItem(settings.getName("dateDisplay"), settings.getLabel("dateDisplay"), "dateDisplay", {}));
        Menu2.addItem(new WatchUi.MenuItem(settings.getName("darkMode"), settings.getLabel("darkMode"), "darkMode", {}));
        // Add menu items for the dark mode on and off times only if dark mode is set to "Auto"
        if (settings.S_DARK_MODE_AUTO == settings.getValue("darkMode")) {
            Menu2.addItem(new WatchUi.MenuItem(settings.getName("dmOn"), settings.getLabel("dmOn"), "dmOn", {}));
            Menu2.addItem(new WatchUi.MenuItem(settings.getName("dmOff"), settings.getLabel("dmOff"), "dmOff", {}));
        }
    }

    public function onShow() as Void {
        Menu2.onShow();
        // Update sub labels in case the dark mode on or off time changed
        var idx = findItemById("dmOn");
        if (-1 != idx) {
            var menuItem = getItem(idx) as MenuItem;
            menuItem.setSubLabel(settings.getLabel("dmOn"));
        }
        idx = findItemById("dmOff");
        if (-1 != idx) {
            var menuItem = getItem(idx) as MenuItem;
            menuItem.setSubLabel(settings.getLabel("dmOff"));
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
        var id = menuItem.getId() as String;
        switch (id) {
            case "dateDisplay":
                // Advance to the next option and show the selected option as the sub label
                settings.setNext(id);
                menuItem.setSubLabel(settings.getLabel(id));
                break;
            case "darkMode":
                // Advance to the next option and show the selected option as the sub label
                settings.setNext(id);
                menuItem.setSubLabel(settings.getLabel(id));
                // If "Auto" is selected, add menu items to set the dark mode on and off times, else delete them
                if (settings.S_DARK_MODE_AUTO == settings.getValue(id)) {
                    _menu.addItem(new WatchUi.MenuItem(settings.getName("dmOn"), settings.getLabel("dmOn"), "dmOn", {}));
                    _menu.addItem(new WatchUi.MenuItem(settings.getName("dmOff"), settings.getLabel("dmOff"), "dmOff", {}));
                } else {
                    var idx = _menu.findItemById("dmOn");
                    if (-1 != idx) { _menu.deleteItem(idx); }
                    idx = _menu.findItemById("dmOff");
                    if (-1 != idx) { _menu.deleteItem(idx); }
                }
                break;    
            case "dmOn":
            case "dmOff":
                // Let the user select the time
                WatchUi.pushView(new TimePicker(id), new TimePickerDelegate(id), WatchUi.SLIDE_IMMEDIATE);
            break;
        }
  	}
}
