![image](https://user-images.githubusercontent.com/972802/211146459-4acc8a60-0c2f-4bf3-acf8-0270906968ab.png)
![image](https://github.com/ahuggel/SwissRailwayClock/assets/972802/069e56b6-4141-470b-8264-2ad1c560f40b)

# Swiss Railway Clock - An analog watchface for Garmin smartwatches

- This analog watchface is an implementation of the iconic [Swiss railway clock] design for Garmin smartwatches, with a [second hand] in both high- and low-power mode;
- The operation differs from the original Swiss railway clock in that the second hand updates only every second and it does not pause at 12 o'clock. There is also an option to make the second hand disappear in low-power mode, after about 30s;
- On-device settings allow the configuration of battery level indicator (a classic battery shaped one or a modern one), date display, dark mode, 3D effects and some other options. The menu implements three different types of menu items as well as a basic time picker;
- Symbols for active alarms, phone connection and notifications, as well as the heart rate and recovery time indicators use icons from a [custom font];
- A global settings class synchronises the selected options to persistent storage and makes them available across the app;
- The program compiles with only a single warning with the compiler type checking level set to "Strict";
- Watches with support for [layers] and sufficient memory or a graphics pool (since [Connect IQ 4.0]) use layers. Older devices without layer support or insufficient memory use a buffered bitmap. ```minApiLevel``` is set to 3.2.0 as that's the minimum level required for on-device settings. Devices with [AMOLED] displays are not supported.

This program reflects the progress of my ongoing journey to learn [Monkey C] and the Garmin [Connect IQ ecosystem] to create an analog watchface. I am making it available for others to hopefully be able to learn the necessary concepts more quickly than I did, and to perhaps get some feedback on what could be done better and how.

## Credits

The [Swiss railway clock] design was created by Hans Hilfiker in the 1940s and 1950s, who was employed by the Swiss Federal Railways (SBB) at that time. It continues to be used at every railway station in Switzerland until today.

I've used several samples that come with the Garmin SDK, in particular: Analog, Menu2Sample and Picker, looked at the code of some other watchface apps that are available on Github, and read lots of very helpful posts in the [Garmin Developer forum].

Alarm, Bluetooth, Heart and SMS icons created by Google - [Flaticon]. License [CC 3.0 BY].

Hourglass icon by Afdalul Zikri. [Flaticon license].

[second hand]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-get-my-watch-face-to-update-every-second/
[custom font]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-use-custom-fonts/
[layers]: https://developer.garmin.com/connect-iq/core-topics/user-interface/
[Connect IQ 4.0]: https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/a-whole-new-world-of-graphics-with-connect-iq-4
[AMOLED]: https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/#howdoimakeawatchfaceforamoledproducts
[Monkey C]: https://developer.garmin.com/connect-iq/monkey-c/
[Connect IQ ecosystem]: https://developer.garmin.com/connect-iq/
[Garmin Developer forum]: https://forums.garmin.com/developer/connect-iq/f/discussion
[Swiss railway clock]: https://en.wikipedia.org/wiki/Swiss_railway_clock
[Flaticon]: https://www.flaticon.com/packs/material-design/
[CC 3.0 BY]: https://creativecommons.org/licenses/by/3.0/
[Flaticon license]: https://www.freepikcompany.com/legal?&_ga=2.78543444.1954543656.1683086561-616594141.1683086561&_gl=1*4sgkt0*test_ga*NjE2NTk0MTQxLjE2ODMwODY1NjE.*test_ga_523JXC6VL7*MTY4MzEyNDUwMi4yLjEuMTY4MzEyNDg0OS41NC4wLjA.*fp_ga*NjE2NTk0MTQxLjE2ODMwODY1NjE.*fp_ga_1ZY8468CQB*MTY4MzEyNDUzMi4yLjEuMTY4MzEyNDg0OS41NC4wLjA.#nav-flaticon
 
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
