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
    @Published var isVeryClose: Bool = false
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
        
        // Scan for ALL peripherals without strict UUID filter so ATM is detected immediately
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
    
    private var lastRestartTime: Date = Date()
    
    func restartScanIfNeeded() {
        guard centralManager?.state == .poweredOn else { return }
        // If not discovered yet or searching, refresh scan every 2.5 seconds to bust CoreBluetooth scan throttling
        if !isAtmNearby && Date().timeIntervalSince(lastRestartTime) > 2.5 {
            lastRestartTime = Date()
            centralManager?.stopScan()
            centralManager?.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }
    
    func resetDetection() {
        isAtmNearby = false
        isVeryClose = false
        detectedAtmCode = nil
        detectedAtmName = ""
        currentRssi = -100
        hasTriggeredHaptic = false
        lastRestartTime = Date()
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
    
    private func isValidAtmCode(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return trimmed.count == 6 && trimmed.allSatisfy { $0.isNumber }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue
        currentRssi = rssiValue
        
        // Look for ATM name or advertised service data
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        var foundCode: String? = nil
        
        // 1. Check device name starting with "RoPay-" or "ATM-"
        if name.hasPrefix("RoPay-") {
            let candidate = String(name.dropFirst(6))
            if isValidAtmCode(candidate) {
                foundCode = candidate
            }
        } else if name.hasPrefix("ATM-") {
            let candidate = String(name.dropFirst(4))
            if isValidAtmCode(candidate) {
                foundCode = candidate
            }
        }
        
        // 2. Check Service Data (UUID 0000FFF0...)
        if foundCode == nil, let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            for (uuid, data) in serviceData {
                if uuid == BluetoothManager.atmServiceUUID || uuid.uuidString.contains("FFF0") {
                    if let codeStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)), isValidAtmCode(codeStr) {
                        foundCode = codeStr
                        break
                    }
                }
            }
        }
        
        // 3. Check Service UUIDs (UUID 0000FFF0...) or prefix
        var isAtmDevice = (foundCode != nil)
        if !isAtmDevice, let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            for uuid in serviceUUIDs {
                if uuid == BluetoothManager.atmServiceUUID || uuid.uuidString.contains("FFF0") {
                    isAtmDevice = true
                    break
                }
            }
        }
        if !isAtmDevice && (name.hasPrefix("RoPay") || name.hasPrefix("ATM")) {
            isAtmDevice = true
        }
        
        // If an authenticated 6-digit ATM code was discovered or ATM peripheral identified
        if isAtmDevice {
            if let code = foundCode {
                detectedAtmCode = code
            }
            detectedAtmName = name.isEmpty ? "Банкомат RoPay" : name
            isAtmNearby = true
            
            // Strict proximity requirement: very close to tablet (<= 15cm is RSSI >= -58 dBm)
            if rssiValue >= -58 {
                isVeryClose = true
                proximityText = "Банкомат рядом! (\(rssiValue) dBm)"
                if !hasTriggeredHaptic {
                    hasTriggeredHaptic = true
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                }
            } else {
                isVeryClose = false
                hasTriggeredHaptic = false
                proximityText = "Поднесите iPhone вплотную к экрану (\(rssiValue) dBm)"
            }
        }
    }
}
