//
//  BLEManager.swift
//  br0z3r
//
//  Created by BGW on 2025-06-04.
//


//
//  BLEManager.swift
//  broser
//
//  Created by BGW on 2025-06-03.
//

import Foundation
import CoreBluetooth
import Combine

@MainActor
public class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: – UUIDs for the UART service & characteristics
    private let uartServiceUUID      = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    // MARK: – CoreBluetooth properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?

    // MARK: – Published state for SwiftUI
    @Published public var discoveredDevices: [CBPeripheral] = []
    @Published public var receivedText: String = ""

    public override init() {
        super.init()
        // Initialize the central manager on the main run loop
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: – Public API

    /// Begin scanning for UART peripherals
    public func startScan() {
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: [uartServiceUUID], options: nil)
    }

    /// Connect to a selected peripheral
    public func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    /// Send a UTF-8 string to the peripheral, chunked by MTU size
    public func send(_ message: String) {
        guard
            let data = message.data(using: .utf8),
            let char = writeCharacteristic,
            let peripheral = connectedPeripheral
        else { return }

        // Split into pieces no larger than MTU
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        var offset = 0
        while offset < data.count {
            let chunkSize = min(mtu, data.count - offset)
            let chunk = data.subdata(in: offset..<offset + chunkSize)
            peripheral.writeValue(chunk, for: char, type: .withoutResponse)
            offset += chunkSize
        }
    }

    // MARK: – CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScan()
        } else {
            print("❌ Bluetooth not available / powered off")
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        // Add newly found peripherals to the published array (if not already present)
        if !discoveredDevices.contains(peripheral) {
            discoveredDevices.append(peripheral)
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([uartServiceUUID])
    }

    public func centralManager(_ central: CBCentralManager,
                               didFailToConnect peripheral: CBPeripheral,
                               error: Error?) {
        // Remove failed peripheral from the list
        if let idx = discoveredDevices.firstIndex(of: peripheral) {
            discoveredDevices.remove(at: idx)
        }
        print("❌ Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "No error info")")
    }

    public func centralManager(_ central: CBCentralManager,
                               didDisconnectPeripheral peripheral: CBPeripheral,
                               error: Error?) {
        // Remove on disconnect and clear state
        if let idx = discoveredDevices.firstIndex(of: peripheral) {
            discoveredDevices.remove(at: idx)
        }
        if connectedPeripheral == peripheral {
            connectedPeripheral = nil
            writeCharacteristic = nil
        }
        print("🔌 Disconnected from peripheral \(peripheral.name ?? "Unknown")")
    }

    // MARK: – CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == uartServiceUUID {
                peripheral.discoverCharacteristics([txCharacteristicUUID, rxCharacteristicUUID], for: service)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didDiscoverCharacteristicsFor service: CBService,
                           error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            // Identify the RX (write) characteristic
            if char.uuid == rxCharacteristicUUID {
                writeCharacteristic = char
            }
            // Identify the TX (notify) characteristic
            if char.uuid == txCharacteristicUUID {
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateValueFor characteristic: CBCharacteristic,
                           error: Error?) {
        guard
            let data = characteristic.value,
            let string = String(data: data, encoding: .utf8)
        else { return }

        // Append to the published text
        Task { @MainActor in
            self.receivedText += string
        }
    }
}
