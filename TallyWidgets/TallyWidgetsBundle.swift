//
//  TallyWidgetsBundle.swift
//  TallyWidgets
//
//  Created by Omar Johnson on 5/16/26.
//

import WidgetKit
import SwiftUI

@main
struct TallyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        TodayChecklistWidget()
    }
}
