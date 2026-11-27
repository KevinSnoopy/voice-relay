import Foundation
import CoreBluetooth
import Network

public enum BLESpec {
    public static let service = CBUUID(string: "7A1F0001-6C3A-4B7E-9E2A-9B5C1D2E3F40")
    public static let rx = CBUUID(string: "7A1F0002-6C3A-4B7E-9E2A-9B5C1D2E3F40")
    public static let tx = CBUUID(string: "7A1F0003-6C3A-4B7E-9E2A-9B5C1D2E3F40")
}

/// BLE GATT peripheral that bridges phone frames into the existing TCP protocol stack
/// over loopback. Authentication, ASR and injection stay exactly the same as Wi-Fi.
public final class BLEBridge: NSObject {
    public enum Status: Equatable {
        case off
        case starting
        case advertising
        case connected(String)
        case failed(String)

        public var label: String {
            switch self {
            case .off: return "未开启"
            case .starting: return "正在启动"
            case .advertising: return "可被发现"
            case .connected: return "手机已订阅 · 待认证"
            case .failed(let reason): return reason
            }
        }
    }

    public private(set) var status: Status = .off
    public var onStatus: ((Status) -> Void)?
    public var onLog: ((String) -> Void)?

    private let port: Int
    private let queue = DispatchQueue(label: "com.voicerelay.ble")
    private var manager: CBPeripheralManager?
    private var service: CBMutableService?
    private var rxChar: CBMutableCharacteristic?
    private var txChar: CBMutableCharacteristic?
    private var central: CBCentral?
    private var subscribed = false
    private var started = false

    private var tcp: NWConnection?
    private var tcpReady = false
    private var toTCP = Data()
    private var toBLE = Data()

    public init(port: Int) {
        self.port = port
        super.init()
    }

    public func start() {
        queue.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            self.setStatus(.starting)
            self.manager = CBPeripheralManager(
                delegate: self,
                queue: self.queue,
                options: [CBPeripheralManagerOptionShowPowerAlertKey: true]
            )
        }
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.started = false
            self.manager?.stopAdvertising()
            self.manager?.removeAllServices()
            self.manager = nil
            self.service = nil
            self.rxChar = nil
            self.txChar = nil
            self.central = nil
            self.subscribed = false
            self.closeTCP()
            self.toTCP.removeAll()
            self.toBLE.removeAll()
            self.setStatus(.off)
        }
    }

    private func setStatus(_ value: Status) {
        status = value
        let callback = onStatus
        DispatchQueue.main.async { callback?(value) }
    }

    private func log(_ text: String) {
        onLog?(text)
    }

    // MARK: - GATT setup

    private func setUpService() {
        guard let manager else { return }
        let service = CBMutableService(type: BLESpec.service, primary: true)
        let rx = CBMutableCharacteristic(
            type: BLESpec.rx,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        let tx = CBMutableCharacteristic(
            type: BLESpec.tx,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )
        service.characteristics = [rx, tx]
        self.service = service
        rxChar = rx
        txChar = tx
        manager.add(service)
    }

    private func startAdvertising() {
        guard let manager else { return }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BLESpec.service],
            CBAdvertisementDataLocalNameKey: "VoiceRelay",
        ])
        setStatus(.advertising)
        log("BLE 广播已开始")
    }

    // MARK: - Loopback TCP

    private func connectTCP() {
        guard tcp == nil, let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return }
        let connection = NWConnection(host: .ipv4(.loopback), port: nwPort, using: .tcp)
        tcp = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.tcpReady = true
                self.flushToTCP()
                self.receiveTCP()
            case .failed(let error):
                self.log("BLE 回环 TCP 失败: \(error)")
                self.closeTCP()
            case .cancelled:
                self.closeTCP()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receiveTCP() {
        guard let tcp else { return }
        tcp.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.enqueueToBLE(data)
            }
            if isComplete || error != nil {
                self.closeTCP()
                return
            }
            self.receiveTCP()
        }
    }

    private func closeTCP() {
        tcp?.cancel()
        tcp = nil
        tcpReady = false
    }

    private func appendToTCP(_ data: Data) {
        toTCP.append(data)
        if toTCP.count > 256 * 1024 {
            toTCP.removeFirst(toTCP.count - 256 * 1024)
        }
        if tcp == nil { connectTCP() }
        flushToTCP()
    }

    private func flushToTCP() {
        guard tcpReady, let tcp, !toTCP.isEmpty else { return }
        let payload = toTCP
        toTCP.removeAll(keepingCapacity: true)
        tcp.send(content: payload, completion: .contentProcessed { [weak self] error in
            guard let self, error != nil else { return }
            self.queue.async {
                self.toTCP.insert(contentsOf: payload, at: 0)
                if self.toTCP.count > 512 * 1024 {
                    self.toTCP.removeFirst(self.toTCP.count - 512 * 1024)
                }
            }
        })
    }

    // MARK: - BLE notifications

    private func enqueueToBLE(_ data: Data) {
        toBLE.append(data)
        if toBLE.count > 512 * 1024 {
            toBLE.removeFirst(toBLE.count - 512 * 1024)
        }
        flushToBLE()
    }

    private func flushToBLE() {
        guard subscribed, let central, let txChar, let manager else { return }
        let mtu = max(20, central.maximumUpdateValueLength - 3)
        while !toBLE.isEmpty {
            let count = min(mtu, toBLE.count)
            let chunk = Data(toBLE.prefix(count))
            let accepted = manager.updateValue(chunk, for: txChar, onSubscribedCentrals: [central])
            if !accepted { break }
            toBLE.removeFirst(count)
        }
    }
}

extension BLEBridge: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            setUpService()
        case .poweredOff:
            setStatus(.off)
            log("蓝牙已关闭")
        case .unauthorized:
            setStatus(.failed("蓝牙未授权"))
        case .unsupported:
            setStatus(.failed("这台 Mac 不支持 BLE 外设"))
        default:
            break
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            setStatus(.failed("BLE 服务启动失败：\(error.localizedDescription)"))
            return
        }
        startAdvertising()
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let value = request.value, !value.isEmpty {
                appendToTCP(value)
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        self.central = central
        subscribed = true
        setStatus(.connected(String(central.identifier.uuidString.prefix(8))))
        connectTCP()
        flushToBLE()
        log("BLE 手机已订阅")
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        self.central = nil
        subscribed = false
        toBLE.removeAll()
        closeTCP()
        setStatus(.advertising)
        log("BLE 手机已断开")
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flushToBLE()
    }
}
