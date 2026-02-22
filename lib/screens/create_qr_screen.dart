import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr/qr.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/constants.dart';
import '../widgets/common_app_bar.dart';

class CreateQrScreen extends StatefulWidget {
  const CreateQrScreen({Key? key}) : super(key: key);

  @override
  State<CreateQrScreen> createState() => _CreateQrScreenState();
}

class _CreateQrScreenState extends State<CreateQrScreen> {
  bool _useKeyValue = false;
  final TextEditingController _rawController = TextEditingController();
  final List<_KeyValueRow> _rows = [ _KeyValueRow() ];
  double _size = 240;

  @override
  void dispose() {
    _rawController.dispose();
    super.dispose();
  }

  String get _qrData {
    if (_useKeyValue) {
      final map = <String, dynamic>{};
      for (final row in _rows) {
        final key = row.keyText.trim();
        if (key.isEmpty) continue;
        map[key] = row.valueText.trim();
      }
      return json.encode(map);
    }
    return _rawController.text.trim();
  }

  QrPainter _buildPainter() {
    return QrPainter(
      data: _qrData.isEmpty ? ' ' : _qrData,
      version: QrVersions.auto,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
  }

  Future<Uint8List> _toPngBytes() async {
    final painter = _buildPainter();
    final uiImageData = await painter.toImageData(_size, format: ui.ImageByteFormat.png);
    return uiImageData!.buffer.asUint8List();
  }

  Future<Uint8List> _toJpgBytes() async {
    final png = await _toPngBytes();
    final decoded = img.decodeImage(png);
    if (decoded == null) return png;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
  }

  Future<String> _toSvgString() async {
    final qrCode = QrCode.fromData(
      data: _qrData.isEmpty ? ' ' : _qrData,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final scale = _size / moduleCount;
    final buffer = StringBuffer();
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="${_size.round()}" height="${_size.round()}" viewBox="0 0 ${_size.round()} ${_size.round()}">',
    );
    buffer.writeln('<rect width="100%" height="100%" fill="white"/>');
    for (var y = 0; y < moduleCount; y++) {
      for (var x = 0; x < moduleCount; x++) {
        if (qrImage.isDark(y, x)) {
          final rx = (x * scale);
          final ry = (y * scale);
          buffer.writeln(
            '<rect x="$rx" y="$ry" width="$scale" height="$scale" fill="black"/>',
          );
        }
      }
    }
    buffer.writeln('</svg>');
    return buffer.toString();
  }

  Future<Uint8List> _toPdfBytes() async {
    final png = await _toPngBytes();
    final doc = pw.Document();
    final image = pw.MemoryImage(png);
    doc.addPage(
      pw.Page(
        build: (_) => pw.Center(
          child: pw.Image(image, width: _size, height: _size),
        ),
      ),
    );
    return doc.save();
  }

  Future<String> _saveBytes(Uint8List bytes, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/qr_$stamp.$ext';
    final file = await File(path).writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.storage.request();
    if (status.isGranted) return true;
    final manage = await Permission.manageExternalStorage.request();
    return manage.isGranted;
  }

  Future<String?> _saveToDownloads(Uint8List bytes, String ext) async {
    if (!Platform.isAndroid) {
      return _saveBytes(bytes, ext);
    }
    final hasPerm = await _ensureStoragePermission();
    if (!hasPerm) return null;
    final dir = Directory('/storage/emulated/0/Download');
    if (!dir.existsSync()) return null;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${dir.path}/qr_$stamp.$ext';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> _savePng() async {
    final bytes = await _toPngBytes();
    final path = await _saveToDownloads(bytes, 'png');
    if (path != null) {
      _showSnack('Saved PNG: $path');
    } else {
      _showSnack('Save PNG failed (permission)');
    }
  }

  Future<void> _saveJpg() async {
    final bytes = await _toJpgBytes();
    final path = await _saveToDownloads(bytes, 'jpg');
    if (path != null) {
      _showSnack('Saved JPG: $path');
    } else {
      _showSnack('Save JPG failed (permission)');
    }
  }

  Future<void> _saveSvg() async {
    final svg = await _toSvgString();
    final bytes = Uint8List.fromList(utf8.encode(svg));
    final path = await _saveToDownloads(bytes, 'svg');
    if (path != null) {
      _showSnack('Saved SVG: $path');
    } else {
      _showSnack('Save SVG failed (permission)');
    }
  }

  Future<void> _savePdf() async {
    final bytes = await _toPdfBytes();
    final path = await _saveToDownloads(bytes, 'pdf');
    if (path != null) {
      _showSnack('Saved PDF: $path');
    } else {
      _showSnack('Save PDF failed (permission)');
    }
  }

  Future<void> _sharePng() async {
    final bytes = await _toPngBytes();
    final path = await _saveBytes(bytes, 'png');
    await Share.shareXFiles([XFile(path)], text: 'QR Code');
  }

  Future<void> _copyData() async {
    await Clipboard.setData(ClipboardData(text: _qrData));
    _showSnack('Copied data');
  }

  Future<void> _copyImage() async {
    try {
      final bytes = await _toPngBytes();
      await Pasteboard.writeImage(bytes);
      _showSnack('Copied image');
    } catch (_) {
      _showSnack('Copy image not supported');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final data = _qrData;
    return Scaffold(
      appBar: const CommonAppBar(title: AppConstants.appName),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Create QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ToggleButtons(
            isSelected: [_useKeyValue == false, _useKeyValue == true],
            onPressed: (index) {
              setState(() {
                _useKeyValue = index == 1;
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Raw Text'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Key / Value'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_useKeyValue)
            TextField(
              controller: _rawController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Text / Data',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          if (_useKeyValue) _buildKeyValueEditor(),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10),
                ],
              ),
              child: QrImageView(
                data: data.isEmpty ? ' ' : data,
                size: _size,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Size'),
              Expanded(
                child: Slider(
                  value: _size,
                  min: 160,
                  max: 480,
                  divisions: 16,
                  label: '${_size.round()}px',
                  onChanged: (value) => setState(() => _size = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Export', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(onPressed: _savePng, child: const Text('PNG')),
              ElevatedButton(onPressed: _saveSvg, child: const Text('SVG')),
              ElevatedButton(onPressed: _savePdf, child: const Text('PDF')),
              ElevatedButton(onPressed: _saveJpg, child: const Text('JPG')),
              OutlinedButton.icon(onPressed: _sharePng, icon: const Icon(Icons.share), label: const Text('Share')),
              OutlinedButton.icon(onPressed: _copyData, icon: const Icon(Icons.copy), label: const Text('Copy Data')),
              OutlinedButton.icon(onPressed: _copyImage, icon: const Icon(Icons.copy_all), label: const Text('Copy Image')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValueEditor() {
    return Column(
      children: [
        ..._rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Key'),
                  onChanged: (value) => row.keyText = value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Value'),
                  onChanged: (value) => row.valueText = value,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _rows.removeAt(index);
                    if (_rows.isEmpty) _rows.add(_KeyValueRow());
                  });
                },
              ),
            ],
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() => _rows.add(_KeyValueRow())),
          icon: const Icon(Icons.add),
          label: const Text('Add Field'),
        ),
      ],
    );
  }
}

class _KeyValueRow {
  _KeyValueRow({this.keyText = '', this.valueText = ''});
  String keyText;
  String valueText;
}
