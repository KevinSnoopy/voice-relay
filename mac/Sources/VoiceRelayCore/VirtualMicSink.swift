import Foundation
import AudioToolbox
import CoreAudio

/// Writes 16 kHz mono float audio to a virtual output device (BlackHole / SayAll style).
/// The input method listening on that device does recognition and inserts text itself.
public final class VirtualMicSink {
    public struct Device: Equatable {
        public let id: AudioDeviceID
        public let name: String
    }

    public enum SinkError: Error, CustomStringConvertible {
        case deviceNotFound
        case componentMissing
        case audioUnit(String)

        public var description: String {
            switch self {
            case .deviceNotFound: return "没有找到虚拟声卡"
            case .componentMissing: return "系统没有 HAL 输出组件"
            case .audioUnit(let detail): return "虚拟声卡启动失败：\(detail)"
            }
        }
    }

    public static let preferredNames = ["BlackHole 2ch", "BlackHole", "SayAll", "VoiceRelay"]

    public private(set) var deviceName = ""
    public private(set) var isRunning = false
    private var unit: AudioUnit?
    private var ring: [Float] = []
    private let lock = NSLock()
    private let sampleRate: Double = 16000

    public init() {}

    public static func availableDevices() -> [Device] {
        allDeviceIDs().compactMap { id in
            let name = deviceName(id)
            guard !name.isEmpty else { return nil }
            return Device(id: id, name: name)
        }
    }

    public static func findPreferredDevice(containing preferred: String? = nil) -> Device? {
        let devices = availableDevices()
        if let preferred, !preferred.isEmpty,
           let match = devices.first(where: { $0.name.localizedCaseInsensitiveContains(preferred) }) {
            return match
        }
        for name in preferredNames {
            if let match = devices.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
                return match
            }
        }
        return nil
    }

    public func start(device: Device) throws {
        stop()
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let component = AudioComponentFindNext(nil, &description) else {
            throw SinkError.componentMissing
        }
        var instance: AudioUnit?
        guard AudioComponentInstanceNew(component, &instance) == noErr, let instance else {
            throw SinkError.audioUnit("AudioComponentInstanceNew")
        }

        var deviceID = device.id
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let deviceStatus = AudioUnitSetProperty(
            instance,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            size
        )
        guard deviceStatus == noErr else {
            AudioComponentInstanceDispose(instance)
            throw SinkError.audioUnit("设置输出设备 \(device.name)")
        }

        var format = AudioStreamBasicDescription(
            mSampleRate: 16000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let formatStatus = AudioUnitSetProperty(
            instance,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &format,
            size
        )
        guard formatStatus == noErr else {
            AudioComponentInstanceDispose(instance)
            throw SinkError.audioUnit("设置 16 kHz 单声道格式")
        }

        var callback = AURenderCallbackStruct(
            inputProc: virtualMicRenderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        let callbackStatus = AudioUnitSetProperty(
            instance,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0,
            &callback,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )
        guard callbackStatus == noErr else {
            AudioComponentInstanceDispose(instance)
            throw SinkError.audioUnit("设置渲染回调")
        }

        guard AudioUnitInitialize(instance) == noErr else {
            AudioComponentInstanceDispose(instance)
            throw SinkError.audioUnit("AudioUnitInitialize")
        }
        guard AudioOutputUnitStart(instance) == noErr else {
            AudioUnitUninitialize(instance)
            AudioComponentInstanceDispose(instance)
            throw SinkError.audioUnit("AudioOutputUnitStart")
        }

        self.unit = instance
        deviceName = device.name
        isRunning = true
        lock.lock()
        ring.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    public func write(_ samples: [Float]) {
        guard isRunning, !samples.isEmpty else { return }
        lock.lock()
        ring.append(contentsOf: samples)
        let capacity = Int(sampleRate * 2)
        if ring.count > capacity {
            ring.removeFirst(ring.count - capacity)
        }
        lock.unlock()
    }

    public func stop() {
        if let unit {
            AudioOutputUnitStop(unit)
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
        }
        unit = nil
        isRunning = false
        deviceName = ""
        lock.lock()
        ring.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    fileprivate func render(frameCount: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
        guard let ioData else { return noErr }
        let buffers = UnsafeMutableAudioBufferListPointer(ioData)
        guard let first = buffers.first, let data = first.mData else { return noErr }
        let pointer = data.assumingMemoryBound(to: Float.self)
        let count = Int(frameCount)
        lock.lock()
        let available = min(count, ring.count)
        if available > 0 {
            for index in 0..<available { pointer[index] = ring[index] }
            ring.removeFirst(available)
        }
        if available < count {
            for index in available..<count { pointer[index] = 0 }
        }
        lock.unlock()
        return noErr
    }

    // MARK: - CoreAudio helpers

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: count)
        var dataSize = size
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids
        ) == noErr else { return [] }
        return ids
    }

    private static func deviceName(_ device: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? (value as String) : ""
    }
}

private func virtualMicRenderCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let sink = Unmanaged<VirtualMicSink>.fromOpaque(inRefCon).takeUnretainedValue()
    return sink.render(frameCount: inNumberFrames, ioData: ioData)
}
