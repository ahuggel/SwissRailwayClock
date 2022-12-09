//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! This implements a goal view for the analog face
class AnalogGoalView extends WatchUi.View {
    private var _goalString as String;

    //! Initialize the string to display on the goal view.
    //! @param goal The goal triggered
    public function initialize(goal as GoalType) {
        View.initialize();

        _goalString = "GOAL!";

        if (goal == Application.GOAL_TYPE_STEPS) {
            _goalString = "STEPS " + _goalString;
        } else if (goal == Application.GOAL_TYPE_FLOORS_CLIMBED) {
            _goalString = "STAIRS " + _goalString;
        } else if (goal == Application.GOAL_TYPE_ACTIVE_MINUTES) {
            _goalString = "ACTIVE " + _goalString;
        }
    }

    //! Load your resources here
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {
        // Clear any clip that may currently be set by the partial update
        dc.clearClip();
    }

    //! Update the clock face graphics
    //! @param dc Device Context
    public function onUpdate(dc as Dc) as Void {
        var clockTime = System.getClockTime();

        var width = dc.getWidth();
        var height = dc.getHeight();

        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_LONG);

        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);

        // Fill the screen with a black rectangle
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, width, height);

        // Fill the top right half of the screen with a grey triangle
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
        dc.fillPolygon([[0, 0] as Array<Number>, [width, 0] as Array<Number>, [width, height] as Array<Number>, [0, 0] as Array<Number>]  as Array< Array<Number> >);

        // Draw the date
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height / 4, Graphics.FONT_MEDIUM, dateStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Draw the Goal String
        dc.drawText(width / 2, height / 2, Graphics.FONT_MEDIUM, _goalString, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
