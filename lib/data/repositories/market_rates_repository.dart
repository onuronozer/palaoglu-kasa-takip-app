import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/market_rate_model.dart';

final marketRatesProvider =
    StreamProvider.autoDispose<List<MarketRateModel>>((ref) {
  final repository = MarketRatesRepository();
  ref.onDispose(repository.dispose);
  return repository.watchRates();
});

class MarketRatesRepository {
  WebSocketChannel? _channel;
  StreamController<List<MarketRateModel>>? _controller;
  final Map<String, MarketRateModel> _latestRates = {};

  Stream<List<MarketRateModel>> watchRates() {
    _controller = StreamController<List<MarketRateModel>>(
      onListen: _connect,
      onCancel: dispose,
    );
    return _controller!.stream;
  }

  void _connect() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(
          'wss://hrmsocketonly.haremaltin.com/socket.io/?EIO=4&transport=websocket',
        ),
      );
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: () {
          if (_controller?.isClosed == false && _latestRates.isEmpty) {
            _controller!.add(const []);
          }
        },
      );
    } catch (error, stackTrace) {
      _handleError(error, stackTrace);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final text = message.toString();
      if (text == '2') {
        _channel?.sink.add('3');
        return;
      }
      if (text.startsWith('0')) {
        _channel?.sink.add('40');
        return;
      }
      if (!text.startsWith('42')) {
        return;
      }

      final decoded = jsonDecode(text.substring(2));
      if (decoded is! List ||
          decoded.length < 2 ||
          decoded.first != 'price_changed') {
        return;
      }

      final payload = decoded[1];
      if (payload is! Map<String, dynamic>) {
        return;
      }
      final data = payload['data'];
      if (data is! Map<String, dynamic>) {
        return;
      }

      for (final code in _marketRateCodes) {
        final rawRate = data[code];
        if (rawRate is Map<String, dynamic>) {
          final rate = _rateFromJson(code, rawRate);
          if (rate != null) {
            _latestRates[code] = rate;
          }
        }
      }

      if (_latestRates.isNotEmpty && _controller?.isClosed == false) {
        _controller!.add([
          for (final code in _marketRateCodes)
            if (_latestRates[code] != null) _latestRates[code]!,
        ]);
      }
    } catch (error, stackTrace) {
      _handleError(error, stackTrace);
    }
  }

  void _handleError(Object error, [StackTrace? stackTrace]) {
    if (_controller?.isClosed == false && _latestRates.isEmpty) {
      _controller!.addError(error, stackTrace);
    }
  }

  MarketRateModel? _rateFromJson(String code, Map<String, dynamic> json) {
    final buy = _doubleValue(json['alis']);
    final sell = _doubleValue(json['satis']);
    if (buy <= 0 || sell <= 0) {
      return null;
    }

    final directionData = json['dir'];
    final direction = directionData is Map<String, dynamic>
        ? directionData['satis_dir']?.toString() ?? ''
        : '';

    return MarketRateModel(
      code: code,
      label: _marketRateLabels[code] ?? code,
      buy: buy,
      sell: sell,
      updatedText: json['tarih']?.toString() ?? '',
      direction: direction,
    );
  }

  double _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return 0;
    }
    final normalized = text.contains(',') && text.contains('.')
        ? text.replaceAll('.', '').replaceAll(',', '.')
        : text.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
    _controller?.close();
    _controller = null;
  }
}

const _marketRateCodes = ['ALTIN', 'USDTRY', 'EURTRY'];

const _marketRateLabels = {
  'ALTIN': 'Gram Altın',
  'USDTRY': 'Dolar',
  'EURTRY': 'Euro',
};
