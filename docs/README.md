![image](https://raw.githubusercontent.com/ahuggel/SwissRailwayClock/main/docs/WatchFace.png)
![image](https://raw.githubusercontent.com/ahuggel/SwissRailwayClock/main/docs/ConfigurableClutter.png)

# Swiss Railway Clock - An analog watchface for Garmin smartwatches

- This analog watchface is an implementation of the iconic [Swiss railway clock] design for Garmin smartwatches, with a [second hand] in both high- and low-power mode;
- The operation differs from the original Swiss railway clock in that the second hand updates only every second and it does not pause at 12 o'clock. There is also an option to make the second hand disappear in low-power mode, after about 30s;
- On-device settings allow the configuration of battery level indicator (a classic battery shaped one or a modern one), date display, dark mode, 3D effects, a [Move Bar] and some other options (see the picture with all the "configurable clutter" above). The menu implements three different types of menu items as well as a basic time picker;
- Symbols for active alarms, phone connection and notifications, as well as the heart rate and recovery time indicators use icons from a [custom font];
- On some of the newest watches, it is possible to detect touch screen presses (touch and hold). This is used for a little gimmick to change the hour and minute hands and draw just their outlines for a few seconds after a screen press, so any indicator that is covered by the hands becomes readable (supported on the Forerunner 255, 955 and fēnix 7 series and the Enduro 2);
- A global settings class synchronises the selected options to persistent storage and makes them available across the app;
- The program compiles with only a single warning with the compiler type checking level set to "Strict";
- Newer watches with support for [layers] and sufficient memory or a graphics pool (since [Connect IQ 4.0]) use layers. Older devices without layer support or insufficient memory use a buffered bitmap. The distinction is made using [Jungle file build instructions]. ```minApiLevel``` is set to 3.2.0 as that's the minimum level required for on-device settings. Devices with [AMOLED] displays are not supported.
- Memory usage on older devices is now really close to the limit. I highly recommend using the [Prettier Monkey C] extension for Visual Studio Code to optimize the generated program as much as possible. (From my experience, memory usage of the optimized program is reduced by 2-4%.)

This program reflects the progress of my ongoing journey to learn [Monkey C] and the Garmin [Connect IQ ecosystem] to create an analog watchface. I am making it available in the hope that others will find it useful to grasp the necessary concepts more quickly than I did, and to perhaps get some feedback on what could be done better and how.

## Compatible devices

The Architecture column shows for each of the [compatible devices], if it supports the layer based implementation (Modern) or uses a buffered bitmap (Legacy). 

| Device name | Architecture |
| ----------- | ------------ |
| Captain Marvel | Modern |
| Darth Vader™ | Modern |
| Descent™ Mk2 / Descent™ Mk2i | Legacy |
| Descent™ Mk2 S | Legacy       |
| fēnix® 5 Plus | Legacy |
| fēnix® 5S Plus | Legacy |
| fēnix® 5X Plus | Legacy |
| fēnix® 6 / 6 Solar / 6 Dual Power | Legacy |
| fēnix® 6 Pro / 6 Sapphire / 6 Pro Solar / 6 Pro Dual Power / quatix® 6 | Legacy |
| fēnix® 6S / 6S Solar / 6S Dual Power | Legacy |
| fēnix® 6S Pro / 6S Sapphire / 6S Pro Solar / 6S Pro Dual Power | Legacy |
| fēnix® 6X Pro / 6X Sapphire / 6X Pro Solar / tactix® Delta Sapphire / Delta Solar / Delta Solar - Ballistics Edition / quatix® 6X / 6X Solar / 6X Dual Power | Legacy |
| fēnix® 7 / quatix® 7 | Modern |
| fēnix® 7 PRO | Modern |
| fēnix® 7 Pro - Solar Edition (no Wi-Fi) | Modern |
| fēnix® 7S | Modern |
| fēnix® 7S PRO | Modern |
| fēnix® 7X / tactix® 7 / quatix® 7X Solar / Enduro™ 2 | Modern |
| fēnix® 7X PRO | Modern |
| fēnix® 7X Pro - Solar Edition (no Wi-Fi) | Modern |
| First Avenger | Modern |
| Forerunner® 245 | Legacy |
| Forerunner® 245 Music | Legacy |
| Forerunner® 255 | Modern |
| Forerunner® 255 Music | Modern |
| Forerunner® 255s | Modern |
| Forerunner® 255s Music | Modern |
| Forerunner® 645 Music | Legacy |
| Forerunner® 745 | Legacy |
| Forerunner® 945 | Legacy |
| Forerunner® 945 LTE | Legacy |
| Forerunner® 955 / Solar | Modern |
| MARQ® Adventurer | Legacy |
| MARQ® Athlete | Legacy |
| MARQ® Aviator | Legacy |
| MARQ® Captain / MARQ® Captain: American Magic Edition | Legacy |
| MARQ® Commander | Legacy |
| MARQ® Driver | Legacy |
| MARQ® Expedition | Legacy |
| MARQ® Golfer | Legacy |
| Rey™ | Modern |
| vívoactive® 3 Music | Legacy |
| vívoactive® 4 | Modern |
| vívoactive® 4S | Modern |

## Credits

The [Swiss railway clock] design was created by Hans Hilfiker, who was employed by the Swiss Federal Railways (SBB) at that time, in the 1940s and 1950s. It continues to be used at every railway station in Switzerland until today.

I've used several samples that come with the Garmin SDK, in particular: Analog, Menu2Sample and Picker, looked at the code of some other watchface apps that are available on Github, and read lots of very helpful posts in the [Garmin Developer forum].

Alarm, Bluetooth, Heart and SMS icons created by Google - [Flaticon]. License [CC 3.0 BY].

Footsteps icon by Freepik, [Flaticon license].

Recovery time icon by Urs Huggel.

[second hand]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-get-my-watch-face-to-update-every-second/
[custom font]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-use-custom-fonts/
[layers]: https://developer.garmin.com/connect-iq/core-topics/user-interface/
[Connect IQ 4.0]: https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/a-whole-new-world-of-graphics-with-connect-iq-4
[Jungle file build instructions]: https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/
[AMOLED]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/#howdoimakeawatchfaceforamoledproducts
[Monkey C]: https://developer.garmin.com/connect-iq/monkey-c/
[Connect IQ ecosystem]: https://developer.garmin.com/connect-iq/
[Garmin Developer forum]: https://forums.garmin.com/developer/connect-iq/f/discussion
[Swiss railway clock]: https://en.wikipedia.org/wiki/Swiss_railway_clock
[Flaticon]: https://www.flaticon.com/packs/material-design/
[CC 3.0 BY]: https://creativecommons.org/licenses/by/3.0/
[Flaticon license]: https://www.freepikcompany.com/legal?&_ga=2.78543444.1954543656.1683086561-616594141.1683086561&_gl=1*4sgkt0*test_ga*NjE2NTk0MTQxLjE2ODMwODY1NjE.*test_ga_523JXC6VL7*MTY4MzEyNDUwMi4yLjEuMTY4MzEyNDg0OS41NC4wLjA.*fp_ga*NjE2NTk0MTQxLjE2ODMwODY1NjE.*fp_ga_1ZY8468CQB*MTY4MzEyNDUzMi4yLjEuMTY4MzEyNDg0OS41NC4wLjA.#nav-flaticon
[Prettier Monkey C]: https://marketplace.visualstudio.com/items?itemName=markw65.prettier-extension-monkeyc
[Move Bar]: https://support.garmin.com/en-US/?faq=JwIMwaMTTV0t7r0mvkdA08
[compatible devices]: https://developer.garmin.com/connect-iq/compatible-devices/

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
