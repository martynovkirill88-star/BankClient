import Foundation
import CoreBluetooth
import UIKit
import Combine

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    static let shared = BluetoothManager()
    
    // Custom ATM Service UUID
    static let atmServiceUUID = CBUUID(string: "0000FFF0-0000-1000-8000-00805F9B34FB")
    
    @Published var isBluetoothEnabled: Bool = false
    @Published var isScanning: Bool = false
    @Published var isAdvertising: Bool = false
    @Published var isAtmNearby: Bool = false
    @Published var isVeryClose: Bool = false
    @Published var detectedAtmCode: String? = nil
    @Published var detectedAtmName: String = ""
    @Published var currentRssi: Int = -100
    @Published var proximityText: String = "Поиск банкомата..."
    @Published var lastPacketTime: Date? = nil
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var currentUserIdToAdvertise: Int? = nil
    private var hasTriggeredHaptic: Bool = false
    private var lastRestartTime: Date = Date()
    
    override init() {
        super.init()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupCentralManager()
            self.setupPeripheralManager()
        }
    }
    
    private func setupCentralManager() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }
    
    private func setupPeripheralManager() {
        guard peripheralManager == nil else { return }
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }
    
    // MARK: - BLE Beacon Advertising (iPhone -> Tablet)
    func startAdvertising(userId: Int) {
        currentUserIdToAdvertise = userId
        if peripheralManager == nil {
            setupPeripheralManager()
        } else if peripheralManager?.state == .poweredOn {
            actuallyStartAdvertising(userId: userId)
        }
    }
    
    private func actuallyStartAdvertising(userId: Int) {
        guard peripheralManager?.state == .poweredOn else { return }
        let advData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [BluetoothManager.atmServiceUUID],
            CBAdvertisementDataLocalNameKey: "RoPay-Client-\(userId)"
        ]
        peripheralManager?.stopAdvertising()
        peripheralManager?.startAdvertising(advData)
        isAdvertising = true
    }
    
    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
    }
    
    // MARK: - BLE Scanning (Tablet -> iPhone)
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
        proximityText = "Поиск банкомата RoPay..."
        
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }
    
    func restartScanIfNeeded() {
        guard centralManager?.state == .poweredOn else { return }
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
    
    func checkLiveness() {
        if let last = lastPacketTime, Date().timeIntervalSince(last) > 2.2 {
            isAtmNearby = false
            isVeryClose = false
            currentRssi = -100
            hasTriggeredHaptic = false
            proximityText = "Поиск банкомата RoPay..."
        }
    }
    
    func setServerActiveCode(_ code: String?) {
        if let code = code, isValidAtmCode(code) {
            detectedAtmCode = code
        } else if code == nil && !isAtmNearby {
            detectedAtmCode = nil
        }
    }
    
    func resetDetection() {
        isAtmNearby = false
        isVeryClose = false
        detectedAtmCode = nil
        detectedAtmName = ""
        currentRssi = -100
        lastPacketTime = nil
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
    
    // MARK: - CBPeripheralManagerDelegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            if let uid = currentUserIdToAdvertise {
                actuallyStartAdvertising(userId: uid)
            }
        }
    }
    
    private func isValidAtmCode(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return trimmed.count == 6 && trimmed.allSatisfy { $0.isNumber }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue
        currentRssi = rssiValue
        
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        var foundCode: String? = nil
        
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
        
        if isAtmDevice {
            lastPacketTime = Date()
            if let code = foundCode {
                detectedAtmCode = code
            }
            detectedAtmName = name.isEmpty ? "Банкомат RoPay" : name
            
            // PROXIMITY CALIBRATION:
            // Direct touch / in front of screen: RSSI is -50 dBm to -62 dBm (threshold >= -64 dBm)
            if rssiValue >= -64 {
                isVeryClose = true
                isAtmNearby = true
                proximityText = "Банкомат вплотную (\(rssiValue) dBm) — нажмите для входа"
                if !hasTriggeredHaptic {
                    hasTriggeredHaptic = true
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                }
            } else if rssiValue >= -74 {
                isVeryClose = false
                isAtmNearby = true
                hasTriggeredHaptic = false
                proximityText = "Банкомат рядом (\(rssiValue) dBm). Подойдите вплотную!"
            } else {
                isVeryClose = false
                isAtmNearby = false
                hasTriggeredHaptic = false
                proximityText = "Слишком далеко (\(rssiValue) dBm). Подойдите к экрану"
            }
        }
    }
}
