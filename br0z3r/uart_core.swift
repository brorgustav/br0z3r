import Foundation
#if os(macOS)
import ORSSerial
#endif

public class SerialManager: NSObject, ObservableObject, ORSSerialPortDelegate {
    override public init() {
        let savedBaudRate = UserDefaults.standard.integer(forKey: "SelectedBaudRate")
        self.selectedBaudRate = (savedBaudRate == 0) ? 115200 : savedBaudRate
        super.init()
        refreshPorts()
    }

    @Published public var selectedPortPath: String = ""
    @Published public var selectedBaudRate: Int {
        didSet {
            UserDefaults.standard.set(selectedBaudRate, forKey: "SelectedBaudRate")
        }
    }
    @Published public var availablePorts: [ORSSerialPort] = []
    @Published public var isConnected: Bool = false
    @Published public var receivedText: String = ""

    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        disconnect()
        refreshPorts()
    }

    public func refreshPorts() {
        availablePorts = ORSSerialPortManager.shared().availablePorts
        if let first = availablePorts.first {
            selectedPortPath = first.path
        }
    }

    @MainActor public static let shared = SerialManager()
    private var serialPort: ORSSerialPort?

    public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("Serial port error: \(error.localizedDescription)")
        isConnected = false
    }

    public func connect(to path: String, baudRate: Int) {
        disconnect()
        guard let port = ORSSerialPort(path: path) else { return }
        port.baudRate = NSNumber(value: baudRate)
        port.delegate = self
        port.open()
        serialPort = port
        // isConnected = true
    }

    public func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }

    public func disconnect() {
        serialPort?.close()
        serialPort = nil
        isConnected = false
    }

    public func send(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        serialPort?.send(data)
    }

    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        if let receivedString = String(data: data, encoding: .utf8) {
            print("Received: \(receivedString)")
            DispatchQueue.main.async {
                self.receivedText += receivedString
            }
        }
    }

    public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        isConnected = false
        print("Serial port closed.")
    }
}
