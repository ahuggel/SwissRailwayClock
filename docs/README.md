# Swiss Railway Clock - An analog watchface for Garmin watches

- An(other) implementation of the iconic Swiss Railway Clock design (with a second hand in both high and low-power mode, but without the pause at 12 o'clock)
- Simple code for an analog watchface, with a generous amount of code comments and hopefully easier to read and more straightforward than the samples I started with
- A working implementation of on-device settings with a menu to set date display and dark mode options, which also uses a basic time picker
- A global settings class that synchronises the selected options to persistent storage and makes them available across the app
- Compiles without warnings with the compiler type checking level set to "Strict"

This program is the result of my recent journey to learn basic Monkey C and the Garmin SDK to get this watchface on my 
new watch. I'm making it available for others to hopefully be able to learn the necessary concepts more quickly than I did, 
and to perhaps get some feedback on what could be done better and how.

## Credits

I've used several samples that come with the Garmin SDK, in particular: Analog, Menu2Sample and Picker.
I also looked at the code at https://github.com/markwmuller/SwissWatchFace/, which is for a similar watchface, and
I read lots of very helpful posts in the Garmin Developer forum.
Finally, the Swiss Railway Clock design was created by Hans Hilfiker in the 1940s and 1950s and it continues to be used at
every railway station in Switzerland until today. See https://www.eguide.ch/de/objekt/sbb-bahnhofsuhr/ (in German)

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
