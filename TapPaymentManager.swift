import Foundation
import SwiftUI
import CoreBluetooth
import CoreNFC
import LocalAuthentication
import AudioToolbox

// MARK: - Tap-To-Pay & NameDrop Proximity Manager
class TapPaymentManager: NSObject, ObservableObject {
    static let shared = TapPaymentManager()
    
    // CoreBluetooth Service UUID for RoPay POS Terminal
    static let posServiceUUID = CBUUID(string: "A001")
    
    // Published State for UI
    @Published var isMerchantBroadcasting: Bool = false
    @Published var isBuyerScanning: Bool = false
    @Published var isProximityContactDetected: Bool = false
    @Published var currentSessionId: String? = nil
    @Published var statusMessage: String = ""
    @Published var activeTerminalFound: TerminalSession? = nil
    @Published var showFallbackSheet: Bool = false
    
    // Bluetooth Managers
    private var peripheralManager: CBPeripheralManager?
    private var centralManager: CBCentralManager?
    private var contactHitCount: Int = 0
    
    // CoreNFC Session (Official Apple System Sheet)
    private var nfcSession: NFCNDEFReaderSession?
    
    // Callbacks
    private var onContactFound: ((String) -> Void)?
    
    override init() {
        super.init()
    }
    
    // =========================================================================
    // MARK: - MERCHANT MODE (Broadcast POS Terminal)
    // =========================================================================
    
    func startMerchantTerminal(session: TerminalSession) {
        stopAll()
        self.currentSessionId = session.id
        self.isMerchantBroadcasting = true
        self.statusMessage = "Ожидание покупателя: приложите iPhone..."
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func stopMerchantTerminal() {
        peripheralManager?.stopAdvertising()
        peripheralManager = nil
        isMerchantBroadcasting = false
        currentSessionId = nil
    }
    
    // =========================================================================
    // MARK: - BUYER MODE (Official Apple NFC Sheet + BLE Proximity Touch)
    // =========================================================================
    
    func startBuyerTouchSession(onFound: @escaping (String) -> Void) {
        stopAll()
        self.onContactFound = onFound
        self.isBuyerScanning = true
        self.isProximityContactDetected = false
        self.contactHitCount = 0
        self.statusMessage = "Приложите iPhone к терминалу продавца"
        
        // 1. Launch BLE Central to detect touch distance
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // 2. Launch Native Apple NFC System Sheet if available
        if NFCNDEFReaderSession.readingAvailable {
            nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            nfcSession?.alertMessage = "Приложите iPhone верхней частью к терминалу RoPay для оплаты"
            nfcSession?.begin()
        } else {
            // Fallback sheet for devices without NFC reader capability
            showFallbackSheet = true
        }
    }
    
    func handleTouchContact(sessionId: String) {
        guard isBuyerScanning else { return }
        isBuyerScanning = false
        isProximityContactDetected = true
        contactHitCount = 0
        
        // Clean Apple haptic touch feedback
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        AudioServicesPlaySystemSound(1519)
        
        // Update Native Apple NFC Sheet with success checkmark
        if let nfc = nfcSession {
            nfc.alertMessage = "Терминал найден!\nПодтвердите платёж Face ID"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                nfc.invalidate()
            }
        }
        
        showFallbackSheet = false
        centralManager?.stopScan()
        centralManager = nil
        
        // Trigger callback
        onContactFound?(sessionId)
    }
    
    func stopAll() {
        stopMerchantTerminal()
        centralManager?.stopScan()
        centralManager = nil
        nfcSession?.invalidate()
        nfcSession = nil
        isBuyerScanning = false
        showFallbackSheet = false
        contactHitCount = 0
    }
}

// =============================================================================
// MARK: - CBPeripheralManagerDelegate (Merchant Advertising)
// =============================================================================
extension TapPaymentManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn, let sid = currentSessionId {
            let adData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [TapPaymentManager.posServiceUUID],
                CBAdvertisementDataLocalNameKey: "RP-\(sid)"
            ]
            peripheral.startAdvertising(adData)
            print("RoPay POS Advertising started: RP-\(sid)")
        }
    }
}

// =============================================================================
// MARK: - CBCentralManagerDelegate (Buyer Proximity Scanning)
// =============================================================================
extension TapPaymentManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(
                withServices: [TapPaymentManager.posServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let rssiVal = RSSI.intValue
        
        // Strict Physical Touch Threshold:
        // When iPhones touch back-to-back, RSSI is typically -20 to -33 dBm.
        // At even 15-20 cm away, RSSI drops below -42 dBm.
        guard rssiVal >= -33 else {
            contactHitCount = 0
            return
        }
        
        contactHitCount += 1
        guard contactHitCount >= 2 else { return }
        
        let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? (peripheral.name ?? "")
        if localName.hasPrefix("RP-") {
            let sessionId = String(localName.dropFirst(3))
            DispatchQueue.main.async {
                self.handleTouchContact(sessionId: sessionId)
            }
            return
        }
        
        // Instant fallback: if iOS suppressed local name in advertising packet, query active waiting session
        Task {
            if let active = try? await APIService.shared.getLatestActiveTerminal() {
                await MainActor.run {
                    self.handleTouchContact(sessionId: active.id)
                }
            }
        }
    }
}

// =============================================================================
// MARK: - NFCNDEFReaderSessionDelegate (Apple Native Sheet)
// =============================================================================
extension TapPaymentManager: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Tag read fallback if physical NFC tag is used
        for msg in messages {
            for rec in msg.records {
                if let str = String(data: rec.payload, encoding: .utf8), str.contains("pos_") {
                    let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    DispatchQueue.main.async {
                        self.handleTouchContact(sessionId: cleaned)
                    }
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isBuyerScanning = false
        }
    }
}
