/*
   Swiss Railway Clock - an analog watchface for Garmin watches

   Copyright (C) 2023 Andreas Huggel <ahuggel@gmx.net>

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
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Draw the steps, return true if it was drawn
function drawSteps(
    dc as Dc, 
    xpos as Number, 
    ypos as Number,
    colorMode as Number,
    textColor as Number
) as Boolean {
    var ret = false;
    var steps = null;
    var info = ActivityMonitor.getInfo();
    if (ActivityMonitor.Info has :steps) {
        steps = info.steps;
    }
    //steps = 123;
    //steps = 87654;
    //steps = 3456;
    if (steps != null and steps > 0) {
        var font = Graphics.FONT_TINY;
        var fontHeight = Graphics.getFontHeight(font);
        var width = (fontHeight * 2.1).toNumber(); // Indicator width
        var rt = steps.format("%d");
        dc.setColor(colorMode ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            steps > 999 ? steps > 9999 ? xpos - width*22/32 : xpos - width*19/32 : xpos - width*16/32,
            ypos - 1, 
            ClockView.iconFont as FontResource, 
            "F" as String, 
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            steps > 999 ? steps > 9999 ? xpos - width*9/32 : xpos - width*6/32 : xpos - width*3/32, 
            ypos, 
            font, 
            rt,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        ret = true;
    }
    return ret;
}
