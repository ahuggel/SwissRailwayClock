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
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

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
                    if (System.Stats has :batteryInDays) { 
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
                addMenuItem(Config.I_DARK_MODE);
                //Fallthrough
            case Config.I_DARK_MODE:
                // Add menu items for the dark mode on and off times only if dark mode is set to "Scheduled"
                if (:DarkModeScheduled == config.getOption(Config.I_DARK_MODE)) {
                    addMenuItem(Config.I_DM_ON);
                    addMenuItem(Config.I_DM_OFF);
                }
                addMenuItem(Config.I_HIDE_SECONDS);
                addMenuItem(Config.I_ACCENT_COLOR);
                addMenuItem(Config.I_ACCENT_CYCLE);
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
                deleteAnyItem(Config.I_DARK_MODE);
                // Fallthrough
            case Config.I_DARK_MODE:
                // Delete all dark mode and following menu items
                deleteAnyItem(Config.I_DM_ON);
                deleteAnyItem(Config.I_DM_OFF);
                deleteAnyItem(Config.I_HIDE_SECONDS);
                deleteAnyItem(Config.I_ACCENT_COLOR);
                deleteAnyItem(Config.I_ACCENT_CYCLE);
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
        } else { // I_DM_ON or I_DM_OFF
            // Let the user select the time
            WatchUi.pushView(new TimePicker(id), new TimePickerDelegate(id), WatchUi.SLIDE_IMMEDIATE);
        }
  	}
} // class SettingsMenuDelegate
