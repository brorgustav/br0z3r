import SwiftUI


struct ContentView: View {
    @State private var inputText = ""

    #if os(macOS)
    @ObservedObject private var serialManager = SerialManager.shared
    private let baudRates = [9600, 19200, 38400, 57600, 115200]
    #else
    @StateObject private var bleManager = BLEManager()
    #endif

    var body: some View {
        VStack(spacing: 20) {
            #if os(macOS)
            Text("macOS UART")
                .font(.headline)

            HStack {
                Picker("Port", selection: $serialManager.selectedPortPath) {
                    ForEach(serialManager.availablePorts, id: \.path) { port in
                        Text(port.name).tag(port.path)
                    }
                }
                Picker("Baud", selection: $serialManager.selectedBaudRate) {
                    ForEach(baudRates, id: \.self) { rate in
                        Text(String(format: "%d", rate)).tag(rate)
                    }
                }
                Button("Connect") {
                    serialManager.connect(to: serialManager.selectedPortPath, baudRate: serialManager.selectedBaudRate)
                }
                Button("Disconnect") {
                    serialManager.disconnect()
                }
            }

            TextField("Enter command", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Send") {
                SerialManager.shared.send(inputText)
                inputText = ""
            }
            .padding()

            #else
            Text("iOS BLE UART")
                .font(.headline)

            List(bleManager.discoveredDevices, id: \.identifier) { peripheral in
                Button(peripheral.name ?? "Unnamed") {
                    bleManager.connect(to: peripheral)
                }
            }

            TextField("Enter command", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Send via BLE") {
                bleManager.send(inputText)
                inputText = ""
            }
            .padding()

            ScrollView {
                Text(bleManager.receivedText)
                    .padding()
            }
            .frame(height: 150)
            #endif
        }
        .padding()
        .onAppear {
            #if os(macOS)
            serialManager.refreshPorts()
            #else
            bleManager.startScan()
            #endif
        }
        .onDisappear {
            #if os(macOS)
            serialManager.disconnect()
            #endif
        }
    }
}
