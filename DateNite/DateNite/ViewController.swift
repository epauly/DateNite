//
//  ViewController.swift
//  DateNite
//
//  Created by Eric Pauly on 11/27/21.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource,
                        CLLocationManagerDelegate, UISearchBarDelegate, MKLocalSearchCompleterDelegate {

    private var categories: [String:[String]] = [:]
    private var activities: [String] = []
    
    private var searchCompleter = MKLocalSearchCompleter()
    private var searchResults = [MKLocalSearchCompletion]()
    
    private var categoryPickerIsLocked = false
    private var activityPickerIsLocked = false
    
    let locationManager = CLLocationManager()
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchTable: UITableView!
    
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var categoryPicker: UIPickerView!
    @IBOutlet weak var activityPicker: UIPickerView!
    
    @IBOutlet weak var findButton: UIButton!
    @IBOutlet weak var categoryLockButton: UIButton!
    @IBOutlet weak var activityLockButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let URL = Bundle.main.url(forResource: "Activities", withExtension: "plist") {
            if let dictionary = NSDictionary(contentsOf: URL) as? [String:[String]] {
                categories = dictionary
            }
        }
        setActivities()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        locationManager.delegate = self
        
        searchBar?.delegate = self
        searchCompleter.delegate = self
        searchTable?.delegate = self
        searchTable?.dataSource = self
        
        searchTable.isHidden = true
    }
    
    @IBAction func categoryLockButtonTapped(_ sender: UIButton) {
        if categoryPickerIsLocked == false {
            sender.setImage(UIImage(systemName: "lock.fill"), for: .normal)
            categoryPicker.isUserInteractionEnabled = false
            categoryPickerIsLocked = true
        } else {
            sender.setImage(UIImage(systemName: "lock.open.fill"), for: .normal)
            categoryPicker.isUserInteractionEnabled = true
            categoryPickerIsLocked = false
        }
    }
    
    @IBAction func activityLockButtonTapped(_ sender: UIButton) {
        if activityPickerIsLocked == false {
            sender.setImage(UIImage(systemName: "lock.fill"), for: .normal)
            activityPicker.isUserInteractionEnabled = false
            activityPickerIsLocked = true
        } else {
            sender.setImage(UIImage(systemName: "lock.open.fill"), for: .normal)
            activityPicker.isUserInteractionEnabled = true
            activityPickerIsLocked = false
        }
    }
    
    @IBAction func findButtonPressed(_ sender: UIButton) {
        var rng: Int = -1

        if !categoryPickerIsLocked {
            rng = Int.random(in: 0..<categories.count)
            categoryPicker.selectRow(rng, inComponent: 0, animated: true)
            pickerView(categoryPicker, didSelectRow: rng, inComponent: 0)
        }

        if !activityPickerIsLocked {
            rng = Int.random(in: 0..<activities.count)
            activityPicker.selectRow(rng, inComponent: 0, animated: true)
            
        }
        
        let item = activityPicker.selectedRow(inComponent: 0)
        let selectedActivity = activities[item]
    
        //print(selectedActivity) // debugging - can comment out
        
        search(using: selectedActivity)
    }
    
    // MARK: - Search
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchCompleter.queryFragment = searchText
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchTable.isHidden = false
        searchResults = completer.results
        searchTable.reloadData()
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        //print(error)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchTable.isHidden = true
        if !searchBar.text!.isEmpty {
            self.searchBar.endEditing(true)
            searchBar.layer.borderWidth = 0
            setRegion(using: searchBar.text!)
        } else {
            searchBar.layer.borderWidth = 2.0
            searchBar.layer.borderColor = UIColor.red.cgColor
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.searchBar.endEditing(true)
        searchTable.isHidden = true
    }

    // MARK: - Picker
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == categoryPicker {
            return categories.count
        } else {
            return activities.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == categoryPicker {
            return Array(categories.keys).sorted()[row]
        } else {
            return activities[row]
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        setActivities()
        if pickerView == categoryPicker {
            activityPicker.selectRow(0, inComponent: 0, animated: true)
        }
        activityPicker.reloadComponent(0)
    }
    
    // MARK: - Map
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            locationManager.stopUpdatingLocation()
            
            render(location)
        }
    }
    
    func render(_ location: CLLocation) {
        let coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
        
        getLocationName(with: location) { [weak self] locationName in
            self?.searchBar.text = locationName
        }

    }
    
    // Search for points of interest
    private func search(using selectedActivity: String) {
        mapView.removeAnnotations(mapView.annotations) // clear previous pins
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = selectedActivity
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        search.start(completionHandler: { (response, error) in
            if let results = response {
                if error != nil {
                    print("Error in search.")
                } else if results.mapItems.count == 0 {
                    print("No matches found.")
                } else {
                    for item in results.mapItems {
                        let pin = MKPointAnnotation()
                        pin.coordinate = item.placemark.coordinate
                        pin.title = item.name
                        pin.subtitle = item.phoneNumber
                        self.mapView.addAnnotation(pin)
                    }
                }
            }
        })
    }
    
    private func setRegion(using newAddress: String) {
        mapView.removeAnnotations(mapView.annotations) // clear previous pins
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = newAddress
        
        let search = MKLocalSearch(request: request)
        search.start(completionHandler: { (response, error) in
            if let results = response {
                if error != nil {
                    print("Error in search.")
                } else if results.mapItems.count == 0 {
                    print("No matches found.")
                } else {
                    let lat = results.mapItems[0].placemark.coordinate.latitude
                    let long = results.mapItems[0].placemark.coordinate.longitude
                    
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                    let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    let region = MKCoordinateRegion(center: coordinate, span: span)
                    
                    self.mapView.setRegion(region, animated: true)
                }
            }
        })
    }
    
    // Reverse geocode to get name from current location
    private func getLocationName(with location: CLLocation, completion: @escaping ((String?) -> Void)) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location, preferredLocale: .current) { placemarks, error in
            guard let place = placemarks?.first, error == nil else {
                completion(nil)
                return
            }
            
            var name = ""
            
            if let locality = place.locality {
                name += locality
            }
            
            if let adminRegion = place.administrativeArea {
                name += ", \(adminRegion)"
            }
            
            completion(name)
        }
    }
    
    // MARK: - Functions
    func setActivities() { // set component 2 based on component 1 selection
        if categories.isEmpty || categories.count == 0 {
            print("Picker unable to populate from plist.")
            return
        }
        
        let category = Array(categories.keys).sorted()
        let selected = category[categoryPicker.selectedRow(inComponent: 0)]
        activities = (categories[selected]?.sorted())!
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.row == 0 {
            let cell = searchTable.dequeueReusableCell(withIdentifier: "currentLocCell", for: indexPath)
            cell.textLabel?.text = "Use Current Location"
            return cell
        } else {
            let searchResult = searchResults[indexPath.row - 1]
            let cell = searchTable.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = searchResult.title
            cell.detailTextLabel?.text = searchResult.subtitle
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        searchTable.deselectRow(at: indexPath, animated: true)
        
        if indexPath.row == 0 {
            searchBar.text = "Current Location"
            locationManager.requestWhenInUseAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        
        } else {
            let result = searchResults[indexPath.row - 1]
            searchBar.text = result.title
            setRegion(using: searchBar.text!)
        }
        
        searchBar.endEditing(true)
        searchTable.isHidden = true
        searchBar.layer.borderWidth = 0
        
        // debugging - can comment out
//        let request = MKLocalSearch.Request(completion: result)
//        let search = MKLocalSearch(request: request)
//        search.start { (response, error) in
//            guard let coordinate = response?.mapItems[0].placemark.coordinate else {
//                return
//            }
//
//            guard let name = response?.mapItems[0].name else {
//                return
//            }
//
//            print(name)
//
//            let lat = coordinate.latitude
//            let long = coordinate.longitude
//
//            print(lat)
//            print(long)
//        }
    }
}
