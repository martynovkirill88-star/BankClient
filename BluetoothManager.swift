import Foundation
import CoreBluetooth
import UIKit
import Combine

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    static let shared = BluetoothManager()
    
    // Custom ATM Service UUID
    static let atmServiceUUID = CBUUID(string: "0000FFF0-0000-1000-8000-00805F9B34FB")
    
    @Published var isBluetoothEnabled: Bool = false
    @Published var isScanning: Bool = false
    @Published var isAtmNearby: Bool = false
    @Published var detectedAtmCode: String? = nil
    @Published var detectedAtmName: String = ""
    @Published var currentRssi: Int = -100
    @Published var proximityText: String = "Поиск банкомата..."
    
    private var centralManager: CBCentralManager?
    private var hasTriggeredHaptic: Bool = false
    
    override init() {
        super.init()
        // Do not block init, lazily instantiate when needed or initialize safely
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupCentralManager()
        }
    }
    
    private func setupCentralManager() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }
    
    func startScanning() {
        if centralManager == nil {
            setupCentralManager()
        }
        
        guard let central = centralManager else { return }
        
        guard central.state == .poweredOn else {
            isScanning = false
            switch central.state {
            case .poweredOff:
                proximityText = "Включите Bluetooth на телефоне"
            case .unauthorized:
                proximityText = "Нет доступа к Bluetooth (разрешите в Настройках)"
            default:
                proximityText = "Ожидание запуска Bluetooth..."
            }
            return
        }
        
        isScanning = true
        proximityText = "Сканирование эфира..."
        
        // Scan for ATM service or any BLE devices nearby with ATM prefix in name
        central.scanForPeripherals(
            withServices: [BluetoothManager.atmServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }
    
    func resetDetection() {
        isAtmNearby = false
        detectedAtmCode = nil
        detectedAtmName = ""
        currentRssi = -100
        hasTriggeredHaptic = false
        proximityText = "Ожидание банкомата..."
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothEnabled = true
            startScanning()
        case .poweredOff:
            isBluetoothEnabled = false
            isScanning = false
            proximityText = "Bluetooth выключен"
        case .unauthorized:
            isBluetoothEnabled = false
            proximityText = "Нет разрешения на Bluetooth"
        default:
            isBluetoothEnabled = false
            proximityText = "Bluetooth недоступен"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue
        currentRssi = rssiValue
        
        // Look for ATM name or advertised service data
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        
        var foundCode: String? = nil
        
        // Check if device name starts with "ATM-"
        if name.hasPrefix("ATM-") {
            foundCode = String(name.dropFirst(4))
        }
        
        // Check manufacturer data or service data
        if foundCode == nil, let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let data = serviceData[BluetoothManager.atmServiceUUID],
           let codeStr = String(data: data, encoding: .utf8) {
            foundCode = codeStr
        }
        
        // If we found an ATM or strong signal
        if let code = foundCode, !code.isEmpty {
            detectedAtmCode = code
            detectedAtmName = name.isEmpty ? "Банкомат" : name
            isAtmNearby = true
            
            // Proximity thresholds
            if rssiValue > -65 {
                proximityText = "Банкомат вплотную! (\(rssiValue) dBm)"
                if !hasTriggeredHaptic {
                    hasTriggeredHaptic = true
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                }
            } else if rssiValue > -80 {
                proximityText = "Рядом с банкоматом (\(rssiValue) dBm)"
            } else {
                proximityText = "Банкомат в зоне видимости (\(rssiValue) dBm)"
            }
        }
    }
}
