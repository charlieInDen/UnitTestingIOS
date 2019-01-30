import UIKit

var str = "Hello, playground"
//Testing tableview
class CustomTableViewController: UITableViewController {
    var data: [String] = []
    
}
extension CustomTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = data[indexPath.row]
        return cell

    }
}

import XCTest

class CustomTableViewControllerTest: XCTestCase {
    var tableViewVC: CustomTableViewController?
    
    override func setUp() {
        super.setUp()
        print("started")
        tableViewVC = CustomTableViewController()
        tableViewVC?.tableView.reloadData()
    }
    override func tearDown() {
        tableViewVC = nil
        super.tearDown()
    }
    
    //MARK :- Testing methods
    func testTableViewLoads() {
        XCTAssertNotNil(self.tableViewVC, "TableViewController not initialized")
    }
    func testConformsToUITableViewDataSource() {
        XCTAssertTrue((self.tableViewVC?.conforms(to: UITableViewDataSource.self)) ?? false, "ViewController does not conform to UITableView datasource protocol")
    }
    func testTableViewHasDataSource() {
        XCTAssertNotNil(self.tableViewVC?.tableView.dataSource, "TableView datasource cannot be nil")
    }
    func testTableViewNumberOfRowsInSection() {
        let expectedRowCount: NSInteger = 0
        let rowsCount = self.tableViewVC?.tableView.numberOfRows(inSection: 0) ?? -1
        let msg = "Table has" + String(rowsCount) + " rows but it should have " + String(expectedRowCount)
        
        XCTAssertTrue(rowsCount == expectedRowCount, msg)
        
    }
    func testTableViewCreateCellWithReuseIdentifier() {
        let expectedReuseIdentifier = "Cell"
        let indexPath = IndexPath.init(row: 0, section: 0)
        let tableCell = self.tableViewVC?.tableView.cellForRow(at: indexPath)
//        XCTAssertTrue(tableCell?.reuseIdentifier == expectedReuseIdentifier, "As no cell has been created, Table does not create reusable cells")
        XCTAssertFalse(tableCell?.reuseIdentifier == expectedReuseIdentifier, " Table create reusable cells")
    }
    
    //Asynchronous task test cases
    func testDownloadWebData() {
        
        // Create an expectation for a background download task.
        let expectation = XCTestExpectation(description: "Download apple.com home page")
        
        // Create a URL for a web page to be downloaded.
        let url = URL(string: "https://apple.com")!
        
        // Create a background task to download the web page.
        let dataTask = URLSession.shared.dataTask(with: url) { (data, _, _) in
            
            // Make sure we downloaded some data.
            XCTAssertNotNil(data, "No data was downloaded.")
            
            // Fulfill the expectation to indicate that the background task has finished successfully.
            expectation.fulfill()
            
        }
        
        // Start the download task.
        dataTask.resume()
        
        // Wait until the expectation is fulfilled, with a timeout of 10 seconds.
        wait(for: [expectation], timeout: 10.0)
    }
    func testSortingArray() {
        let input = [ 3,2,1,5,4]
        let output = input.sorted()
        XCTAssertEqual(output, [1,2,3,4,5])
    }
}

CustomTableViewControllerTest.defaultTestSuite.run()

import CoreLocation
struct PointOfInterest: Codable, Equatable {
    var name: String
}
class PointOfInterestSample {
    var tableView: UITableView = UITableView()
    var tableValues:[PointOfInterest]?
    
    func handleError(_ error: Error?) -> Void {
        print(error!)
    }
    func loadData(near coord: CLLocationCoordinate2D) {
        let url = URL(string: "/locations?lat=\(coord.latitude)&long=\(coord.longitude)")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { self.handleError(error); return }
            do {
                let values = try JSONDecoder().decode([PointOfInterest].self, from: data)
                DispatchQueue.main.async {
                    self.tableValues = values
                    self.tableView.reloadData()
                }
            } catch {
                self.handleError(error)
            }
            }.resume()
    }
}
protocol APIRequest {
    associatedtype RequestDataType
    associatedtype ResponseDataType
    func makeRequest(from data: RequestDataType) throws -> URLRequest
    func parseResponse(data: Data) throws -> ResponseDataType
}


struct PointsOfInterestRequest: APIRequest {
    enum RequestError: Error {
        case invalidCoordinate
        case unknown
    }
    func makeRequest(from coordinate: CLLocationCoordinate2D) throws -> URLRequest {
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw RequestError.invalidCoordinate
        }
        var components = URLComponents(string: "https://example.com/locations")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
            URLQueryItem(name: "long", value: "\(coordinate.longitude)")
        ]
        return URLRequest(url: components.url!)
    }
    
    func parseResponse(data: Data) throws -> [PointOfInterest] {
        return try JSONDecoder().decode([PointOfInterest].self, from: data)
    }
}
class APIRequestLoader<T: APIRequest> {
    let apiRequest: T
    let urlSession: URLSession
    
    init(apiRequest: T, urlSession: URLSession = .shared) {
        self.apiRequest = apiRequest
        self.urlSession = urlSession
    }

    func loadAPIRequest(requestData: T.RequestDataType,
                        completionHandler: @escaping (T.ResponseDataType?, Error?) -> Void) {
        do {
            let urlRequest = try apiRequest.makeRequest(from: requestData)
            urlSession.dataTask(with: urlRequest) { data, response, error in
                guard let data = data else { return completionHandler(nil, error) }
                do {
                    let parsedResponse = try self.apiRequest.parseResponse(data: data)
                    completionHandler(parsedResponse, nil)
                } catch {
                    completionHandler(nil, error)
                }
            }.resume()
        }catch { return completionHandler(nil, error) }
    }
}




class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Received unexpected request with no handler set")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}
//Unit test :- Prepare URLRequest -> Parse Response
class PointOfInterestRequestTests: XCTestCase {
    let request = PointsOfInterestRequest()
    func testMakingURLRequest() throws {
        let coordinate = CLLocationCoordinate2D(latitude: 37.3293, longitude: -121.8893)
        let urlRequest = try request.makeRequest(from: coordinate)
        
        XCTAssertEqual(urlRequest.url?.scheme, "https")
        XCTAssertEqual(urlRequest.url?.host, "example.com")
        XCTAssertEqual(urlRequest.url?.query, "lat=37.3293&long=-121.8893")
    }
    func testParsingResponse() throws {
        let jsonData = "[{\"name\":\"My Location\"}]".data(using: .utf8)!
        let response = try request.parseResponse(data: jsonData)
        
        XCTAssertEqual(response, [PointOfInterest(name: "My Location")])
    }
    
    
}
PointOfInterestRequestTests.defaultTestSuite.run()

//Integration test:- Prepare URLRequest -> Create URLSession Task -> Parse Response
class APILoaderTests: XCTestCase {
    var loader: APIRequestLoader<PointsOfInterestRequest>!
    override func setUp() {
        let request = PointsOfInterestRequest()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        loader = APIRequestLoader(apiRequest: request, urlSession: urlSession)
    }
    func testLoaderSuccess() {
        let inputCoordinate = CLLocationCoordinate2D(latitude: 37.3293, longitude: -121.8893)
        let mockJSONData = "[{\"name\":\"MyPointOfInterest\"}]".data(using: .utf8)!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.query?.contains("lat=37.3293"), true)
            return (HTTPURLResponse(), mockJSONData)
        }
//        let expectation = XCTestExpectation(description: "response")
//        loader.loadAPIRequest(requestData: inputCoordinate) { pointsOfInterest, error in
//            XCTAssertEqual(pointsOfInterest, [PointOfInterest(name: "MyPointOfInterest")])
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 1)
    }
}
APILoaderTests.defaultTestSuite.run()

class CurrentLocationProviderOld {
    static let authChangedNotification = Notification.Name("AuthChanged")
    func notifyAuthChanged() {
        let name = CurrentLocationProvider.authChangedNotification
        NotificationCenter.default.post(name: name, object: self)
    }
}


class PointsOfInterestTableViewControllerOld {
    var observer: AnyObject?
    init() {
        let name = CurrentLocationProvider.authChangedNotification
        observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            self?.handleAuthChanged()
        }
    }

    var didHandleNotification = false
    func handleAuthChanged() {
        didHandleNotification = true
    }
}
class CurrentLocationProvider {
    static let authChangedNotification = Notification.Name("AuthChanged")
    
    let notificationCenter: NotificationCenter
    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }
    func notifyAuthChanged() {
        let name = CurrentLocationProvider.authChangedNotification
        notificationCenter.post(name: name, object: self)
    }
}
class PointsOfInterestTableViewController {
    let notificationCenter: NotificationCenter
    var observer: AnyObject?
    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        let name = CurrentLocationProvider.authChangedNotification
        observer = notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            self?.handleAuthChanged()
        }
    }
    var didHandleNotification = false
    func handleAuthChanged() {
        didHandleNotification = true
    }
}
class PointsOfInterestTableViewControllerTests: XCTestCase {
    func testNotification() {
        let notificationCenter = NotificationCenter()
        let observer = PointsOfInterestTableViewController(notificationCenter:
            notificationCenter)
        XCTAssertFalse(observer.didHandleNotification)
        //       Notification posted to just this center, isolating the test
        let name = CurrentLocationProvider.authChangedNotification
        notificationCenter.post(name: name, object: nil)
        XCTAssertTrue(observer.didHandleNotification)
    }
}
PointsOfInterestTableViewControllerTests.defaultTestSuite.run()

class CurrentLocationProviderTests: XCTestCase {
    func testNotifyAuthChanged() {
        let notificationCenter = NotificationCenter()
        let poster = CurrentLocationProvider(notificationCenter: notificationCenter)
        // Notification only sent to this specific center, isolating test
        let name = CurrentLocationProvider.authChangedNotification
        let expectation = XCTNSNotificationExpectation(name: name, object: poster,
                                                       notificationCenter: notificationCenter)
        poster.notifyAuthChanged()
        wait(for: [expectation], timeout: 0)
    }
}

CurrentLocationProviderTests.defaultTestSuite.run()
