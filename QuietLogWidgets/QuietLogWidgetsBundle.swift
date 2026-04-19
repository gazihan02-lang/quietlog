// QuietLogWidgetsBundle.swift
// QuietLog Widget Extension

import SwiftUI
import WidgetKit

@main
struct QuietLogWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CircularDBWidget()
        SmallDBWidget()
        MediumDBWidget()
    }
}
