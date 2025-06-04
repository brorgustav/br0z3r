import Foundation
#if os(macOS)
import ORSSerial
#endif

public class SerialManager: NSObject, ObservableObject, ORSSerialPortDelegate {
    override public init() {
        let savedBaudRate = UserDefaults.standard.integer(forKey: "SelectedBaudRate")
        self.selectedBaudRate = (savedBaudRate == 0) ? 115200 : savedBaudRate
        super.init()
    }
    @Published public var selectedPortPath: String = ""
    @Published public var selectedBaudRate: Int {
        didSet {
            UserDefaults.standard.set(selectedBaudRate, forKey: "SelectedBaudRate")
        }
    }
    @Published public var availablePorts: [ORSSerialPort] = ORSSerialPortManager.shared().availablePorts
    
    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
    
    }
    public func refreshPorts() {
        availablePorts = ORSSerialPortManager.shared().availablePorts
    }
    
    @MainActor public static let shared = SerialManager()
    private var serialPort: ORSSerialPort?
    
    public func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("Serial port error: \(error.localizedDescription)")
    }
    public func connect(to path: String, baudRate: Int) {
        guard let port = ORSSerialPort(path: path) else { return }
        serialPort = port
        port.baudRate = NSNumber(value: baudRate)
        port.delegate = self
        port.open()
    }

    public func disconnect() {
        serialPort?.close()
        serialPort = nil
    }

    public func send(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        serialPort?.send(data)
    }

    public func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        if let receivedString = String(data: data, encoding: .utf8) {
            print("Received: \(receivedString)")
            // Handle received data
        }
    }

    public func serialPortWasRemoved(fromSystem serialPort: ORSSerialPort) {
        disconnect()
    }

    public func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print("Serial port closed.")
    }
}
