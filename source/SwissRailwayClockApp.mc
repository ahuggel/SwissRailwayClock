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

    // onStop() is called when your application is exiting
    public function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    public function getInitialView() as Array<Views or InputDelegates>? {
        if (WatchUi has :WatchFaceDelegate) {
            var view = new $.SwissRailwayClockView();
            var delegate = new $.SwissRailwayClockDelegate(view);
            return [view, delegate] as Array<Views or InputDelegates>;
        } else {
            return [new $.SwissRailwayClockView()] as Array<Views>;
        }
    }

    //! Return the settings view and delegate
    //! @return Array Pair [View, Delegate]
    public function getSettingsView() as Array<Views or InputDelegates>? {
        return [new $.SettingsView(), new $.SwissRailwayClockSettingsDelegate()] as Array<Views or InputDelegates>;
    }

}

function getApp() as SwissRailwayClockApp {
    return Application.getApp() as SwissRailwayClockApp;
}
