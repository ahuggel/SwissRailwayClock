![image](WatchFace.png)

![image](configurable-clutter.gif)

<img src="venu4.png" alt="Venu 4" align="left" width="34%">

_More "Configurable Clutter"_

A newer AMOLED watch (Venu® 4 41mm, picture from the simulator) showing some of the newer indicators for stress, pressure, altitude and temperature, and a purple second hand.

The altitude and temperature values are in the units set in the system (°C or °F and m or ft) and for the pressure unit there is a setting in the watch menu (since there isn't a system setting for this).
<br clear="left" />

# Swiss Railway Clock - An analog watchface for Garmin smartwatches

- This analog watchface is an implementation of the iconic [Swiss railway clock] design for Garmin smartwatches, with an always-on second hand on watches with a MIP display;
- The operation differs from the original Swiss railway clock in that the second hand ticks like that of a quartz watch, rather than sweeps, and it does not pause at 12 o'clock;
- On-device settings (a settings menu on the watch itself) allow the configuration of a battery level indicator (a classic battery shaped one or a modern one), date display, dark mode, 3D effects, a "Move Bar" and various other options. The "Configurable Clutter" clip above shows some of them, section [Settings](#settings) has the complete list and sections [Adding a new Indicator](#adding-a-new-indicator) and [Adding a new Application Setting](#adding-a-new-application-setting) explain how you can add your own;
- On watches with an AMOLED display, the background is always black and there are two independent brightness settings, replacing the contrast and dark mode options of MIP watches. Always-on (low-power) mode uses the darkest dimmer level[^1]. It is not possible to show the second hand in always-on (low-power) mode of AMOLED watches;
- On recent watches with a touch screen, it is possible to detect touch screen presses (touch and hold). This is used for a little gimmick to change the hour and minute hands and draw just their outlines for a few seconds after a screen press, so any indicator that is covered by the hands becomes readable (supported from the Forerunner 255, 955, fēnix 7 and 8 series, Enduro 2 and 3 and all AMOLED watches).

This program reflects the progress of my ongoing journey to master [Monkey C] and the Garmin [Connect IQ ecosystem] to create an analog watchface. What started as a simple program has grown into a complete application over time, with numerous features and support for all newer Garmin watch models. I am sharing it with developers to showcase what I've learned, in the hope that it will help others grasp the relevant programming concepts more quickly than I did, and to perhaps get some feedback on what could be done better and how. This is an educational and non-commercial project and is not intended to compete with any licensed application of the original Swiss railway clock design, which belongs to the Swiss Federal Railways (SBB). As such, it is not published in the Garmin Connect IQ store.

[^1]: Newer AMOLED watches have burn-in protection requirements, which are easily and quite naturally addressed with the concept of a brightness setting. A few older AMOLED watches with more complex burn-in protection requirements are not supported.

## Credits

The [Swiss railway clock] design was created by Hans Hilfiker, who was employed by the Swiss Federal Railways (SBB) at that time, in the 1940s and 1950s. It continues to be used at every railway station in Switzerland until today.

I've used several samples that come with the Garmin SDK, in particular: Analog, Menu2Sample and Picker, looked at the code of some other watchface apps that are available on Github, and read lots of very helpful posts in the [Garmin Developer forum].

Alarm, Bluetooth, Heart and SMS icons created by Google - [Flaticon]. License [CC 3.0 BY].

Footsteps icon by Freepik, [Flaticon license].

Recovery time icon by Urs Huggel.

## License

Copyright (C) Andreas Huggel <ahuggel@gmx.net>

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

[second hand]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-get-my-watch-face-to-update-every-second/
[custom font]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-use-custom-fonts/
[buffered bitmap]: https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/BufferedBitmap.html
[layers]: https://developer.garmin.com/connect-iq/core-topics/user-interface/
[Connect IQ 4.0]: https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/a-whole-new-world-of-graphics-with-connect-iq-4
[Jungle file build instructions]: https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/
[AMOLED]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/#howdoimakeawatchfaceforamoledproducts
[Monkey C]: https://developer.garmin.com/connect-iq/monkey-c/
[Toybox APIs]: https://developer.garmin.com/connect-iq/api-docs/
[Connect IQ ecosystem]: https://developer.garmin.com/connect-iq/
[Garmin Developer forum]: https://forums.garmin.com/developer/connect-iq/f/discussion
[Swiss railway clock]: https://en.wikipedia.org/wiki/Swiss_railway_clock
[Flaticon]: https://www.flaticon.com/packs/material-design/
[CC 3.0 BY]: https://creativecommons.org/licenses/by/3.0/
[Flaticon license]: https://www.freepikcompany.com/legal?&_ga=2.78543444.1954543656.1683086561-616594141.1683086561&_gl=1*4sgkt0*test_ga*NjE2NTk0MTQxLjE2ODMwODY1NjE.*test_ga_523JXC6VL7*MTY4MzEyNDUwMi4yLjEuMTY4MzEyNDg0OS41NC4wLjA.*fp_ga*NjE2NTk0MTQxLjE2ODMwODY1NjE.*fp_ga_1ZY8468CQB*MTY4MzEyNDUzMi4yLjEuMTY4MzEyNDg0OS41NC4wLjA.#nav-flaticon
[Prettier Monkey C]: https://marketplace.visualstudio.com/items?itemName=markw65.prettier-extension-monkeyc
[compatible devices]: https://developer.garmin.com/connect-iq/compatible-devices/
[on-device menu]: https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Menu2.html
[picker]: https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Picker.html
[clipping area]: https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html#setClip-instance_function
[exclude annotations]: https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/#excludedannotations
[persistent storage]: https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html
[type checking]: https://developer.garmin.com/connect-iq/monkey-c/monkey-types/
