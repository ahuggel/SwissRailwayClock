![image](https://user-images.githubusercontent.com/972802/211146459-4acc8a60-0c2f-4bf3-acf8-0270906968ab.png)

# Swiss Railway Clock - An analog watchface for Garmin smartwatches

- This analog watchface is an implementation of the iconic [Swiss railway clock] design for Garmin smartwatches, with a second hand in both high and low-power mode;
- The operation differs from the original Swiss railway clock in that the second hand updates only every second and it does not pause at 12 o'clock. There is also an option to make the second hand disappear in low-power mode, after about 30s;
- On-device settings allow the configuration of battery level indicator, date display, dark mode and some other options. The menu implements three different types of menu items as well as a basic time picker;
- Symbols for active alarms, phone connection and notifications done with very few lines of code and a custom icon font;
- A global settings class synchronises the selected options to persistent storage and makes them available across the app;
- The program compiles without warnings with the compiler type checking level set to "Strict";
- All modern Garmin watches should be able to run this watchface (```minApiLevel``` is set to 3.2.0, mostly to keep the code simple). It fails miserably in the always-on mode of watches with an AMOLED display though.

This program is the result of my recent journey to learn basic Monkey C and the Garmin Connect IQ ecosystem. I tried to keep the source code simple and straightforward, with a generous amount of comments, and implement an easy to understand yet robust logic. I am making it available for others to hopefully be able to learn the necessary concepts more quickly than I did, and to perhaps get some feedback on what could be done better and how.

## Credits

I've used several samples that come with the Garmin SDK, in particular: Analog, Menu2Sample and Picker.
I also looked at the code at https://github.com/markwmuller/SwissWatchFace/, which is for a similar watchface, and
read lots of very helpful posts in the Garmin Developer forum.

The [Swiss railway clock] design was created by Hans Hilfiker in the 1940s and 1950s and it continues to be used at
every railway station in Switzerland until today.

Alarm, Bluetooth, Heart and SMS icons created by Google - [Flaticon]. License [CC 3.0 BY].

[Swiss railway clock]: https://en.wikipedia.org/wiki/Swiss_railway_clock
[Flaticon]: https://www.flaticon.com/packs/material-design/
[CC 3.0 BY]: https://creativecommons.org/licenses/by/3.0/

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
