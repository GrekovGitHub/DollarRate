import UIKit
import Alamofire
import SWXMLHash

class DollarRateViewController: UIViewController {
    
    @IBOutlet weak var rateView: UIView!
    @IBOutlet weak var currentDollarRateLabel: UILabel!
    @IBOutlet weak var ratesTableView: UITableView!
    @IBOutlet weak var incorrectRateLabel: UILabel!
    @IBOutlet weak var clientRateTextField: UITextField!
    
    private let defaults = UserDefaults.standard
    
    private var items: [XMLItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clientRateTextField.text = RateSettings.clientRate
        ratesTableView.delegate = self
        ratesTableView.dataSource = self
        fetchRatesData()
        fetchCurrentRateData()
        makeAnimation()
        incorrectRateLabel.isHidden = true
    }
    
    private func fetchRatesData(){
        let date_req1 = formatDate(date: getLastMonthStart())
        let date_req2 = formatDate(date: getLastMonthEnd())
        AF.request("http://www.cbr.ru/scripts/XML_dynamic.asp?date_req1=\(date_req1)&date_req2=\(date_req2)&VAL_NM_RQ=R01235").validate().response {
            (response) in
            switch response.result {
            case .success(let data):
                let xml = SWXMLHash.parse(data!)
                for index in 0..<xml["ValCurs"]["Record"].all.count {
                    let subIndex = xml["ValCurs"]["Record"][index]
                    let id = subIndex.element?.attribute(by: "Id")?.text
                    let date = subIndex.element?.attribute(by: "Date")?.text
                    let value = subIndex["Value"].element?.text ?? "00.0000"
                    let item = XMLItem(id: id ?? "0", date: date ?? "0", value: value)
                    self.items.append(item)
                }
                self.ratesTableView.reloadData()
            case .failure(let error):
                print(error.localizedDescription)
            }
        } .resume()
    }
    
    private func getLastMonthStart() -> Date? {
        let components:NSDateComponents = Calendar.current.dateComponents([.day, .month, .year], from: Date()) as NSDateComponents
        components.day = 1
        components.month -= 1
        return Calendar.current.date(from: components as DateComponents)!
    }
    
    private func getLastMonthEnd() -> Date? {
        let components:NSDateComponents = Calendar.current.dateComponents([.day, .month, .year], from: Date()) as NSDateComponents
        components.day = 1
        components.day -= 1
        return Calendar.current.date(from: components as DateComponents)!
    }
    
    private func fetchCurrentRateData(){
        let todaysDate = formatDate(date: Date())
        AF.request("http://www.cbr.ru/scripts/XML_daily.asp?date_req=\(todaysDate)").validate().response {
            (response) in
            switch response.result {
            case .success(let data):
                let xml = SWXMLHash.parse(data!)
                let currentValute = xml["ValCurs"]["Valute"].filterAll{elem, _ in elem.attribute(by: "ID")!.text == "R01235"}
                let rate = currentValute["Value"].element?.text ?? "00.0000"
                self.currentDollarRateLabel.text = rate
                self.chooseColor()
            case .failure(let error):
                print(error.localizedDescription)
            }
        } .resume()
    }
    
    private func formatDate(date: Date?) -> String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        return dateFormatter.string(from: date!)
    }
    
    private func makeAnimation(){
        UIView.animateKeyframes(withDuration: 1.0, delay: 0.0, options: [.repeat, .autoreverse], animations: {
            self.currentDollarRateLabel.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }, completion: nil)
    }
    
    private func chooseColor(){
        guard let currentRate = parseToDouble(string: currentDollarRateLabel.text ?? "00.0000"),
              let clientRate = parseToDouble(string: clientRateTextField.text ?? "00.0000") else {
            return
        }
        currentDollarRateLabel.textColor = (currentRate > clientRate) ? .green : .red
    }
    
    private func parseToDouble(string: String) -> Double? {
        return Double(string.replacingOccurrences(of: ",", with: "."))
    }
    
    @IBAction func scheduleNotifications(){
        guard let currentRate = parseToDouble(string: currentDollarRateLabel.text ?? "00.0000"),
              let clientRate = parseToDouble(string: clientRateTextField.text ?? "00.0000") else {
            return
        }
        if currentRate > clientRate {
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "Уведомление"
            content.body = "Торопись! Курс доллара меньше заданного!"
            var dateComponents = DateComponents()
            dateComponents.hour = 10
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "UNNotificationRequest", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                guard error == nil else {
                    print(error ?? "Error with donate")
                    return
                }
            }
        }
    }
    
    @IBAction func saveInputRate(_ sender: UIButton) {
        guard let rate = clientRateTextField.text else {
            return
        }
        if rate.isValidRate {
            incorrectRateLabel.isHidden = true
            RateSettings.clientRate = clientRateTextField.text!
        } else {
            incorrectRateLabel.isHidden = false
        }
        clientRateTextField.endEditing(true)
    }
}

extension DollarRateViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! DollarRateTableViewCell
        cell.dateLabel.text = items[indexPath.row].date
        cell.rateLabel.text = items[indexPath.row].value
        cell.selectionStyle = .none
        return cell
    }
}

extension String {
    
    var isValidRate: Bool {
        let RegEx = "(([1-9][0-9][0-9])|([1-9][0-9])),([0-9]{4})"
        let Test = NSPredicate(format:"SELF MATCHES %@", RegEx)
        return Test.evaluate(with: self)
    }
}
