import Foundation
import Darwin

/// Reads CPU and memory utilization using Mach kernel APIs,
/// matching Activity Monitor's methodology.
final class NativeSystemStats {
    static let shared = NativeSystemStats()

    // Previous CPU ticks for delta calculation
    private var prevUserTicks: UInt64 = 0
    private var prevSystemTicks: UInt64 = 0
    private var prevIdleTicks: UInt64 = 0
    private var prevNiceTicks: UInt64 = 0
    private var hasBaseline = false

    private let hostPort = mach_host_self()

    /// Memory utilization as a percentage (0–100), matching Activity Monitor.
    func memoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let pageSize = Double(vm_kernel_page_size)
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)

        let active      = Double(stats.active_count) * pageSize
        let speculative = Double(stats.speculative_count) * pageSize
        let wired       = Double(stats.wire_count) * pageSize
        let compressor  = Double(stats.compressor_page_count) * pageSize

        let used = active + speculative + wired + compressor
        return min((used / totalBytes) * 100, 100)
    }

    /// CPU utilization as a percentage (0–100), averaged across all cores.
    func cpuUsage() -> Double {
        var numCPU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(hostPort,
                                          PROCESSOR_CPU_LOAD_INFO,
                                          &numCPU,
                                          &cpuInfo,
                                          &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0 }

        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(numCPU) {
            let base = Int(CPU_STATE_MAX) * i
            totalUser   += UInt64(info[base + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            totalIdle   += UInt64(info[base + Int(CPU_STATE_IDLE)])
            totalNice   += UInt64(info[base + Int(CPU_STATE_NICE)])
        }

        if !hasBaseline {
            prevUserTicks = totalUser
            prevSystemTicks = totalSystem
            prevIdleTicks = totalIdle
            prevNiceTicks = totalNice
            hasBaseline = true
            return 0
        }

        let dUser   = Double(totalUser - prevUserTicks)
        let dSystem = Double(totalSystem - prevSystemTicks)
        let dIdle   = Double(totalIdle - prevIdleTicks)
        let dNice   = Double(totalNice - prevNiceTicks)

        prevUserTicks = totalUser
        prevSystemTicks = totalSystem
        prevIdleTicks = totalIdle
        prevNiceTicks = totalNice

        let totalDelta = dUser + dSystem + dIdle + dNice
        guard totalDelta > 0 else { return 0 }

        return min(((dUser + dSystem + dNice) / totalDelta) * 100, 100)
    }
}
