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
    public function getInitialView() as [ Views ] or [ Views, InputDelegates ] {
        var view = new ClockView();
        var delegate = new ClockDelegate(view);
        return [view, delegate];
    }

    // Return the settings view and delegate
    // @return Array Pair [View, Delegate]
    public function getSettingsView() as [ Views ] or [ Views, InputDelegates ] or Null {
        var view = new SettingsMenu();
        var delegate = new SettingsMenuDelegate(view);
        return [view, delegate];
    }
}

function getApp() as SwissRailwayClockApp {
    return Application.getApp() as SwissRailwayClockApp;
}
