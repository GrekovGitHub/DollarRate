//
//  RateSettings.swift
//  DollarRate
//
//  Created by Rostislav on 6/7/21.
//

import Foundation

final class RateSettings {
    
    private static let defaults = UserDefaults.standard
    
    static var clientRate: String! {
        get{
            return defaults.string(forKey: "clientRate")
        }
        set{
            if let clientRate = newValue {
                defaults.set(clientRate, forKey: "clientRate")
            } else {
                defaults.removeObject(forKey: "clientRate")
            }
        }
    }
    
}
