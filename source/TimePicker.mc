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
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// A simple time picker. It's only a class so that we can implement onLayout(), to
// fix some display issues on both, my fr955 device and the sim, otherwise we could
// just use Picker itself.
// Also, it depends on the global settings class, which is not nice. That could be
// fixed easily, however the delegate also has the same issue and is more
// difficult to fix.
// The result sort of works but doesn't look good at all. It's really too bad that 
// Garmin doesn't make their own time picker available as an API. The one that is 
// used to set an alarm on the fr955 looks great and would allow developers to build
// apps with a more consistent look and feel.
class TimePicker extends WatchUi.Picker {
    //! Constructor
    public function initialize(id as String) {
        var title = new WatchUi.Text({
            :text=>settings.getName(id),
            :font=>Graphics.FONT_SMALL,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER,
            :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, 
            :color=>Graphics.COLOR_WHITE
        });

        var factories = new Array<PickerFactory or Text>[3];
        factories[0] = new TimeFactory(TimeFactory.T_HOUR);
        factories[1] = new WatchUi.Text({
            :text=>":",
            :font=>Graphics.FONT_MEDIUM,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER,
            :locY=>WatchUi.LAYOUT_VALIGN_CENTER,
            :color=>Graphics.COLOR_WHITE 
        });
        factories[2] = new TimeFactory(TimeFactory.T_MINUTE);

        var defaults = new Array<Number>[3];
        var value = settings.getValue(id);
        defaults[0] = (value / 60).toNumber();
        defaults[1] = 0;
        defaults[2] = value % 60;

        Picker.initialize({:title=>title, :pattern=>factories, :defaults=>defaults});
    }

    // This is needed to show the title (on both, the watch and the sim) and clear the background (sim)
    public function onLayout(dc as Dc) as Void {
        dc.clearClip();
        Picker.onLayout(dc);
    }
}

class TimeFactory extends WatchUi.PickerFactory {
    enum { T_HOUR, T_MINUTE }
    private var _stop as Number;
    private var _format as String;

    public function initialize(mode as Number) {
        PickerFactory.initialize();
        _stop = 0;
        _format = "%d";
        switch (mode) {
            case T_HOUR:
                _stop = 23;
                break;
            case T_MINUTE:
                _stop = 59;
                _format = "%02d";
                break;
        }
    }

    public function getDrawable(item as Number, isSelected as Boolean) as Drawable? {
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

class TimePickerDelegate extends WatchUi.PickerDelegate {
    private var _id as String;

    public function initialize(id as String) {
        PickerDelegate.initialize();
        _id = id;
    }

    public function onAccept(values as Array<Number?>) as Boolean {
        settings.setValue(_id, values[0] as Number * 60 + values[2] as Number);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    public function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
