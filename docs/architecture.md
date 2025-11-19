## Design and architecture notes[^1]

One of the main challenges of this watchface program was that I wanted it to show the long and rather bulky second hand in both high- and low-power mode.

Garmin smartwatches with a MIP display can perform screen updates every second, even in low-power mode, which makes it possible to always show a [second hand], as opposed to only drawing it in high-power mode. This per-second update in low-power mode has very strict limits set on execution time though; only a tiny portion of the screen can be modified and only a minimal number of statements can be executed within these limits.

AMOLED watches on the other hand, do not have support for such per-second updates at all. It is not possible to update the screen more often than once a minute in always-on (low-power) mode and therefore, the second hand can only be shown in high-power mode on AMOLED watches.

The Swiss Railway Clock watchface implements three different architectures for three classes of devices and [Jungle file build instructions] define for each device, which architecture it uses:

1. Older ("Legacy") devices with a MIP display, which do not support [layers] or have insufficient memory, work with a [buffered bitmap] and indicators are only updated once a minute in low-power mode (when the entire screen is redrawn). This is the traditional model to implement a watchface with per-second screen updates.

2. Newer ("Modern") watches with a MIP display and support for [layers] and sufficient memory or a graphics pool (since [Connect IQ 4.0]) use layers. This results in more straightforward code and allows refreshing indicators, like the heart rate, more often than once a minute, even in low-power mode (on the background layer, without having to worry about the watch hands).

Either one of these two concepts, together with a "clipping area", is required in order to stay within Garmin's execution time limits when updating the second hand in low-power mode. The [clipping area] is set to the smallest rectangle around the second hand and is used to restrict the rendering window when "deleting" the second hand before redrawing it at its next position. On older devices, the buffered bitmap holds a copy of the watchface screen without the second hand, which is used to "delete" the second hand by copying the region defined by the clipping area to the device display. The new second hand is then drawn directly on the display. On newer devices, a separate layer is used just for the second hand. The clipping area of the second hand layer is cleared to delete it, before the new second hand is drawn on the layer.

3. The code for watches with an [AMOLED] display draws directly on the device display and just draws the entire watchface screen from scratch every second in high-power mode and once a minute in always-on (low-power) mode. This is the simplest of the three architectures. It doesn't have to deal with a second hand in always-on (low-power) mode and thus doesn't require layers or a buffered bitmap[^2].

The code for the different architectures is in the directories ```source/legacy```, ```source/modern``` and ```source/amoled```.
Besides the actual watchface, each also implements its own version of the global settings class and the on-device menu, as they provide slightly different options to cater for the capabilities of each class of devices.

In some of the common code, [exclude annotations] are used to distinguish between code for modern (incl. AMOLED) and legacy devices with more and less memory. Modern and AMOLED devices use a global instance of ```class Shapes```, which deals with the coordinates of the watchface shapes, i.e., the hands and tickmarks. Legacy watches don't use this class because of the memory overhead it adds.

Symbols for active alarms, phone connection and notifications, as well as the various indicators use icons from a [custom font];

The compiler [type checking] level is set to "Strict" and the program compiles with a single warning.

[^1]: These are kept high-level; for the full picture, read them together with the code and the comments in the code.
[^2]: Either of these concepts could be considered to try to be more energy efficient, even in high-power mode. It is difficult to tell how significant such potential performance improvements might be though, in comparison with the energy required to update the pixels and light the device display.

## Optimizations

Garmin smartwatches are constrained devices with limited processing power, memory, and energy resources. These resources are interlinked; optimizing for one often adversely affects the others. And while the [Monkey C] language and the [Toybox APIs] provide a modern programming environment, comparable to those used to code for more powerful computers, this can also give a misleading sense of ample resources and capabilities. Moreover, the Monkey C compiler's built-in optimizer isn't very effective (yet) and even some basic language features incur memory overheads and are best avoided. It is important to keep these constraints in mind when developing for a Garmin device.

To start, I highly recommend using [Prettier Monkey C], an extension for Visual Studio Code, which does a great job at optimizing the memory usage of the generated program. From my experience, for legacy watches, for which the memory usage is now really close to the limit, Prettier Monkey C allows me to keep the source code more maintainable (I can keep the ```enum```s for example) while reducing the size of the application code and data by around 12%.

### Performance optimizations

The first optimization needed for the Swiss Railway Clock watchface was not about memory though, but to reduce the execution time to stay within Garmin's execution time limits when updating the screen in low-power mode. The goal for this is to minimize the time it takes to run ```WatchFace.onPartialUpdate()```. This function is called every second when the device is in low-power mode. Its main task is to delete the [second hand] and redraw it at the next position, which requires calculating the new coordinates for the hand and for the smallest rectangle around it and calling the relevant Garmin graphics functions.

Optimizing these calculations involved
- relocating code to eliminate unnecessarily repeated computations;
- removing any not strictly required statements;
- inlining functions; and 
- unrolling loops.

After much experimenting and tweaking, the resulting code now meets the execution time limits, but is no longer easy to read and understand. If you're just looking for a basic example of code to rotate coordinates and set the clipping regions for a second hand, you may be better off checking out Garmin's sample analog watchface application first.

For devices with sufficient memory the optimization goes one step further and all required coordinates for every second are only calculated once, when the app is started. They are kept in an array and the time critical code then only needs to lookup the coordinates for the current second.

To measure the efficiency of performance optimizations, Garmin's simulator provides a "Watchface Diagnostics" tool that shows the time spent in ```onPartialUpdate()```[^3] and a Profiler to analyze the program's performance in more detail.

[^3]: This tool would be even more useful if it also showed the (running) *average* partial update execution time, i.e., the actual metric that is limited.

### Memory optimizations

As the number of supported optional indicators - the "Configurable Clutter" - grew, memory became a constraint on older devices. Optimizing memory usage involved
- removing some functionality from legacy devices;
- minimizing the number of classes, class variables and functions;
- replacing ```switch``` constructs with ```if``` statements;
- replacing more complex variable types with simpler ones (e.g., use array instead of dictionary); and
- introducing local variables to avoid repeating any, even minor, repeated expressions (e.g., instead of ```a=b+c+2; d=e+c+2;```, write ```var f=c+2; a=b+f; d=e+f;```).

More recently, the number of custom icons (being characters of a custom font) continued to increase only for modern and AMOLED watches. As each new icon requires memory and the new icons are not used on legacy watches, a way to load different font resources for different watches was needed. With additional resource-path definitions in the ```monkey.jungle``` file, legacy watches now use a legacy custom font with only a handful of icons, while the other two architectures get all the icons.

For additional strategies on saving memory, check the [Garmin Developer forum]. Also, keep in mind that the resulting optimized design and code to save a few bytes here and there often violates common software development best practices. The optimized design and code may not look right.

Memory optimizations can be measured with the simulator's "Active Memory" utility, which reports the size of the application code and data as well as other useful information.

## Adding a new Indicator

On AMOLED and Modern watches, four complications are available and each can display one of a list of supported indicators. New indicators can be added with minimal code changes. These are the steps to add a new indicator for AMOLED and Modern watches[^4]:

- Choose a new symbol name for the new indicator (like `:Temperature`).

In `resources/default/strings/strings.xml` and `resources/lang/*/strings/strings.xml`
- Add string resources for the new symbol.

In `resources/family/*/fonts/swissrailwayclock-icons-*`
- Create one or more icons for the new indicator and add them to the Icons font.

In `source/{amoled,modern}/Config.mc`
- Add the new symbol to the `Config._options` arrays for the four complications. (Complications 1 and 2 are for indicators with up to 5 digits, the other two only have space for up to 4 digits);
- Add a check to `Config._hasCapability` if the new indicator is not available on all supported devices.

In `source/common/Indicators.mc`
- Implement the logic to determine the value and icon for the new indicator in `Indicators.getDisplayValues()`.

Voilà.

The [code changes for the Temperature indicator](https://github.com/ahuggel/SwissRailwayClock/pull/28/commits/d8b95e3d34813d1398e353c2621e541437623807) are an example for a new indicator.

[^4]: Due to memory constraints, legacy watches have only four indicators, which are individually turned on or off (Heart rate, Recovery time, Steps, Calories). The quickest way to make changes to this would be to replace one of these existing indicators with a new one.

## Adding a new Application Setting

Application settings are managed by class ```Config```. A global instance of that class, ```config```, maintains the settings and related information. It synchronises the selected menu options to [persistent storage] and makes them available across the app. Throughout the app, settings are generally identified and referred to by an enum value (e.g., ```I_PRESSURE_UNIT```). The existing settings are grouped into toggle items (configurations that are either on or off), list items (where the user selects an option from a list) and settings with a time picker (to set the start and end time of dark or dimmer mode). The [on-device menu] implements three different types of Connect IQ menu items: ```ToggleMenuItem``` for toggle items, ```MenuItem``` for simple list items and ```IconMenuItem``` for list items with an icon, and uses a basic time [picker] for the user to configure dark/dimmer mode start and end times.

Introducing new toggle or list items and adding them to the settings menu is straightforward (although not overly object-oriented - see [Optimizations](#optimizations) above) and requires the following code changes:

In `source/*/Config.mc`
- Add an enum name for the new setting to `enum Item`;
- Add a symbol for the new setting, at the same position in the array, to `_itemSymbols`;
- Add a (two letter) label for the new setting, also at the same position in the array, to `_itemLabels`;
- For list items, add a list of options to the `_options` array. The first option in the list is the default value. Again, the position within the array is critical;
- Toggle items have a default value set in the local variable `defaults` in `Config.initialize()`.

In `resources/default/strings/strings.xml` and `resources/lang/*/strings/strings.xml`
- Add string resources for the new symbols (they become the setting and option labels in the menu).

In `source/*/Settings.mc`
- Add a menu item for the new setting to the menu in `SettingsView.buildMenu()`. Use `SettingsView.addToggleMenuItem()` for toggle items and `SettingsView.addMenuItem()` for simple list items (without an icon);
- Add a call to delete the item to `SettingsView.deleteMenu()`.

This introduces a new setting, which is synchronised to persistent storage, appears in the on-device menu, and can be accessed from anywhere in the app.

The [code changes for the Pressure Unit setting](https://github.com/ahuggel/SwissRailwayClock/commit/d0435107df276390f4d5a07e48e8e978a4f4b8d6) are an example for a basic list item.

[Jungle file build instructions]: https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/
[layers]: https://developer.garmin.com/connect-iq/core-topics/user-interface/
[buffered bitmap]: https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/BufferedBitmap.html
[Connect IQ 4.0]: https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/a-whole-new-world-of-graphics-with-connect-iq-4
[clipping area]: https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html#setClip-instance_function
[AMOLED]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/#howdoimakeawatchfaceforamoledproducts
[exclude annotations]: https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/#excludedannotations
[custom font]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-use-custom-fonts/
[type checking]: https://developer.garmin.com/connect-iq/monkey-c/monkey-types/
[Monkey C]: https://developer.garmin.com/connect-iq/monkey-c/
[Toybox APIs]: https://developer.garmin.com/connect-iq/api-docs/
[Prettier Monkey C]: https://marketplace.visualstudio.com/items?itemName=markw65.prettier-extension-monkeyc
[second hand]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-get-my-watch-face-to-update-every-second/
[Garmin Developer forum]: https://forums.garmin.com/developer/connect-iq/f/discussion
[persistent storage]: https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html
[on-device menu]: https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Menu2.html
[picker]: https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Picker.html
