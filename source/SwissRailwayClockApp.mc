//
// Copyright 2016-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! This app demonstrates a basic analog watch face. It also shows
//! a new page when a goal is met and has an app settings menu.
class AnalogWatch extends Application.AppBase {

    //! Constructor
    public function initialize() {
        AppBase.initialize();
    }

    //! Handle app startup
    //! @param state Startup arguments
    public function onStart(state as Dictionary?) as Void {
    }

    //! Handle app shutdown
    //! @param state Shutdown arguments
    public function onStop(state as Dictionary?) as Void {
    }

    //! Return the initial view for the app
    //! @return Array Pair [View, Delegate] or Array [View]
    public function getInitialView() as Array<Views or InputDelegates>? {
        if (WatchUi has :WatchFaceDelegate) {
            var view = new $.AnalogView();
            var delegate = new $.AnalogDelegate(view);
            return [view, delegate] as Array<Views or InputDelegates>;
        } else {
            return [new $.AnalogView()] as Array<Views>;
        }
    }

    //! This method runs when a goal is triggered and the goal view is started.
    //! @param goal The goal type that triggered
    //! @return The view to push
    public function getGoalView(goal as GoalType) as Array<View>? {
        return [new $.AnalogGoalView(goal)] as Array<View>;
    }

    //! Return the settings view and delegate
    //! @return Array Pair [View, Delegate]
    public function getSettingsView() as Array<Views or InputDelegates>? {
        return [new $.AnalogSettingsView(), new $.AnalogSettingsDelegate()] as Array<Views or InputDelegates>;
    }
}
