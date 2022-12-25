//
// Swiss Railway Clock
// https://www.eguide.ch/de/objekt/sbb-bahnhofsuhr/
//
// Copyright 2022 by Andreas Huggel
// 

import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Global variable that keeps track of the settings and makes them available to the app.
var settings as SwissRailwayClockSettings = new $.SwissRailwayClockSettings();

class SwissRailwayClockSettings {
    private var _darkModeIdx as Number;
    private var _darkModeOptions as Array<String> = ["Auto", "Off", "On"] as Array<String>;

    private var _dateDisplayIdx as Number;
    private var _dateDisplayOptions as Array<String> = ["Off", "Day Only", "Weekday and Day"] as Array<String>;

    private var _imageIdx as Number;
    private var _imageOptions as Array<String> = ["None", "Candle", "Leaves", "Hat"] as Array<String>;

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
        _imageIdx = Storage.getValue("image") as Number;
        if (_imageIdx == null) {
            _imageIdx = 0;
        }
    }

    // "darkMode" - setting id
    // "Dark Mode" - setting name
    // "Auto", "Off", "On" - setting options, the selected option is the selection
    // 0, 1, 2 - setting index

    //! Return the selected option for the specified setting.
    //!@param id Setting
    //!@return The currently selected option
    public function selection(id as String) as String {
        var option = "";
        switch (id) {
            case "darkMode":
                option = _darkModeOptions[_darkModeIdx];
                break;
            case "dateDisplay":
                option = _dateDisplayOptions[_dateDisplayIdx];
                break;
            case "image":
                option = _imageOptions[_imageIdx];
                break;
        }
        return option;
    }

    //! Return the selected option for the specified setting.
    //!@param id Setting
    //!@return 
    public function setNext(id as String) as Number {
        var idx = -1;
        switch (id) {
            case "darkMode":
                _darkModeIdx = (_darkModeIdx + 1) % _darkModeOptions.size();
                idx = _darkModeIdx;
                break;
            case "dateDisplay":
                _dateDisplayIdx = (_dateDisplayIdx + 1) % _dateDisplayOptions.size();
                idx = _dateDisplayIdx;
                break;
            case "image":
                _imageIdx = (_imageIdx + 1) % _imageOptions.size();
                idx = _imageIdx;
                break;
        }
        return idx;
    }
}

//! The app settings menu
class SwissRailwayClockSettingsMenu extends WatchUi.Menu2 {
    //! Constructor
    public function initialize() {
        Menu2.initialize({:title=>"Settings"});
        Menu2.addItem(new WatchUi.MenuItem("Dark Mode", settings.selection("darkMode"), "darkMode", {}));
        Menu2.addItem(new WatchUi.MenuItem("Date Display", settings.selection("dateDisplay"), "dateDisplay", {}));
        Menu2.addItem(new WatchUi.MenuItem("X-Mas Image", settings.selection("image"), "image", {}));
    }
}

//! Input handler for the app settings menu
class SwissRailwayClockSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    //! Constructor
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    //! Handle a menu item being selected
    //! @param menuItem The menu item selected
    public function onSelect(menuItem as MenuItem) as Void {
        var id = menuItem.getId() as String;
        var idx = settings.setNext(id);
        Storage.setValue(id, idx);
        menuItem.setSubLabel(settings.selection(id));
  	}
  	
  	public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

