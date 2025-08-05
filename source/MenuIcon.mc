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

// Drawable used for menu icons (accent color and dark mode contrast / dimmer level)
(:modern) class MenuIcon extends WatchUi.Drawable {
    enum Type { T_CIRCLE, T_TRIANGLE }
    private var _type as Type;
    private var _fgColor as Number;
    private var _bgColor as Number;

    // Constructor
    public function initialize(type as Type, fgColor as Number, bgColor as Number) {
        Drawable.initialize({});
        _type = type;
        _fgColor = fgColor;
        _bgColor = bgColor;
    }

    // Set the foreground color
    public function setColor(fgColor as Number) as Void {
        _fgColor = fgColor;
    }

    // Draw the icon
    public function draw(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var length = width < height ? width : height;
        var sx0 = (width - length)/2;
        var sy0 = (height - length)/2;
        dc.setColor(_bgColor, _bgColor);
        dc.setClip(sx0, sy0, length, length);
        dc.clear();
        dc.setColor(_fgColor, _fgColor);
        if (T_CIRCLE == _type) {
            dc.fillCircle(width/2, height/2, length/2.6);
        } else {
            dc.fillPolygon([[sx0, sy0], [sx0 + length, sy0 + length], [sx0 + length, sy0]]);
        }
    }
}
