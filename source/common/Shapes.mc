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
import Toybox.System;

// Global variable with the shapes and coordinates for the watchface.
(:modern) var shapes as Shapes = new Shapes();

// Shapes and coordinates used for the watchface design.
(:modern) class Shapes {
    // The watchface shapes
    // Review optimizations in calcSecondData() et al. before changing the Shape enum.
    public enum Shape { 
        S_BIGTICKMARK, 
        S_SMALLTICKMARK, 
        S_HOURHAND, 
        S_MINUTEHAND, 
        S_SECONDHAND, 
        S_GAUGEHAND, 
        S_SIZE 
    }
    // Radius of the second hand circle
    public var secondCircleRadius as Number = 0; 
    // Cache for all numbers required to draw the second hand. These are pre-calculated in onLayout().
    public var secondData as Array< Array<Number> > = new Array< Array<Number> >[60];
    // Two obscure values needed in the Indicators class to position the Bluetooth symbol on the 6 o'clock tickmark 
    public var s0 as Float;
    public var s3 as Float;

    // A 1 dimensional array for the coordinates, size: S_SIZE (shapes) * 4 (points) * 2 (coordinates) - that's supposed to be more efficient
    private var _coords as Array<Number> = new Array<Number>[S_SIZE * 8];

    // Constructor
    public function initialize() {
        var deviceSettings = System.getDeviceSettings();
        var width = deviceSettings.screenWidth;
        var height = deviceSettings.screenHeight;
        var screenCenter = [width/2, height/2] as Array<Number>;
        var clockRadius = screenCenter[0] < screenCenter[1] ? screenCenter[0] : screenCenter[1];

        // A 2 dimensional array for the geometry of the watchface shapes - because the initialisation is more intuitive that way
        var shapes = new Array< Array<Float> >[S_SIZE];

        // Geometry of the hands and tick marks of the clock, as percentages of the diameter of the
        // clock face. Each of these shapes is a polygon (trapezoid), defined by
        // - its height (length),
        // - the width at the tail of the hand or tick mark,
        // - the width at the tip of the hand or tick mark,
        // - the distance from the center of the clock to the tail side (negative for a watch hand 
        //   with a tail).
        // In addition, the second hand has a circle, which is defined separately.
        // See docs/1508_CHD151_foto_b.jpg for the original design. The numbers used here deviate from 
        // that only slightly.
        //                          height, width1, width2, radius
        shapes[S_BIGTICKMARK]   = [  12.0,    3.5,    3.5,   36.5];	
        shapes[S_SMALLTICKMARK] = [   3.5,    1.4,    1.4,   45.0];
        shapes[S_HOURHAND]      = [  44.0,    6.3,    5.1,  -12.0];
        shapes[S_MINUTEHAND]    = [  57.8,    5.2,    3.7,  -12.0];
        shapes[S_SECONDHAND]    = [  47.9,    1.4,    1.4,  -16.5];
        shapes[S_GAUGEHAND]     = [   8.5,    2.5,    0.75,  -3.5];

        // Convert the clock geometry data to pixels
        for (var s = 0; s < S_SIZE; s++) {
            for (var i = 0; i < 4; i++) {
                shapes[s][i] = Math.round(shapes[s][i] * clockRadius / 50.0) as Float;
            }
        }

        s0 = shapes[S_BIGTICKMARK][0];
        s3 = shapes[S_BIGTICKMARK][3];

        // Map out the coordinates of all the shapes. Doing that only once reduces processing time.
        for (var s = 0; s < S_SIZE; s++) {
            var idx = s * 8;
            _coords[idx]   = -(shapes[s][1] / 2 + 0.5).toNumber();
            _coords[idx+1] = -(shapes[s][3] + 0.5).toNumber();
            _coords[idx+2] = -(shapes[s][2] / 2 + 0.5).toNumber();
            _coords[idx+3] = -(shapes[s][3] + shapes[s][0] + 0.5).toNumber();
            _coords[idx+4] =  (shapes[s][2] / 2 + 0.5).toNumber();
            _coords[idx+5] = -(shapes[s][3] + shapes[s][0] + 0.5).toNumber();
            _coords[idx+6] =  (shapes[s][1] / 2 + 0.5).toNumber();
            _coords[idx+7] = -(shapes[s][3] + 0.5).toNumber();
        }
        //System.println("("+_coords[S_SECONDHAND*8+2]+","+_coords[S_SECONDHAND*8+3]+") ("+_coords[S_SECONDHAND*8+4]+","+_coords[S_SECONDHAND*8+5]+")");
        if (clockRadius >= 130 and 0 == (_coords[S_SECONDHAND*8+4] - _coords[S_SECONDHAND*8+2]) % 2) {
            // TODO: Check if we always get here because of the way the numbers are calculated
            _coords[S_SECONDHAND*8+6] += 1;
            _coords[S_SECONDHAND*8+4] += 1;
            //System.println("INFO: Increased the width of the second hand by 1 pixel to "+(_coords[S_SECONDHAND*8+4]-_coords[S_SECONDHAND*8+2]+1)+" pixels to make it even");
        }

        // The radius of the second hand circle in pixels, calculated from the percentage of the clock face diameter
        secondCircleRadius = ((5.1 * clockRadius / 50.0) + 0.5).toNumber();
        var secondCircleY = _coords[S_SECONDHAND * 8 + 3];
        // Shorten the second hand from the circle center to the edge of the circle to avoid a dark shadow
        _coords[S_SECONDHAND * 8 + 3] += secondCircleRadius - 1;
        _coords[S_SECONDHAND * 8 + 5] += secondCircleRadius - 1;

        // Calculate all numbers required to draw the second hand for every second
        var offsetX = screenCenter[0] + 0.5;
        var offsetY = screenCenter[1] + 0.5;
        for (var second = 0; second < 60; second++) {
            // Interestingly, lookup tables for the angle or sin/cos don't make this any faster.
            var angle = second * 0.104719755; /* 2*pi/60 */
            var sin = Math.sin(angle);
            var cos = Math.cos(angle);

            // Rotate the rectangular portion of the second hand, using inlined code from rotateCoords() to improve performance
            // Optimized: idx = S_SECONDHAND * 8; idy = idx + 1; and etc.
            var x0 = (_coords[32] * cos - _coords[33] * sin + offsetX).toNumber();
            var y0 = (_coords[32] * sin + _coords[33] * cos + offsetY).toNumber();
            var x1 = (_coords[34] * cos - _coords[35] * sin + offsetX).toNumber();
            var y1 = (_coords[34] * sin + _coords[35] * cos + offsetY).toNumber();
            var x2 = (_coords[36] * cos - _coords[37] * sin + offsetX).toNumber();
            var y2 = (_coords[36] * sin + _coords[37] * cos + offsetY).toNumber();
            var x3 = (_coords[38] * cos - _coords[39] * sin + offsetX).toNumber();
            var y3 = (_coords[38] * sin + _coords[39] * cos + offsetY).toNumber();

            // Rotate the center of the second hand circle
            var x = (-secondCircleY * sin + offsetX).toNumber();
            var y = (secondCircleY * cos + offsetY).toNumber();

            // Set the clipping region
            var xx1 = x - secondCircleRadius;
            var yy1 = y - secondCircleRadius;
            var xx2 = x + secondCircleRadius;
            var yy2 = y + secondCircleRadius;
            // coords[1], coords[2] optimized out: only consider the tail and circle coords, loop unrolled for performance,
            // use only points [x0, y0], [x3, y3], [xx1, yy1], [xx2, yy1], [xx2, yy2], [xx1, yy2], minus duplicate comparisons
            var minX = x0;
            var minY = y0;
            var maxX = x0;
            var maxY = y0;
            if (x3 < minX) { minX = x3; }
            if (y3 < minY) { minY = y3; }
            if (x3 > maxX) { maxX = x3; }
            if (y3 > maxY) { maxY = y3; }
            if (xx1 < minX) { minX = xx1; }
            if (yy1 < minY) { minY = yy1; }
            if (xx1 > maxX) { maxX = xx1; }
            if (yy1 > maxY) { maxY = yy1; }
            if (xx2 < minX) { minX = xx2; }
            if (yy2 < minY) { minY = yy2; }
            if (xx2 > maxX) { maxX = xx2; }
            if (yy2 > maxY) { maxY = yy2; }

            // Save the calculated numbers, add two pixels on each side of the clipping region for good measure
            //             Index: 0  1   2   3   4   5   6   7   8   9        10        11               12               13
            secondData[second] = [x, y, x0, y0, x1, y1, x2, y2, x3, y3, minX - 2, minY - 2, maxX - minX + 4, maxY - minY + 4];
        }

        //var s = secondData[0];
        //System.println("INFO: Clock radius = "+clockRadius);
        //System.println("INFO: Secondhand circle: ("+s[0]+","+s[1]+"), r = "+secondCircleRadius);
        //System.println("INFO: Secondhand coords: ("+s[2]+","+s[3]+") ("+s[4]+","+s[5]+") ("+s[6]+","+s[7]+") ("+s[8]+","+s[9]+")");
    }

    // Rotate the four corner coordinates of a polygon used to draw a watch hand or a tick mark.
    // 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    // Param shape: Index of the shape
    // Param angle: Rotation angle in radians
    // Param xpos, ypos: Position of the shape on the screen
    // Returns the rotated coordinates of the polygon (watch hand or tick mark)
    public function rotate(shape as Shape, angle as Float, xpos as Number, ypos as Number) as Array<Point2D> {
        var sin = Math.sin(angle);
        var cos = Math.cos(angle);
        // Optimized: Expanded the loop and avoid repeating the same operations (Thanks Inigo Tolosa for the tip!)
        var offsetX = xpos + 0.5;
		var offsetY = ypos + 0.5;
        var coords = new Array<Point2D>[4];
        var idx = shape * 8;
        var idy = idx + 1;
        coords[0] = [(_coords[idx] * cos - _coords[idy] * sin + offsetX).toNumber(),
                     (_coords[idx] * sin + _coords[idy] * cos + offsetY).toNumber()];
        idx += 2;
        idy += 2;
        coords[1] = [(_coords[idx] * cos - _coords[idy] * sin + offsetX).toNumber(),
                     (_coords[idx] * sin + _coords[idy] * cos + offsetY).toNumber()];
        idx += 2;
        idy += 2;
        coords[2] = [(_coords[idx] * cos - _coords[idy] * sin + offsetX).toNumber(),
                     (_coords[idx] * sin + _coords[idy] * cos + offsetY).toNumber()];
        idx += 2;
        idy += 2;
        coords[3] = [(_coords[idx] * cos - _coords[idy] * sin + offsetX).toNumber(),
                     (_coords[idx] * sin + _coords[idy] * cos + offsetY).toNumber()];

        return coords;
    }

    // Draw the edges of a polygon
    public function drawPolygon(dc as Dc, pts as Array<Point2D>) as Void {
        var size = pts.size();
        for (var i = 0; i < size; i++) {
            var startPoint = pts[i];
            var endPoint = pts[(i + 1) % size];
            dc.drawLine(startPoint[0], startPoint[1], endPoint[0], endPoint[1]);
        }
    }
}
