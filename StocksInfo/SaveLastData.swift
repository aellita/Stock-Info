//
//  SaveLastData.swift
//  StocksInfo
//
//  Created by Аэлита Лукманова on 04.09.2021.
//

import Foundation

class CompanyInfo : Codable {
    
    var companyName : String
    var companySymbol : String
    var price : Double
    var priceChange : Double
    var priceChangePercent : Double
    
    init(companyName : String, companySymbol : String, price : Double, priceChange : Double, priceChangePercent : Double) {
        self.companyName = companyName
        self.companySymbol = companySymbol
        self.price = price
        self.priceChange = priceChange
        self.priceChangePercent = priceChangePercent
    }
}


extension CompanyInfo {
    static var userDefaultsKey = "InfoKey"
    
    static func save(_ companiesInfoDict : [String : CompanyInfo]) {
        let data = try? JSONEncoder().encode(companiesInfoDict)
        UserDefaults.standard.set(data, forKey: CompanyInfo.userDefaultsKey)
    }
    
    static func loadInfo() -> [String : CompanyInfo] {
        var returnValue = [String : CompanyInfo]()
        if let data = UserDefaults.standard.data(forKey: CompanyInfo.userDefaultsKey),
           let companyInfoDict = try? JSONDecoder().decode([String : CompanyInfo].self, from: data) {
            returnValue = companyInfoDict
        }
        return returnValue
    }
    
    static func removeInfo() {
        UserDefaults.standard.removeObject(forKey: CompanyInfo.userDefaultsKey)
        UserDefaults.standard.synchronize()
    }
}
