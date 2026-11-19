import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tutor_tasks/tutor_tasks.dart';

/// Shows a code as one QR code, or several in turn when it is long.
class QrCodes extends StatefulWidget {
  const QrCodes(this.code, {super.key, this.size = 280});
  final String code;
  final double size;

  @override
  State<QrCodes> createState() => _QrCodesState();
}

class _QrCodesState extends State<QrCodes> {
  late List<String> _parts = splitForQr(widget.code);
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(QrCodes old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) {
      _parts = splitForQr(widget.code);
      _i = 0;
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    if (_parts.length > 1) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => setState(() => _i = (_i + 1) % _parts.length),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: QrImageView(
            data: _parts[_i],
            size: widget.size,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        if (_parts.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${_i + 1} / ${_parts.length}'),
          ),
      ],
    );
  }
}

/// A full-screen camera that returns the first complete code accepted by
/// [accept] (several-part codes are collected first).
class QrScanPage extends StatefulWidget {
  const QrScanPage({
    super.key,
    required this.title,
    required this.hint,
    required this.accept,
    this.partsLabel,
  });
  final String title;
  final String hint;

  /// Returns an error to show, or null to accept the code.
  final String? Function(String code) accept;
  final String Function(int have, int total)? partsLabel;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _assembler = QrAssembler();
  String? _error;
  bool _done = false;

  void _onDetect(BarcodeCapture c) {
    if (_done) return;
    for (final b in c.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final whole = _assembler.add(raw);
      if (whole == null) {
        setState(() {});
        continue;
      }
      final err = widget.accept(whole);
      if (err == null) {
        _done = true;
        Navigator.of(context).pop(whole);
        return;
      }
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = _assembler.total > 1 && widget.partsLabel != null
        ? widget.partsLabel!(_assembler.have, _assembler.total)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                [widget.hint, ?parts, ?_error].join('\n'),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
