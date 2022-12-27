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
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SwissRailwayClockApp extends Application.AppBase {

    // Constructor
    public function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    public function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when the application is exiting
    public function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view and delegate of the application 
    // (WatchFaceDelegate is available since API Level 2.3.0 )
    public function getInitialView() as Array<Views or InputDelegates>? {
        var view = new $.SwissRailwayClockView();
        var delegate = new $.SwissRailwayClockDelegate(view);
        return [view, delegate] as Array<Views or InputDelegates>;
    }

    //! Return the settings view and delegate
    //! @return Array Pair [View, Delegate]
    public function getSettingsView() as Array<Views or InputDelegates>? {
        var view = new $.SwissRailwayClockSettingsMenu();
        var delegate = new $.SwissRailwayClockSettingsMenuDelegate();
        return [view, delegate] as Array<Views or InputDelegates>;
    }
}

function getApp() as SwissRailwayClockApp {
    return Application.getApp() as SwissRailwayClockApp;
}
