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
import Toybox.System;
import Toybox.WatchUi;

//! Global variable that keeps track of the settings and makes them available to the app.
var settings as SwissRailwayClockSettings = new $.SwissRailwayClockSettings();

//! This class maintains application settings and synchronises them to persistent storage.
//! For clarity, it currently only interfaces via setting ids and setting names.
//! TODO: should there be some kind of onSettingsChanged callback mechanism?
class SwissRailwayClockSettings {
    // "darkMode" - setting id
    // "Dark Mode" - setting name
    // "Auto", "Off", "On" - setting options, the selected option is the selection
    // 0, 1, 2 - setting index
    enum { S_DARK_MODE_AUTO, S_DARK_MODE_OFF, S_DARK_MODE_ON }
    enum { S_DATE_DISPLAY_OFF, S_DATE_DISPLAY_DAY_ONLY, S_DATE_DISPLAY_WEEKDAY_AND_DAY }
    enum { S_IMAGE_NONE, S_IMAGE_CANDLE, S_IMAGE_LEAVES, S_IMAGE_HAT }

    private var _darkModeOptions as Array<String> = ["Auto", "Off", "On"] as Array<String>;
    private var _dateDisplayOptions as Array<String> = ["Off", "Day Only", "Weekday and Day"] as Array<String>;
    private var _imageOptions as Array<String> = ["None", "Candle", "Leaves", "Hat"] as Array<String>;

    private var _darkModeIdx as Number;
    private var _dateDisplayIdx as Number;
    private var _imageIdx as Number;

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
            case "image":
                option = _imageOptions[_imageIdx];
                break;
        }
        return option;
    }

    //! Return the current value of the specified setting.
    //!@param id Setting
    //!@return The current value of the setting
    public function getValue(id as String) as Number {
        var idx = -1;
        switch (id) {
            case "darkMode":
                idx = _darkModeIdx;
                break;
            case "dateDisplay":
                idx = _dateDisplayIdx;
                break;
            case "image":
                idx = _imageIdx;
                break;
        }
        return idx;
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
            case "image":
                _imageIdx = (_imageIdx + 1) % _imageOptions.size();
                Storage.setValue(id, _imageIdx);
                break;
        }
    }
}

//! The app settings menu
class SwissRailwayClockSettingsMenu extends WatchUi.Menu2 {
    //! Constructor
    public function initialize() {
        Menu2.initialize({:title=>"Settings"});
        Menu2.addItem(new WatchUi.MenuItem("Dark Mode", settings.getLabel("darkMode"), "darkMode", {}));
        Menu2.addItem(new WatchUi.MenuItem("Date Display", settings.getLabel("dateDisplay"), "dateDisplay", {}));
        Menu2.addItem(new WatchUi.MenuItem("X-Mas Image", settings.getLabel("image"), "image", {}));
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
        settings.setNext(id);
        menuItem.setSubLabel(settings.getLabel(id));
  	}
  	
  	public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

