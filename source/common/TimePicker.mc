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
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// A simple time picker. It's only a class so that we can implement onLayout(), to
// fix some display issues on both, my fr955 device and the sim, otherwise we could
// just use Picker itself.
// Also, it depends on the global settings class, which is not very nice. That could be
// fixed easily, however the delegate also has the same issue and is more
// difficult to fix.
// The result sort of works but doesn't look good at all. It's really too bad that 
// Garmin doesn't make their own time picker available as an API. The one that is 
// used to set an alarm on the fr955 looks great and would allow developers to build
// apps with a more consistent look and feel.
class TimePicker extends WatchUi.Picker {
    // Constructor
    public function initialize(id as Config.Item) {
        var title = new WatchUi.Text({
            :text=>config.getName(id),
            :font=>Graphics.FONT_SMALL,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER,
            :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, 
            :color=>Graphics.COLOR_WHITE
        });

        var is24Hour = System.getDeviceSettings().is24Hour;
        var factories = new Array<PickerFactory or Text>[is24Hour ? 3 : 4];
        factories[0] = new TimeFactory(TimeFactory.T_HOUR, is24Hour);
        factories[1] = new WatchUi.Text({
            :text=>":",
            :font=>Graphics.FONT_MEDIUM,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER,
            :locY=>WatchUi.LAYOUT_VALIGN_CENTER,
            :color=>Graphics.COLOR_WHITE 
        });
        factories[2] = new TimeFactory(TimeFactory.T_MINUTE, is24Hour);
        if (!is24Hour) { factories[3] = new AmPmFactory(); }

        var defaults = new Array<Number>[is24Hour ? 3 : 4];
        var value = config.getValue(id);
        defaults[0] = (value / 60).toNumber();
        defaults[1] = 0;
        defaults[2] = value % 60;
        if (!is24Hour) {
            defaults[3] = defaults[0] < 12 ? 0 : 1;
            defaults[0] %= 12; 
        }

        Picker.initialize({:title=>title, :pattern=>factories, :defaults=>defaults});
    }

    // This is needed to show the title (on both, the watch and the sim) and clear the background (sim)
    public function onLayout(dc as Dc) as Void {
        dc.clearClip();
    }
}

class TimeFactory extends WatchUi.PickerFactory {
    public enum Mode { T_HOUR, T_MINUTE }
    private var _mode as Mode;
    private var _is24Hour as Boolean;
    private var _stop as Number;
    private var _format as String;

    public function initialize(mode as Mode, is24Hour as Boolean) {
        PickerFactory.initialize();
        _mode = mode;
        _is24Hour = is24Hour;
        if (T_HOUR == mode) {
            _stop = _is24Hour ? 23 : 11;
            _format = "%d";
        } else { // T_MINUTE == mode
            _stop = 59;
            _format = "%02d";
        }
    }

    public function getDrawable(item as Number, isSelected as Boolean) as Drawable? {
        if (T_HOUR == _mode and !_is24Hour and 0 == item) { item = 12; } 
        return new WatchUi.Text({
            :text=>item.format(_format),
            :font=>Graphics.FONT_MEDIUM,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, 
            :locY=>WatchUi.LAYOUT_VALIGN_CENTER, 
            :color=>Graphics.COLOR_WHITE 
        });
    }

    public function getValue(item as Number) as Object? {
        return item;
    }

    public function getSize() as Number { 
        return _stop + 1;
    }
}

class AmPmFactory extends WatchUi.PickerFactory {
    private var _values as Array<String>;

    public function initialize() {
        PickerFactory.initialize();
        _values = ["am", "pm"] as Array<String>;
    }

    public function getDrawable(item as Number, isSelected as Boolean) as Drawable? {
        return new WatchUi.Text({
            :text=>_values[item],
            :font=>Graphics.FONT_MEDIUM,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, 
            :locY=>WatchUi.LAYOUT_VALIGN_CENTER, 
            :color=>Graphics.COLOR_WHITE 
        });
    }

    public function getValue(item as Number) as Object? {
        return item;
    }

    public function getSize() as Number { 
        return _values.size();
    }
}

class TimePickerDelegate extends WatchUi.PickerDelegate {
    private var _id as Config.Item;

    public function initialize(id as Config.Item) {
        PickerDelegate.initialize();
        _id = id;
    }

    public function onAccept(values as Array) as Boolean {
        var pm = 4 == values.size() and 1 == values[3] as Number ? 12 : 0;
        config.setValue(_id, (values[0] as Number + pm) * 60 + values[2] as Number);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    public function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
