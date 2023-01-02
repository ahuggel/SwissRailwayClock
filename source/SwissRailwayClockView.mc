//
// Swiss Railway Clock
// https://www.eguide.ch/de/objekt/sbb-bahnhofsuhr/
//
// Copyright 2022 by Andreas Huggel
// 
// This started from the Garmin Analog sample program; there may be some terminology from that left.
// That sample program is Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables Application Developer Agreement.
//
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Implements the Swiss Railway Clock watch face
class SwissRailwayClockView extends WatchUi.WatchFace {
    enum { M_LIGHT, M_DARK } // Color modes
    enum { C_FOREGROUND, C_BACKGROUND, C_SECONDS, C_TEXT } // Indexes into the color arrays
    private var _colors as Array< Array<Number> > = [
        [Graphics.COLOR_BLACK, Graphics.COLOR_WHITE, Graphics.COLOR_RED, Graphics.COLOR_DK_GRAY],
        [Graphics.COLOR_WHITE, Graphics.COLOR_BLACK, Graphics.COLOR_ORANGE, Graphics.COLOR_LT_GRAY]
    ] as Array< Array<Number> >;

    // Geometry of the clock, as a percentage of the diameter of the clock face.
    //                                            height, width1, width2, radius, circle
    private var _bigTickMark   as Array<Float> = [  12.0,    3.5,    3.5,   36.5]        as Array<Float>;	
    private var _smallTickMark as Array<Float> = [   3.5,    1.4,    1.4,   45.0]        as Array<Float>;
    private var _hourHand      as Array<Float> = [  44.0,    6.3,    5.1,  -12.0]        as Array<Float>;
    private var _minuteHand    as Array<Float> = [  57.8,    5.2,    3.7,  -12.0]        as Array<Float>;
    private var _secondHand    as Array<Float> = [  47.9,    1.4,    1.4,  -16.5,   5.1] as Array<Float>;
// TODO: shorter second hand, if the original one doesn't work in low-power mode -   private var _secondHand    as Array<Float> = [  44.9,    1.4,    1.4,  -13.5,   5.1] as Array<Float>;

    private var _isAwake as Boolean;
    private var _doPartialUpdates as Boolean;
    private var _offscreenBuffer as BufferedBitmap;
    private var _screenShape as Number;
    private var _screenCenterPoint as Array<Number> = [0, 0] as Array<Number>;
    private var _clockRadius as Number = 0;
    private var _colorMode as Number = M_LIGHT;
    private var _sin as Array<Float> = new Array<Float>[60]; // Sinus/Cosinus lookup table for each second

    private var _image = null; // TODO as what??
    private var _loadedImage as Number = settings.S_IMAGE_NONE; // Remember which image has been loaded
    private var _imgCoords as Array<Number> = [0, 0] as Array<Number>;

    //! Constructor. Initialize the variables for this view.
    public function initialize() {
        WatchFace.initialize();

        _isAwake = true; // Assume we start awake and depend on onEnterSleep() to fall asleep
        _doPartialUpdates = true; // WatchUi.WatchFace has :onPartialUpdate since API Level 2.3.0
        _screenShape = System.getDeviceSettings().screenShape;

        // Allocate the buffer we use for drawing the watchface, hour and minute hands in low-power mode, 
        // using BufferedBitmap (API Level 2.3.0).
        // This is a full-colored buffer (with no palette), as we have enough memory and it makes drawing 
        // text with anti-aliased fonts much more straightforward.
        // Doing this in initialize() rather than onLayout() so _offscreenBuffer does not need to be 
        // nullable, which makes the type checker complain less.
        var bbmo = {
            :width=>System.getDeviceSettings().screenWidth,
	        :height=>System.getDeviceSettings().screenHeight
        };
        // CIQ 4 devices *need* to use createBufferBitmaps() 
  	    if (Graphics has :createBufferedBitmap) {
    		var bbRef = Graphics.createBufferedBitmap(bbmo);
			_offscreenBuffer = bbRef.get() as BufferedBitmap;
    	} else {
    		_offscreenBuffer = new Graphics.BufferedBitmap(bbmo);
		}
        if (Toybox.Graphics.Dc has :setAntiAlias) {
            var offscreenDc = _offscreenBuffer.getDc();
            offscreenDc.setAntiAlias(true);
        }

        // Initialize the sinus lookup table 
        for (var i = 0; i < 60; i++) {
            _sin[i] = Math.sin(i / 60.0 * 2 * Math.PI);
        }
    }

    //! Load resources and configure the layout of the watchface for this device
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        _screenCenterPoint = [width / 2, height / 2] as Array<Number>;
        _clockRadius = _screenCenterPoint[0] < _screenCenterPoint[1] ? _screenCenterPoint[0] : _screenCenterPoint[1];
        // Convert the clock geometry data to pixels
        for (var i = 0; i < 4; i++) {
            _bigTickMark[i]   = Math.round(_bigTickMark[i] * _clockRadius / 50.0);
            _smallTickMark[i] = Math.round(_smallTickMark[i] * _clockRadius / 50.0);
            _hourHand[i]      = Math.round(_hourHand[i] * _clockRadius / 50.0);
            _minuteHand[i]    = Math.round(_minuteHand[i] * _clockRadius / 50.0);
            _secondHand[i]    = Math.round(_secondHand[i] * _clockRadius / 50.0);
        }
        _secondHand[4] = Math.round(_secondHand[4] as Float * _clockRadius / 50.0);
        if (Toybox.Graphics.Dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
    }

    //! Called when this View is brought to the foreground. Restore the state of this view and
    //! prepare it to be shown. This includes loading resources into memory.
    public function onShow() as Void {
        // Load the selected background image if required
        var selectedImage = settings.getValue("image");
        if (selectedImage != _loadedImage) {
            _loadedImage = selectedImage;
            _image = null; // This seems to help purging any already loaded image
            _imgCoords = [0, 0] as Array<Number>;
            switch (selectedImage) {
                case settings.S_IMAGE_LEAVES:
                    _image = WatchUi.loadResource(Rez.Drawables.Leaves);
                    _imgCoords = [50, 60] as Array<Number>;
                    break;
                case settings.S_IMAGE_CANDLE:
                    _image = WatchUi.loadResource(Rez.Drawables.Candle);
                    _imgCoords = [50, 30] as Array<Number>;
                    break;
                case settings.S_IMAGE_HAT:
                    _image = WatchUi.loadResource(Rez.Drawables.Hat);
                    _imgCoords = [55, 35] as Array<Number>;
                    break;
                case settings.S_IMAGE_NONE:
                    break;
            }
        }
    }

    //! Handle the update event. This function is called
    //! 1) every second when the device is awake,
    //! 2) every full minute in low-power mode, and
    //! 3) it's also triggered when the device goes into low-power mode (from onEnterSleep()).
    //!
    //! Dependent on the power state of the device, we need to be more or less careful regarding
    //! the cost of (mainly) the drawing operations used. If available, anti-aliasing is used 
    //! for both, the main display and the off-screen buffer. The processing logic is as follows.
    //!
    //! When awake: 
    //! onUpdate(): Draw the entire screen every second, directly on the main display.
    //!
    //! In low-power mode:
    //! onUpdate(): Draw the screen into the off-screen buffer and then output the buffer
    //!             to the main display. If partial updates are enabled, also draw the second 
    //!             hand, directly on the main display.
    //! onPartialUpdate(): Use (part of) the off-screen buffer to blank out the second hand and 
    //!             re-draw the second hand at the new position, directly on the main display.
    //!
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        dc.clearClip();
        var targetDc = dc;
        if (!_isAwake) {
            // Only use the buffer in low-power mode
            targetDc = _offscreenBuffer.getDc();
        }
        var width = targetDc.getWidth();
        var height = targetDc.getHeight();
        var clockTime = System.getClockTime();

        // Set the color mode
        switch (settings.getValue("darkMode")) {
            case settings.S_DARK_MODE_AUTO:
                _colorMode = M_LIGHT;
                var time = clockTime.hour * 60 + clockTime.min;
                if (time >= settings.getValue("dmOn") or time < settings.getValue("dmOff")) {
                    _colorMode = M_DARK;
                }
                break;
            case settings.S_DARK_MODE_OFF:
                _colorMode = M_LIGHT;
                break;
            case settings.S_DARK_MODE_ON:
                _colorMode = M_DARK;
                break;
        }

        // Fill the background
        if (System.SCREEN_SHAPE_ROUND == _screenShape) {
            // Fill the entire background with the background color (white)
            targetDc.setColor(_colors[_colorMode][C_BACKGROUND], _colors[_colorMode][C_BACKGROUND]);
            targetDc.fillRectangle(0, 0, width, height);
        } else {
            // Fill the entire background with black and draw a circle with the background color (white)
            targetDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            targetDc.fillRectangle(0, 0, width, height);
            targetDc.setColor(_colors[_colorMode][C_BACKGROUND], _colors[_colorMode][C_BACKGROUND]);
            targetDc.fillCircle(_screenCenterPoint[0], _screenCenterPoint[1], _clockRadius);
        }

        // Show the background image
        if (_loadedImage != settings.S_IMAGE_NONE) {
            targetDc.drawBitmap(_imgCoords[0], _imgCoords[1], _image);
        }

        // Draw the date string
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        targetDc.setColor(_colors[_colorMode][C_TEXT], Graphics.COLOR_TRANSPARENT);
        switch (settings.getValue("dateDisplay")) {
            case settings.S_DATE_DISPLAY_OFF:
                break;
            case settings.S_DATE_DISPLAY_DAY_ONLY: 
                var dateStr = Lang.format("$1$", [info.day.format("%02d")]);
                targetDc.drawText(width*0.75, height/2 - Graphics.getFontHeight(Graphics.FONT_MEDIUM)/2, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
                break;
            case settings.S_DATE_DISPLAY_WEEKDAY_AND_DAY:
                dateStr = Lang.format("$1$ $2$", [info.day_of_week, info.day]);
                targetDc.drawText(width/2, height*0.65, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
                break;
        }

        // Draw tick marks around the edges of the screen
        targetDc.setColor(_colors[_colorMode][C_FOREGROUND], Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i++) {
            targetDc.fillPolygon(generatePolygonCoords(i % 5 ? _smallTickMark : _bigTickMark, i));
        }

        // Draw the hour hand
        var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min) / (12 * 60.0) * 2 * Math.PI;
        targetDc.fillPolygon(generatePolygonCoords(_hourHand, hourHandAngle));

        // Draw the minute hand
        targetDc.fillPolygon(generatePolygonCoords(_minuteHand, clockTime.min));

        if (!_isAwake) {
            // Output the offscreen buffer to the main display
            dc.drawBitmap(0, 0, _offscreenBuffer);
        }

        if (_isAwake or _doPartialUpdates) {
            drawSecondHand(dc, clockTime.sec);
        }
    }

    //! Handle the partial update event. This function is called every second when the device is
    //! in low-power mode. See onUpdate() for the full story.
    //! @param dc Device context
    public function onPartialUpdate(dc as Dc) as Void {
        // Output the offscreen buffer to the main display and draw the second hand.
        // Note that this will only affect the clipped region, to delete the second hand.
        dc.drawBitmap(0, 0, _offscreenBuffer);
        var clockTime = System.getClockTime();
        drawSecondHand(dc, clockTime.sec);
    }

    //! Set the clipping region and draw the second hand
    //! @param dc Device context
    //! @param second The current second 
    private function drawSecondHand(dc as Dc, second as Number) as Void {
        // Compute the center of the second hand circle, at the tip of the second hand
        var sin = _sin[second];
        var cos = _sin[(second + 15) % 60];
        var secondCircleCenter = [
            (_screenCenterPoint[0] + (_secondHand[0] + _secondHand[3]) * sin + 0.5).toNumber(),
            (_screenCenterPoint[1] - (_secondHand[0] + _secondHand[3]) * cos + 0.5).toNumber() 
        ] as Array<Number>;
        var secondHandCoords = generatePolygonCoords(_secondHand, second);
        var radius = _secondHand[4].toNumber();

        // Set the clipping region
        var boundingBoxCoords = [ 
            secondHandCoords[0], secondHandCoords[1], secondHandCoords[2], secondHandCoords[3],
            [ secondCircleCenter[0] - radius, secondCircleCenter[1] - radius ],
            [ secondCircleCenter[0] + radius, secondCircleCenter[1] - radius ],
            [ secondCircleCenter[0] + radius, secondCircleCenter[1] + radius ],
            [ secondCircleCenter[0] - radius, secondCircleCenter[1] + radius ]
        ] as Array< Array<Number> >;
        var minX = 65536;
        var minY = 65536;
        var maxX = 0;
        var maxY = 0;
        for (var i = 0; i < boundingBoxCoords.size(); i++) {
            if (boundingBoxCoords[i][0] < minX) {
                minX = boundingBoxCoords[i][0];
            }
            if (boundingBoxCoords[i][1] < minY) {
                minY = boundingBoxCoords[i][1];
            }
            if (boundingBoxCoords[i][0] > maxX) {
                maxX = boundingBoxCoords[i][0];
            }
            if (boundingBoxCoords[i][1] > maxY) {
                maxY = boundingBoxCoords[i][1];
            }
        }
        // Add one pixel on each side for good measure
        dc.setClip(minX - 1, minY - 1, maxX + 1 - (minX - 1), maxY + 1 - (minY - 1));

        // Draw the second hand
        dc.setColor(_colors[_colorMode][C_SECONDS], Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(secondHandCoords);
        dc.fillCircle(secondCircleCenter[0], secondCircleCenter[1], radius);
    }

    //! Generate the screen coordinates of the four corners of a polygon (trapezoid) used to draw 
    //! a watch hand or a tick mark. The coordinates are generated using a specified height,
    //! and two separate widths, and are rotated around the center point at the provided angle.
    //! 0 degrees is at the 12 o'clock position, and increases in the clockwise direction.
    //! @param shape Definition of the polygon (in pixels) as follows
    //!        shape[0] The height of the polygon
    //!        shape[1] Width of the polygon at the tail of the hand or tick mark
    //!        shape[2] Width of the polygon at the tip of the hand or tick mark
    //!        shape[3] Distance from the center of the watch to the tail side 
    //!                 (negative for a watch hand with a tail) of the polygon
    //! @param angle Angle of the hand in radians (Float) or in minutes (Number, between 0 and 59)
    //! @return The coordinates of the polygon (watch hand or tick mark)
    private function generatePolygonCoords(shape as Array<Numeric>, angle as Float or Number) as Array< Array<Number> > {
        // Map out the coordinates of the polygon (trapezoid)
        var coords = [[-(shape[1] / 2), -shape[3]] as Array<Number>,
                      [-(shape[2] / 2), -(shape[3] + shape[0])] as Array<Number>,
                      [shape[2] / 2, -(shape[3] + shape[0])] as Array<Number>,
                      [shape[1] / 2, -shape[3]] as Array<Number>] as Array< Array<Number> >;

        // Rotate the coordinates
        var sin = 0.0;
        var cos = 0.0;
        switch (angle) {
            case instanceof Float:
                sin = Math.sin(angle);
                cos = Math.cos(angle);
                break;
            case instanceof Number:
                sin = _sin[angle];
                cos = _sin[(angle as Number + 15) % 60];
                break;
        }
        var result = new Array< Array<Number> >[4];
        for (var i = 0; i < 4; i++) {
            var x = (coords[i][0] * cos - coords[i][1] * sin + 0.5).toNumber();
            var y = (coords[i][0] * sin + coords[i][1] * cos + 0.5).toNumber();

            result[i] = [_screenCenterPoint[0] + x, _screenCenterPoint[1] + y];
        }
        return result;
    }

    //! This method is called when the device re-enters sleep mode
    public function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    //! This method is called when the device exits sleep mode
    public function onExitSleep() as Void {
        _isAwake = true;
    }

    //! Indicate if partial updates are on or off (only used with false)
    public function setPartialUpdates(doPartialUpdates as Boolean) as Void {
        _doPartialUpdates = doPartialUpdates;
    }
}

//! Receives watch face events
class SwissRailwayClockDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as SwissRailwayClockView;

    //! Constructor
    //! @param view The analog view
    public function initialize(view as SwissRailwayClockView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! The onPowerBudgetExceeded callback is called by the system if the
    //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
    //! the system will stop invoking onPartialUpdate each second, so we notify the
    //! view here to let the rendering methods know they should not be rendering a
    //! second hand.
    //! @param powerInfo Information about the power budget
    public function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        System.println("Average execution time: " + powerInfo.executionTimeAverage);
        System.println("Allowed execution time: " + powerInfo.executionTimeLimit);

        _view.setPartialUpdates(false);
    }
}

    // DEBUG
    function typeName(obj) {
        if (obj instanceof Toybox.Lang.Number) {
            return "Number";
        } else if (obj instanceof Toybox.Lang.Long) {
            return "Long";
        } else if (obj instanceof Toybox.Lang.Float) {
            return "Float";
        } else if (obj instanceof Toybox.Lang.Double) {
            return "Double";
        } else if (obj instanceof Toybox.Lang.Boolean) {
            return "Boolean";
        } else if (obj instanceof Toybox.Lang.String) {
            return "String";
        } else if (obj instanceof Toybox.Lang.Array) {
            var s = "Array [";
            for (var i = 0; i < obj.size(); ++i) {
                s += typeName(obj);
                s += ", ";
            }
            s += "]";
            return s;
        } else if (obj instanceof Toybox.Lang.Dictionary) {
            var s = "Dictionary{";
            var keys = obj.keys();
            var vals = obj.values();
            for (var i = 0; i < keys.size(); ++i) {
                s += keys;
                s += ": ";
                s += vals;
                s += ", ";
            }
            s += "}";
            return s;
        } else if (obj instanceof Toybox.Time.Gregorian.Info) {
            return "Gregorian.Info";
        } else {
            return "???";
        }
    }
