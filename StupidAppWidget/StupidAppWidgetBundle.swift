import WidgetKit
import SwiftUI

@main
struct StupidAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        LockScreenWidget()
        DoseCountdownActivity()
        if #available(iOS 18.0, *) {
            LogControl()
        }
    }
}
