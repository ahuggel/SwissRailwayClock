![image](WatchFace.png)

![image](configurable-clutter.gif)

# Swiss Railway Clock - An analog watchface for Garmin smartwatches

- This analog watchface is an implementation of the iconic [Swiss railway clock] design for Garmin smartwatches, with a [second hand] in both high- and low-power mode on watches with a MIP display;
- The operation differs from the original Swiss railway clock in that the second hand ticks like that of a quartz watch, rather than sweeps, and it does not pause at 12 o'clock. There is also a battery saving option to make the second hand disappear in low-power mode, after about 30s;
- On-device settings allow the configuration of battery level indicator (a classic battery shaped one or a modern one), date display, dark mode, 3D effects, a [Move Bar] and some other options. The "Configurable Clutter" clip above shows most of them. In addition, an accent color (the color of the second hand) can also be configured. The menu implements three different types of menu items as well as a basic time picker;
- On watches with an AMOLED display, the watchface has been adapted to the inherent peculiarities of this display type: The background is always black and dark mode just works as a dimmer. Always-on (low-power) mode uses the darkest dimmer setting and has no second hand. A few older AMOLED watches with more complex burn-in protection requirements are not supported;
- On some of the newest watches, it is possible to detect touch screen presses (touch and hold). This is used for a little gimmick to change the hour and minute hands and draw just their outlines for a few seconds after a screen press, so any indicator that is covered by the hands becomes readable (supported on the Forerunner 255, 955, fēnix 7 and 8 series, Enduro 2 and 3 and all AMOLED watches);
- Symbols for active alarms, phone connection and notifications, as well as the various indicators use icons from a [custom font];
- A global settings class synchronises the selected options to persistent storage and makes them available across the app;
- Newer ("Modern") watches with support for [layers] and sufficient memory or a graphics pool (since [Connect IQ 4.0]) use layers. Older ("Legacy") devices without layer support or insufficient memory work with a buffered bitmap. The code for watches with an [AMOLED] display draws directly on the device display, it doesn't need layers or a bitmap. [Jungle file build instructions] define for each device, which architecture it uses;
- The program has been upgraded to compile exclusively with SDK 7 (due to type changes in Monkey C, it is not backward compatible with older SDKs). It still compiles with a single warning with the compiler type checking level set to "Strict";
- Memory usage on legacy devices is now really close to the limit. I highly recommend using the [Prettier Monkey C] extension for Visual Studio Code to optimize the generated program as much as possible. From my experience, for legacy watches, the size of the code and data memory of the optimized program (as shown in the simulator's Active Memory window) is reduced by around 12%.

This program reflects the progress of my ongoing journey to learn [Monkey C] and the Garmin [Connect IQ ecosystem] to create an analog watchface. I am making it available in the hope that others will find it useful to grasp the necessary concepts more quickly than I did, and to perhaps get some feedback on what could be done better and how.

## Compatible devices

The Architecture column shows for each of the [compatible devices], if it supports the layer based implementation (Modern), uses a buffered bitmap (Legacy), or the simple code for AMOLED watches (Amoled).

| Device name | Label | Architecture |
| ----------- | ----- | ------------ |
| Approach® S70 42mm | approachs7042mm | Amoled |
| Approach® S70 47mm | approachs7047mm | Amoled |
| Captain Marvel | legacyherocaptainmarvel | Modern |
| D2™ Air X10 | d2airx10 | Amoled |
| D2™ Mach 1 | d2mach1 | Amoled |
| Darth Vader™ | legacysagadarthvader | Modern |
| Descent™ Mk2 / Descent™ Mk2i | descentmk2 | Legacy |
| Descent™ Mk2 S | descentmk2s | Legacy |
| Descent™ Mk3 43mm / Mk3i 43mm | descentmk343mm | Amoled |
| Descent™ Mk3i 51mm | descentmk351mm | Amoled |
| Enduro™ 3 | enduro3 | Modern |
| epix™ (Gen 2) / quatix® 7 Sapphire | epix2 | Amoled |
| epix™ Pro (Gen 2) 42mm | epix2pro42mm | Amoled |
| epix™ Pro (Gen 2) 47mm / quatix® 7 Pro | epix2pro47mm | Amoled |
| epix™ Pro (Gen 2) 51mm / D2™ Mach 1 Pro / tactix® 7 – AMOLED Edition | epix2pro51mm | Amoled |
| fēnix® 5 Plus | fenix5plus | Legacy |
| fēnix® 5S Plus | fenix5splus | Legacy |
| fēnix® 5X Plus | fenix5xplus | Legacy |
| fēnix® 6 / 6 Solar / 6 Dual Power | fenix6 | Legacy |
| fēnix® 6 Pro / 6 Sapphire / 6 Pro Solar / 6 Pro Dual Power / quatix® 6 | fenix6pro | Legacy |
| fēnix® 6S / 6S Solar / 6S Dual Power | fenix6s | Legacy |
| fēnix® 6S Pro / 6S Sapphire / 6S Pro Solar / 6S Pro Dual Power | fenix6spro | Legacy |
| fēnix® 6X Pro / 6X Sapphire / 6X Pro Solar / tactix® Delta Sapphire / Delta Solar / Delta Solar - Ballistics Edition / quatix® 6X / 6X Solar / 6X Dual Power | fenix6xpro | Legacy |
| fēnix® 7 / quatix® 7 | fenix7 | Modern |
| fēnix® 7 PRO | fenix7pro | Modern |
| fēnix® 7 Pro - Solar Edition (no Wi-Fi) | fenix7pronowifi | Modern |
| fēnix® 7S | fenix7s | Modern |
| fēnix® 7S PRO | fenix7spro | Modern |
| fēnix® 7X / tactix® 7 / quatix® 7X Solar / Enduro™ 2 | fenix7x | Modern |
| fēnix® 7X PRO | fenix7xpro | Modern |
| fēnix® 7X Pro - Solar Edition (no Wi-Fi) | fenix7xpronowifi | Modern |
| fēnix® 8 43mm | fenix843mm | Amoled |
| fēnix® 8 47mm / 51mm | fenix847mm | Amoled |
| fēnix® 8 Solar 47mm | fenix8solar47mm | Modern |
| fēnix® 8 Solar 51mm | fenix8solar51mm | Modern |
| fēnix® E | fenixe | Amoled |
| First Avenger | legacyherofirstavenger | Modern |
| Forerunner® 165 | fr165 | Amoled |
| Forerunner® 165 Music | fr165m | Amoled |
| Forerunner® 245 | fr245 | Legacy |
| Forerunner® 245 Music | fr245m | Legacy |
| Forerunner® 255 | fr255 | Modern |
| Forerunner® 255 Music | fr255m | Modern |
| Forerunner® 255s | fr255s | Modern |
| Forerunner® 255s Music | fr255sm | Modern |
| Forerunner® 265 | fr265 | Amoled |
| Forerunner® 265s | fr265s | Amoled |
| Forerunner® 645 Music | fr645m | Legacy |
| Forerunner® 745 | fr745 | Legacy |
| Forerunner® 945 | fr945 | Legacy |
| Forerunner® 945 LTE | fr945lte | Legacy |
| Forerunner® 955 / Solar | fr955 | Modern |
| Forerunner® 965 | fr965 | Amoled |
| Instinct® 3 AMOLED 45mm | instinct3amoled45mm | Amoled |
| Instinct® 3 AMOLED 50mm | instinct3amoled50mm | Amoled |
| MARQ® Adventurer | marqadventurer | Legacy |
| MARQ® Athlete | marqathlete | Legacy |
| MARQ® Aviator | marqaviator | Legacy |
| MARQ® Captain / MARQ® Captain: American Magic Edition | marqcaptain | Legacy |
| MARQ® Commander | marqcommander | Legacy |
| MARQ® Driver | marqdriver | Legacy |
| MARQ® Expedition | marqexpedition | Legacy |
| MARQ® (Gen 2) Athlete / Adventurer / Captain / Golfer / Carbon Edition / Commander - Carbon Edition | marq2 | Amoled |
| MARQ® (Gen 2) Aviator | marq2aviator | Amoled |
| MARQ® Golfer | marqgolfer | Legacy |
| Rey™ | legacysagarey | Modern |
| Venu® 2 Plus | venu2plus | Amoled |
| Venu® 2 | venu2 | Amoled |
| Venu® 2S | venu2s | Amoled |
| Venu® 3 | venu3 | Amoled |
| Venu® 3S | venu3s | Amoled |
| Venu® Sq 2 | venusq2 | Amoled |
| Venu® Sq 2 Music | venusq2m | Amoled |
| vívoactive® 3 Music | vivoactive3m | Legacy |
| vívoactive® 4 | vivoactive4 | Modern |
| vívoactive® 4S | vivoactive4s | Modern |
| vívoactive® 5 | vivoactive5 | Amoled |

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
