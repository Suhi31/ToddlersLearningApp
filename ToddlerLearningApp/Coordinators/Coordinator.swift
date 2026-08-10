//
//  Coordinator.swift
//  ToddlerLearningApp
//

import Foundation

/// The navigation contract. Views hold a coordinator and express intent
/// (`push(.quiz)`); they never construct a destination view themselves.
@MainActor
protocol Coordinator: AnyObject {
    var path: [Route] { get set }

    func push(_ route: Route)
    func popToRoot()
}

extension Coordinator {

    func push(_ route: Route) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }
}
