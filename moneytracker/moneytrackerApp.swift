//
//  moneytrackerApp.swift
//  moneytracker
//
//  Created by Joost Groen on 13.09.25.
//

import SwiftUI
import UIKit

@main
struct moneytrackerApp: App {
    init() {
        // Ensure SwiftUI List (UITableView) uses transparent backgrounds
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.pink)
        }
    }
}
