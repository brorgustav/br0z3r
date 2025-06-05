//
//  ContentView.swift
//  br0z3r
//
//  Created by BGW on 2025-06-05.
//

import SwiftUI
import ORSSerial         // macOS USB-UART support
import CoreBluetooth     // macOS & iOS BLE-UART support

struct ContentView: View {
    #if os(macOS)
    // ───────────────────────────────────────────────────────
    // macOS branch: USB-UART via ORSSerialPort + BLE-UART via CoreBluetooth
    // ───────────────────────────────────────────────────────
    @StateObject var serialManager = SerialManager.shared
    @State private var inputText: String = ""
    @State private var showDisconnectConfirmation = false
    private let baudRates = [9600, 19200, 38400, 57600, 115200]

    // BLE on macOS
    @StateObject var bleManager = BLEManager()
    @State private var bleInputText: String = ""
    @State private var showBleDisconnectConfirmation = false

    var body: some View {
        TabView {
            // ── Settings Tab ─────────────────────────────────────
            VStack(spacing: 16) {
                Text("Serial Settings")
                    .font(.headline)

                // Port picker (refreshes on tap)
                HStack {
                    Picker("Port", selection: $serialManager.selectedPortPath) {
                        ForEach(serialManager.availablePorts, id: \.path) { port in
                            Text(port.name).tag(port.path)
                        }
                    }
                    .frame(width: 200)
                    .onTapGesture {
                        serialManager.refreshPorts()
                    }

                    // Baud-rate picker
                    Picker("Baud", selection: $serialManager.selectedBaudRate) {
                        ForEach(baudRates, id: \.self) { rate in
                            Text(String(rate)).tag(rate)
                        }
                    }
                    .frame(width: 100)
                }
                .padding(.horizontal)

                // Connect / Disconnect with confirmation
                Button(serialManager.isConnected ? "Disconnect" : "Connect") {
                    if serialManager.isConnected {
                        showDisconnectConfirmation = true
                    } else {
                        serialManager.connect(
                            to: serialManager.selectedPortPath,
                            baudRate: serialManager.selectedBaudRate
                        )
                    }
                }
                .alert(isPresented: $showDisconnectConfirmation) {
                    Alert(
                        title: Text("Disconnect"),
                        message: Text("Are you sure you want to disconnect?"),
                        primaryButton: .destructive(Text("Disconnect")) {
                            serialManager.disconnect()
                        },
                        secondaryButton: .cancel()
                    )
                }
                .padding()

                Spacer()
            }
            .padding()
            .tabItem {
                Text("Settings")
            }

            // ── Monitor Tab ──────────────────────────────────────
            VStack(spacing: 16) {
                Text("Serial Monitor")
                    .font(.headline)

                // Send Text
                HStack {
                    TextField("Enter command", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            guard serialManager.isConnected, !inputText.isEmpty else { return }
                            serialManager.send(inputText + "\n")
                            inputText = ""
                        }
                    Button("Send") {
                        serialManager.send(inputText + "\n")
                        inputText = ""
                    }
                    .disabled(!serialManager.isConnected)
                }
                .padding(.horizontal)

                // Received Data View (Selectable)
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(serialManager.receivedText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("Bottom")
                    }
                    .border(Color.gray, width: 1)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .onChange(of: serialManager.receivedText) { _ in
                        proxy.scrollTo("Bottom", anchor: .bottom)
                    }
                }
                .padding(.horizontal)

                // Status Label
                HStack {
                    Text("Status:")
                    Text(serialManager.isConnected ? "• Connected" : "• Disconnected")
                        .foregroundColor(serialManager.isConnected ? .green : .red)
                }
                .font(.subheadline)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .tabItem {
                Text("Monitor")
            }

            // ── BLE Tab ────────────────────────────────────────────
            VStack(spacing: 16) {
                Text("BLE UART Monitor")
                    .font(.headline)

                // Discovered BLE Devices
                List(bleManager.discoveredDevices, id: \.identifier) { peripheral in
                    Button(action: {
                        bleManager.connect(to: peripheral)
                    }) {
                        Text(peripheral.name ?? "Unnamed Device")
                    }
                }
                .frame(height: 200)

                // Send Text over BLE
                HStack {
                    TextField("Enter BLE command", text: $bleInputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            guard bleManager.isConnected, !bleInputText.isEmpty else { return }
                            bleManager.send(bleInputText + "\n")
                            bleInputText = ""
                        }
                    Button("Send") {
                        bleManager.send(bleInputText + "\n")
                        bleInputText = ""
                    }
                    .disabled(!bleManager.isConnected)
                }
                .padding(.horizontal)

                // Received Data View (Selectable) for BLE
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(bleManager.receivedText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("BottomBLE")
                    }
                    .border(Color.gray, width: 1)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .onChange(of: bleManager.receivedText) { _ in
                        proxy.scrollTo("BottomBLE", anchor: .bottom)
                    }
                }
                .padding(.horizontal)

                // Connect / Disconnect Button with confirmation for BLE
                Button(bleManager.isConnected ? "Disconnect BLE" : "Connect BLE") {
                    if bleManager.isConnected {
                        showBleDisconnectConfirmation = true
                    } else {
                        bleManager.startScan()
                    }
                }
                .alert(isPresented: $showBleDisconnectConfirmation) {
                    Alert(
                        title: Text("Disconnect BLE"),
                        message: Text("Are you sure you want to disconnect BLE?"),
                        primaryButton: .destructive(Text("Disconnect")) {
                            bleManager.disconnect()
                        },
                        secondaryButton: .cancel()
                    )
                }
                .padding()

                // Status Label for BLE
                HStack {
                    Text("BLE Status:")
                    Text(bleManager.isConnected ? "• Connected" : "• Disconnected")
                        .foregroundColor(bleManager.isConnected ? .green : .red)
                }
                .font(.subheadline)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .tabItem {
                Text("BLE")
            }
        }
        .frame(minWidth: 600, minHeight: 600)
        .onAppear {
            serialManager.refreshPorts()
        }
        .onDisappear {
            if serialManager.isConnected {
                serialManager.disconnect()
            }
            if bleManager.isConnected {
                bleManager.disconnect()
            }
        }
    }
    #else
    // ───────────────────────────────────────────────────────
    // iOS branch: BLE-UART via CoreBluetooth
    // ───────────────────────────────────────────────────────
    @StateObject var bleManager = BLEManager()
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("iOS BLE Serial Monitor")
                .font(.headline)

            // ── Discovered BLE Devices ───────────────────────────
            List(bleManager.discoveredDevices, id: \.identifier) { peripheral in
                Button(action: {
                    bleManager.connect(to: peripheral)
                }) {
                    Text(peripheral.name ?? "Unnamed Device")
                }
            }
            .frame(height: 200)

            // ── Send Text ────────────────────────────────────────
            HStack {
                TextField("Enter command", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        guard bleManager.isConnected, !inputText.isEmpty else { return }
                        bleManager.send(inputText + "\n")
                        inputText = ""
                    }
                Button("Send") {
                    bleManager.send(inputText + "\n")
                    inputText = ""
                }
                .disabled(!bleManager.isConnected)
            }
            .padding(.horizontal)

            // ── Received Data View (Selectable) ────────────────────
            ScrollViewReader { proxy in
                ScrollView {
                    Text(bleManager.receivedText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("BottomBLE")
                }
                .border(Color.gray, width: 1)
                .frame(maxWidth: .infinity, minHeight: 200)
                .onChange(of: bleManager.receivedText) { _ in
                    proxy.scrollTo("BottomBLE", anchor: .bottom)
                }
            }
            .padding(.horizontal)

            // ── Status Label ──────────────────────────────────────
            HStack {
                Text("Status:")
                Text(bleManager.isConnected ? "• Connected" : "• Disconnected")
                    .foregroundColor(bleManager.isConnected ? .green : .red)
            }
            .font(.subheadline)
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            bleManager.startScan()
        }
        .onDisappear {
            if bleManager.isConnected {
                bleManager.disconnect()
            }
        }
    }
    #endif
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
