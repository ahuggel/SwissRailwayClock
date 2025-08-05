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
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// The view for the on-device settings menu
class SettingsView extends WatchUi.Menu2 {
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
                addMenuItem(Config.I_COMPLICATION_1);
                addMenuItem(Config.I_COMPLICATION_2);
                addMenuItem(Config.I_COMPLICATION_3);
                addMenuItem(Config.I_COMPLICATION_4);
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
                        new MenuIcon(MenuIcon.T_TRIANGLE, config.getContrastColor(), Graphics.COLOR_BLACK),
                        {}
                    ));
                }
                addMenuItem(Config.I_HIDE_SECONDS);
                Menu2.addItem(new WatchUi.IconMenuItem(
                    config.getName(Config.I_ACCENT_COLOR), 
                    config.getLabel(Config.I_ACCENT_COLOR), 
                    Config.I_ACCENT_COLOR,
                    new MenuIcon(MenuIcon.T_CIRCLE, config.getAccentColor(-1, -1, -1), config.colors[Config.C_BACKGROUND]),
                    {}
                ));
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
                deleteAnyItem(Config.I_COMPLICATION_1);
                deleteAnyItem(Config.I_COMPLICATION_2);
                deleteAnyItem(Config.I_COMPLICATION_3);
                deleteAnyItem(Config.I_COMPLICATION_4);
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
} // class SettingsView

// Input handler for the on-device settings menu
class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as SettingsView;

    // Constructor
    public function initialize(menu as SettingsView) {
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
            if (   Config.I_COMPLICATION_1 == id 
                or Config.I_COMPLICATION_2 == id
                or Config.I_COMPLICATION_3 == id
                or Config.I_COMPLICATION_4 == id) {
                // Skip options that are not supported by the device
                while (!config.hasRequiredFeature(config.getOption(id) as Symbol)) {
                    config.setNext(id);
                }
            }
            menuItem.setSubLabel(config.getLabel(id));
            if (Config.I_BATTERY == id or Config.I_DARK_MODE == id) {
                // Delete all the following menu items, rebuild the menu with only the items required
                _menu.deleteMenu(id);
                _menu.buildMenu(id);
            }
            if (Config.I_DM_CONTRAST == id) {
                // Update the color of the icon
                var menuIcon = menuItem.getIcon() as MenuIcon;
                menuIcon.setColor(config.getContrastColor());
            }
            if (Config.I_ACCENT_COLOR == id) {
                // Update the color of the icon
                var menuIcon = menuItem.getIcon() as MenuIcon;
                menuIcon.setColor(config.getAccentColor(-1, -1, -1));
            }
        } else { // I_DM_ON or I_DM_OFF
            // Let the user select the time
            WatchUi.pushView(new TimePicker(id), new TimePickerDelegate(id), WatchUi.SLIDE_IMMEDIATE);
        }
  	}
} // class SettingsDelegate
