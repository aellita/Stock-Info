//
//  ViewController.swift
//  StocksInfo
//
//  Created by Аэлита Лукманова on 04.09.2021.
//

import UIKit

class ViewController: UIViewController {

    // UI
    @IBOutlet weak var companyNameButton: UIButton!
    @IBOutlet weak var companyPickerView: UIPickerView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var companySymbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var infoStackView: UIStackView!
    
    @IBOutlet weak var mainScrollView: UIScrollView!
    
    
    // MARK:- Private vars
    private var companies = [String:String]()
    
    private var companiesInfoDict = CompanyInfo.loadInfo() {
        didSet {
            CompanyInfo.save(companiesInfoDict)
        }
    }
    
    static let tokenKey = "tokenKey"
    private var token = UserDefaults.standard.string(forKey: tokenKey) ?? ""
    
    
    private let refreshControl = UIRefreshControl()
    
    
    // MARK: - /Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        companyNameButton.titleLabel?.numberOfLines = 0
                
        infoStackView.isHidden = true
        
        companyPickerView.isHidden = true
        companyPickerView.dataSource = self
        companyPickerView.delegate = self
        
        activityIndicator.hidesWhenStopped = true
        
        if companiesInfoDict.count != 0 {
            for company in companiesInfoDict {
                let info = company.value
                companies[info.companyName] = info.companySymbol
            }
        }
        
        refreshControl.addTarget(self, action: #selector(refetchingData), for: .valueChanged)
        mainScrollView.refreshControl = refreshControl
    }
    
    @objc func refetchingData() {
        if companiesInfoDict.count != 0 {
            CompanyInfo.removeInfo()
        }
        companyNameButton.setTitle("Select", for: .normal)
        refreshControl.endRefreshing()
        infoStackView.isHidden = true
        companyPickerView.isHidden = true
    }

    // MARK: - IBAction
    @IBAction func chooseCompanyNameButtonPressed(_ sender: Any) {
        activityIndicator.startAnimating()
        if companiesInfoDict.count == 0 {
            requestMostActive()
        } else {
            requestQuoteUpdate()
        }
    }
    
    // MARK: - Private funcs
  
    private func requestQuoteUpdate() {
        activityIndicator.startAnimating()
        companyNameButton.setTitle("", for: .normal)
        companySymbolLabel.text = "-"
        priceLabel.text = "-"
        priceChangeLabel.text = "-"
        
        priceChangeLabel.textColor = .none
        
        let selectedRow = companyPickerView.selectedRow(inComponent: 0)
        if !self.companies.isEmpty {
            let selectedSymbol = Array(companies.values)[selectedRow]
            if let companyInfo = companiesInfoDict[selectedSymbol] {
                displayStockInfo(companyName: companyInfo.companyName,
                                 symbol: companyInfo.companySymbol,
                                 price: companyInfo.price,
                                 priceChange: companyInfo.priceChange,
                                 priceChangePercent: companyInfo.priceChangePercent)
            } else {
                requestQuote(for: selectedSymbol)
            }
        }
    }
    
    private func requestQuote(for symbol: String) {
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/quote?token=\(token)") else
        {
            callErrorAllert(title: "Invalid url", message: "Check in code")
            return
        }

        let dataTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            if let data = data,
               (response as? HTTPURLResponse)?.statusCode == 200,
               error == nil {
                self?.parseQuote(from: data)
            } else {
                
                var title = "Failed to get data!"
                var message = "Unknown error"
                
                if !NetworkMonitor.shared.isConnected {
                    title = "You are not connected to the Internet"
                    message = "Check connection"
                }
                
                if let httpResponse = (response as? HTTPURLResponse) {
                    title = HTTPURLResponse.localizedString(forStatusCode: (httpResponse.statusCode))
                    message = "Status code: \(httpResponse.statusCode)"
                    
                    if httpResponse.statusCode == 403 || httpResponse.statusCode == 400 {
                        DispatchQueue.main.async {
                            self?.alertWithToken()
                        }
                        return
                    }
                }
                
                
                DispatchQueue.main.async {
                    self?.alert(title: title, message: message, style: .alert)
                }
            }
        }
        dataTask.resume()
    }
    
    private func parseQuote(from data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let companyName = json["companyName"] as? String,
                companyName != "",
                let companySymbol = json["symbol"] as? String,
                companySymbol != "",
                let price = json["latestPrice"] as? Double,
                price != 0,
                let priceChange = json["change"] as? Double,
                price != 0,
                let priceChangePercent = json["changePercent"] as? Double,
                priceChangePercent != 0
            else {
                DispatchQueue.main.async {
                    self.alert(title: "Invalid JSON!", message: "Check connection", style: .alert)
                }
                return
            }
            
            let companyInfo = CompanyInfo(companyName: companyName,
                                          companySymbol: companySymbol,
                                          price: price,
                                          priceChange: priceChange,
                                          priceChangePercent: priceChangePercent)
            companiesInfoDict[companySymbol] = companyInfo
            
            DispatchQueue.main.async {
                self.displayStockInfo(companyName: companyName,
                                      symbol: companySymbol,
                                      price: price,
                                      priceChange: priceChange,
                                      priceChangePercent: priceChangePercent)
            }
        } catch {
            DispatchQueue.main.async {
                self.alert(title: "! JSON parsing error:", message: error.localizedDescription, style: .alert)
            }
        }
    }
    
    private func displayStockInfo(companyName: String,
                                  symbol: String,
                                  price: Double,
                                  priceChange: Double,
                                  priceChangePercent: Double) {
        activityIndicator.stopAnimating()
        infoStackView.isHidden = false
        companyPickerView.isHidden = false
        
        companyNameButton.setTitle(companyName, for: .normal)
        companySymbolLabel.text = symbol
        priceLabel.text = "\(price) USD"
        priceChangeLabel.text = "\(priceChange) (\(String(format: "%.2f", abs(priceChangePercent * 100)))%)"
        
        if priceChange > 0 {
            priceChangeLabel.text!.insert("+", at: priceChangeLabel.text!.startIndex)
            priceChangeLabel.text?.append("\u{2191}")
            priceChangeLabel.textColor = .systemGreen
        } else if priceChange < 0 {
            priceChangeLabel.text?.append("\u{2193}")
            priceChangeLabel.textColor = .systemRed
        }
    }
    
    
    
    private func requestMostActive() {
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/market/list/mostactive/quote?token=\(token)")
        else {
            return
        }

        let dataTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            if let data = data,
               (response as? HTTPURLResponse)?.statusCode == 200,
               error == nil {
                self?.parseMostActive(from: data) { [weak self] nameAndSymbolsDict in
                    if nameAndSymbolsDict.isEmpty {
                        self?.callErrorAllert(title: "Something went wrong", message: "Check url of request")
                        return
                    }
                    self?.companies = nameAndSymbolsDict
                    DispatchQueue.main.async {
                        self?.companyPickerView.reloadAllComponents()
                        self?.requestQuoteUpdate()
                    }
                }
                
            } else {
                var title = "Failed to get data!"
                var message = "Unknown error"
                
                if !NetworkMonitor.shared.isConnected {
                    title = "You are not connected to the Internet"
                    message = "Check connection"
                }
                
                if let httpResponse = (response as? HTTPURLResponse) {
                    title = HTTPURLResponse.localizedString(forStatusCode: (httpResponse.statusCode))
                    message = "Status code: \(httpResponse.statusCode)"
                    
                    if httpResponse.statusCode == 403 || httpResponse.statusCode == 400 {
                        DispatchQueue.main.async {
                            self?.alertWithToken()
                        }
                        return
                    }
                }
                
                self?.callErrorAllert(title: title, message: message)
                print("Error!")
            }
        }
        dataTask.resume()
    }
    
    private func parseMostActive(from data : Data, completion : (_ nameAndSymbolsDict : [String : String])->Void) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [[String: Any]]
            else {
                callErrorAllert(title : "Invalid JSON!", message : "")
                return
            }
            var nameAndSymbolsDict = [String:String]()
            for companyInfo in json {
                if let symbol = companyInfo["symbol"] as? String {
                    if let name = companyInfo["companyName"] as? String {
                        nameAndSymbolsDict[name] = symbol
                    }
                }
            }
            completion(nameAndSymbolsDict)
            
        } catch {
            callErrorAllert(title :  "! JSON parsing error:",
                            message : error.localizedDescription)
        }
    }
    
    
    private func callErrorAllert(title : String, message : String) {
        DispatchQueue.main.async {
            self.alert(title: title, message: message, style: .alert)
        }
    }
    
    //UIAlertController
    private func alert(title: String, message: String, style: UIAlertController.Style) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: style)
        let action = UIAlertAction(title: "OK", style: .default)
        
        alertController.addAction(action)
        self.present(alertController, animated: true, completion: nil)
        self.activityIndicator.stopAnimating()
        self.refreshControl.endRefreshing()
    }
    
    private func alertWithToken() {
        
        var title = "To work with this app you need to input token"
        var message = ""
        
        if token != "" {
            title = "This may be incorrect token:"
            message = "Check it and press OK"
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.text = self.token
        }
        
        let confirmAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in

            let newToken = alertController.textFields?.first?.text ?? ""
            print(newToken)
            UserDefaults.standard.set(newToken, forKey: ViewController.tokenKey)
            self?.token = newToken
            self?.requestMostActive()
        }
        alertController.addAction(confirmAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
}

// MARK: - UIPickerViewDataSourse

extension ViewController: UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return Array(companies.keys).count
    }
}

// MARK: - UIPickerViewDelegate

extension ViewController : UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(companies.keys)[row]

    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        requestQuoteUpdate()
        
    }
}
