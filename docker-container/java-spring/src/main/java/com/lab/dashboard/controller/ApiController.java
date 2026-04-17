package com.lab.dashboard.controller;

import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryUsage;
import java.lang.management.ThreadMXBean;
import java.net.InetAddress;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import oshi.SystemInfo;
import oshi.hardware.CentralProcessor;
import oshi.hardware.GlobalMemory;
import oshi.hardware.HWDiskStore;
import oshi.hardware.HardwareAbstractionLayer;
import oshi.hardware.NetworkIF;
import oshi.software.os.OperatingSystem;

@RestController
@RequestMapping("/api")
public class ApiController {

    private final SystemInfo systemInfo = new SystemInfo();
    private final long startTimeMs = System.currentTimeMillis();

    // -----------------------------------------------------------------------
    // Static info — called once at frontend load
    // -----------------------------------------------------------------------
    @GetMapping("/info")
    public Map<String, Object> info() {
        HardwareAbstractionLayer hw = systemInfo.getHardware();
        OperatingSystem os = systemInfo.getOperatingSystem();
        CentralProcessor cpu = hw.getProcessor();
        GlobalMemory mem = hw.getMemory();

        Map<String, Object> result = new LinkedHashMap<>();

        // JVM / container
        Map<String, Object> container = new LinkedHashMap<>();
        try {
            container.put("hostname", InetAddress.getLocalHost().getHostName());
        } catch (Exception e) {
            container.put("hostname", System.getenv().getOrDefault("HOSTNAME", "unknown"));
        }
        container.put("javaVersion", System.getProperty("java.version"));
        container.put("javaVendor", System.getProperty("java.vendor"));
        container.put("jvmName", System.getProperty("java.vm.name"));
        container.put("pid", ProcessHandle.current().pid());
        container.put("startTime", new Date(startTimeMs).toString());
        container.put("springProfile",
                System.getProperty("spring.profiles.active", "default"));
        container.put("port",
                System.getProperty("server.port", "8080"));
        result.put("container", container);

        // OS
        Map<String, Object> osInfo = new LinkedHashMap<>();
        osInfo.put("family", os.getFamily());
        osInfo.put("version", os.getVersionInfo().toString());
        osInfo.put("arch", System.getProperty("os.arch", "unknown"));
        osInfo.put("availableProcessors", Runtime.getRuntime().availableProcessors());
        result.put("os", osInfo);

        // CPU
        Map<String, Object> cpuInfo = new LinkedHashMap<>();
        cpuInfo.put("name", cpu.getProcessorIdentifier().getName());
        cpuInfo.put("physicalCores", cpu.getPhysicalProcessorCount());
        cpuInfo.put("logicalCores", cpu.getLogicalProcessorCount());
        result.put("cpu", cpuInfo);

        // System memory
        Map<String, Object> memInfo = new LinkedHashMap<>();
        memInfo.put("total", mem.getTotal());
        memInfo.put("pageSize", mem.getPageSize());
        result.put("memory", memInfo);

        // JVM memory bounds
        MemoryUsage heap = ManagementFactory.getMemoryMXBean().getHeapMemoryUsage();
        MemoryUsage nonHeap = ManagementFactory.getMemoryMXBean().getNonHeapMemoryUsage();
        Map<String, Object> jvmInfo = new LinkedHashMap<>();
        jvmInfo.put("heapMax", heap.getMax() > 0 ? heap.getMax() : heap.getCommitted());
        jvmInfo.put("heapInit", heap.getInit());
        jvmInfo.put("nonHeapInit", nonHeap.getInit());
        // GC names
        List<String> gcNames = ManagementFactory.getGarbageCollectorMXBeans()
                .stream().map(GarbageCollectorMXBean::getName).toList();
        jvmInfo.put("gcCollectors", gcNames);
        result.put("jvm", jvmInfo);

        return result;
    }

    // -----------------------------------------------------------------------
    // Live metrics — polled every 3s by the frontend
    // -----------------------------------------------------------------------
    @GetMapping("/metrics")
    public Map<String, Object> metrics() {
        HardwareAbstractionLayer hw = systemInfo.getHardware();
        OperatingSystem os = systemInfo.getOperatingSystem();
        CentralProcessor cpu = hw.getProcessor();
        GlobalMemory mem = hw.getMemory();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("timestamp", System.currentTimeMillis());
        result.put("uptime", (System.currentTimeMillis() - startTimeMs) / 1000.0);

        // CPU (200 ms sampling window)
        double cpuLoad = cpu.getSystemCpuLoad(200) * 100.0;
        double[] loadAvg = cpu.getSystemLoadAverage(3);
        Map<String, Object> cpuMetrics = new LinkedHashMap<>();
        cpuMetrics.put("load", round2(Math.max(0, cpuLoad)));
        cpuMetrics.put("loadAvg1", loadAvg[0] >= 0 ? round2(loadAvg[0]) : null);
        cpuMetrics.put("loadAvg5", loadAvg[1] >= 0 ? round2(loadAvg[1]) : null);
        cpuMetrics.put("loadAvg15", loadAvg[2] >= 0 ? round2(loadAvg[2]) : null);
        result.put("cpu", cpuMetrics);

        // System memory
        long memTotal = mem.getTotal();
        long memAvail = mem.getAvailable();
        long memUsed = memTotal - memAvail;
        Map<String, Object> memMetrics = new LinkedHashMap<>();
        memMetrics.put("total", memTotal);
        memMetrics.put("used", memUsed);
        memMetrics.put("available", memAvail);
        memMetrics.put("usedPercent", round2((double) memUsed / memTotal * 100.0));
        result.put("memory", memMetrics);

        // JVM heap + non-heap
        MemoryUsage heapUsage = ManagementFactory.getMemoryMXBean().getHeapMemoryUsage();
        MemoryUsage nonHeapUsage = ManagementFactory.getMemoryMXBean().getNonHeapMemoryUsage();
        long heapMax = heapUsage.getMax() > 0 ? heapUsage.getMax() : heapUsage.getCommitted();
        Map<String, Object> jvmMem = new LinkedHashMap<>();
        jvmMem.put("heapUsed", heapUsage.getUsed());
        jvmMem.put("heapCommitted", heapUsage.getCommitted());
        jvmMem.put("heapMax", heapMax);
        jvmMem.put("heapPercent", round2((double) heapUsage.getUsed() / heapMax * 100.0));
        jvmMem.put("nonHeapUsed", nonHeapUsage.getUsed());
        jvmMem.put("nonHeapCommitted", nonHeapUsage.getCommitted());
        result.put("jvmMemory", jvmMem);

        // Threads
        ThreadMXBean threadBean = ManagementFactory.getThreadMXBean();
        Map<String, Object> threads = new LinkedHashMap<>();
        threads.put("count", threadBean.getThreadCount());
        threads.put("daemon", threadBean.getDaemonThreadCount());
        threads.put("peak", threadBean.getPeakThreadCount());
        threads.put("totalStarted", threadBean.getTotalStartedThreadCount());
        result.put("threads", threads);

        // GC
        long gcCount = 0, gcTimeMs = 0;
        for (GarbageCollectorMXBean gc : ManagementFactory.getGarbageCollectorMXBeans()) {
            if (gc.getCollectionCount() > 0) gcCount += gc.getCollectionCount();
            if (gc.getCollectionTime() > 0) gcTimeMs += gc.getCollectionTime();
        }
        Map<String, Object> gcMetrics = new LinkedHashMap<>();
        gcMetrics.put("collections", gcCount);
        gcMetrics.put("timeMs", gcTimeMs);
        result.put("gc", gcMetrics);

        // Processes
        Map<String, Object> procs = new LinkedHashMap<>();
        procs.put("total", os.getProcessCount());
        procs.put("threads", os.getThreadCount());
        result.put("processes", procs);

        // Network (first active interface, cumulative bytes for rate calc in frontend)
        List<NetworkIF> nets = hw.getNetworkIFs(false);
        if (!nets.isEmpty()) {
            NetworkIF net = nets.get(0);
            net.updateAttributes();
            Map<String, Object> netMetrics = new LinkedHashMap<>();
            netMetrics.put("name", net.getName());
            netMetrics.put("rxBytes", net.getBytesRecv());
            netMetrics.put("txBytes", net.getBytesSent());
            netMetrics.put("rxPackets", net.getPacketsRecv());
            netMetrics.put("txPackets", net.getPacketsSent());
            result.put("network", netMetrics);
        }

        // Disk (first disk store, cumulative for rate calc in frontend)
        List<HWDiskStore> disks = hw.getDiskStores();
        if (!disks.isEmpty()) {
            HWDiskStore disk = disks.get(0);
            disk.updateAttributes();
            Map<String, Object> diskMetrics = new LinkedHashMap<>();
            diskMetrics.put("name", disk.getName());
            diskMetrics.put("readBytes", disk.getReadBytes());
            diskMetrics.put("writeBytes", disk.getWriteBytes());
            diskMetrics.put("reads", disk.getReads());
            diskMetrics.put("writes", disk.getWrites());
            result.put("disk", diskMetrics);
        }

        return result;
    }

    private static double round2(double v) {
        return Math.round(v * 100.0) / 100.0;
    }
}
