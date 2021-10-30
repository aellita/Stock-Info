//
//  NetworkMonitor.swift
//  StocksInfo
//
//  Created by Аэлита Лукманова on 05.09.2021.
//

import Foundation
import Network


final class NetworkMonitor {
    static let shared = NetworkMonitor()
     
    private let queue = DispatchQueue.global()
    private let monitor : NWPathMonitor
    
    public private(set) var isConnected : Bool = false 
    
    public var connectionType : ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethenret
        case unknown
    }
    
    private init() {
        monitor = NWPathMonitor()
    }
    
    public func startMonitoring() {
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status != .unsatisfied
            self?.getConnectionType(path)
        }
    }
    
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    
    private func getConnectionType(_ path:NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethenret
        } else {
            connectionType = .unknown
        }

    }
}
