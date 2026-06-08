enum BleDiagnosticPhase {
  idle,
  checkingAdapter,
  scanning,
  connecting,
  discoveringServices,
  checkingCharacteristics,
  enablingNotify,
  queryingStatus,
  ready,
  failed,
}

class BleDiagnostics {
  const BleDiagnostics({
    this.bleSupported,
    this.adapterState,
    this.scanInProgress = false,
    this.scanCount = 0,
    this.scanSummary = const [],
    this.selectedDeviceId,
    this.selectedDeviceName,
    this.phase = BleDiagnosticPhase.idle,
    this.targetServiceFound = false,
    this.notifyCharacteristicFound = false,
    this.writeCharacteristicFound = false,
    this.notifyEnabled = false,
    this.lastTxHex,
    this.lastRxHex,
    this.lastError,
    this.updatedAt,
  });

  final bool? bleSupported;
  final String? adapterState;
  final bool scanInProgress;
  final int scanCount;
  final List<String> scanSummary;
  final String? selectedDeviceId;
  final String? selectedDeviceName;
  final BleDiagnosticPhase phase;
  final bool targetServiceFound;
  final bool notifyCharacteristicFound;
  final bool writeCharacteristicFound;
  final bool notifyEnabled;
  final String? lastTxHex;
  final String? lastRxHex;
  final String? lastError;
  final DateTime? updatedAt;

  bool get isProtocolReady =>
      targetServiceFound &&
      notifyCharacteristicFound &&
      writeCharacteristicFound;

  String get phaseLabelZh => switch (phase) {
    BleDiagnosticPhase.idle => '空闲',
    BleDiagnosticPhase.checkingAdapter => '检查蓝牙',
    BleDiagnosticPhase.scanning => '扫描设备',
    BleDiagnosticPhase.connecting => '连接设备',
    BleDiagnosticPhase.discoveringServices => '发现服务',
    BleDiagnosticPhase.checkingCharacteristics => '检查特征',
    BleDiagnosticPhase.enablingNotify => '开启通知',
    BleDiagnosticPhase.queryingStatus => '查询状态',
    BleDiagnosticPhase.ready => '就绪',
    BleDiagnosticPhase.failed => '失败',
  };

  String get phaseLabelEn => switch (phase) {
    BleDiagnosticPhase.idle => 'Idle',
    BleDiagnosticPhase.checkingAdapter => 'Checking adapter',
    BleDiagnosticPhase.scanning => 'Scanning',
    BleDiagnosticPhase.connecting => 'Connecting',
    BleDiagnosticPhase.discoveringServices => 'Discovering services',
    BleDiagnosticPhase.checkingCharacteristics => 'Checking characteristics',
    BleDiagnosticPhase.enablingNotify => 'Enabling notify',
    BleDiagnosticPhase.queryingStatus => 'Querying status',
    BleDiagnosticPhase.ready => 'Ready',
    BleDiagnosticPhase.failed => 'Failed',
  };

  String get failureSummary {
    if (lastError != null && lastError!.isNotEmpty) return lastError!;
    if (phase == BleDiagnosticPhase.failed) return 'Unknown BLE failure';
    return '';
  }

  BleDiagnostics copyWith({
    bool? bleSupported,
    String? adapterState,
    bool? scanInProgress,
    int? scanCount,
    List<String>? scanSummary,
    String? selectedDeviceId,
    String? selectedDeviceName,
    BleDiagnosticPhase? phase,
    bool? targetServiceFound,
    bool? notifyCharacteristicFound,
    bool? writeCharacteristicFound,
    bool? notifyEnabled,
    String? lastTxHex,
    String? lastRxHex,
    String? lastError,
    DateTime? updatedAt,
  }) {
    return BleDiagnostics(
      bleSupported: bleSupported ?? this.bleSupported,
      adapterState: adapterState ?? this.adapterState,
      scanInProgress: scanInProgress ?? this.scanInProgress,
      scanCount: scanCount ?? this.scanCount,
      scanSummary: scanSummary ?? this.scanSummary,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      selectedDeviceName: selectedDeviceName ?? this.selectedDeviceName,
      phase: phase ?? this.phase,
      targetServiceFound: targetServiceFound ?? this.targetServiceFound,
      notifyCharacteristicFound:
          notifyCharacteristicFound ?? this.notifyCharacteristicFound,
      writeCharacteristicFound:
          writeCharacteristicFound ?? this.writeCharacteristicFound,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      lastTxHex: lastTxHex ?? this.lastTxHex,
      lastRxHex: lastRxHex ?? this.lastRxHex,
      lastError: lastError ?? this.lastError,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String exportSnapshot({Iterable<String> debugLog = const []}) {
    final lines = <String>[
      'BLE diagnostics',
      'updated_at=${updatedAt?.toIso8601String() ?? '-'}',
      'phase=${phase.name}',
      'supported=${bleSupported ?? 'unknown'}',
      'adapter=${adapterState ?? 'unknown'}',
      'scan_in_progress=$scanInProgress',
      'scan_count=$scanCount',
      'device=${_formatDevice()}',
      'target=FFF0/FFF1/FFF2',
      'fff0_service=$targetServiceFound',
      'fff1_notify=$notifyCharacteristicFound',
      'fff1_notify_enabled=$notifyEnabled',
      'fff2_write=$writeCharacteristicFound',
      'protocol_ready=$isProtocolReady',
      'last_tx=${lastTxHex ?? '-'}',
      'last_rx=${lastRxHex ?? '-'}',
      'last_error=${lastError ?? '-'}',
    ];
    if (scanSummary.isNotEmpty) {
      lines
        ..add('scan_results:')
        ..addAll(scanSummary.map((line) => '  $line'));
    }
    if (debugLog.isNotEmpty) {
      lines
        ..add('debug_log:')
        ..addAll(debugLog.map((line) => '  $line'));
    }
    return lines.join('\n');
  }

  String _formatDevice() {
    if ((selectedDeviceName == null || selectedDeviceName!.isEmpty) &&
        (selectedDeviceId == null || selectedDeviceId!.isEmpty)) {
      return '-';
    }
    final name = selectedDeviceName?.isNotEmpty == true
        ? selectedDeviceName!
        : 'unknown';
    final id = selectedDeviceId?.isNotEmpty == true ? selectedDeviceId! : '-';
    return '$name ($id)';
  }
}
