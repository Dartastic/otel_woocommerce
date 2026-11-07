// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_woocommerce_suppression.dart';

const _tracerName = 'dartastic_otel_libs_woocommerce';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class WoocommerceResult {
  /// Creates a result.
  const WoocommerceResult({
    this.itemCount,
    this.totalCount,
    this.totalPages,
    this.page,
    this.perPage,
    this.resource,
    this.orderStatus,
    this.paymentMethod,
    this.totalAmountMinor,
    this.currency,
    this.requestId,
    this.statusCode,
  });

  /// Items in this page.
  final int? itemCount;

  /// `X-WP-Total` header.
  final int? totalCount;

  /// `X-WP-TotalPages` header.
  final int? totalPages;

  final int? page;
  final int? perPage;

  /// `products`, `orders`, `customers`, `coupons`, `refunds`,
  /// `reports`, `shipping`, `taxes`, `webhooks`, `settings`,
  /// `system_status`, `data` — slices traffic by resource family.
  final String? resource;

  /// `pending` / `processing` / `on-hold` / `completed` / `cancelled` /
  /// `refunded` / `failed` / `trash`.
  final String? orderStatus;

  /// Payment method id (`stripe`, `paypal`, `cod`, `bacs`, etc.).
  final String? paymentMethod;

  /// Order total in minor units (avoid float drift on WC's decimal
  /// totals).
  final int? totalAmountMinor;

  /// ISO 4217.
  final String? currency;

  /// `X-Request-ID` if WC plugin added it (Woo itself doesn't).
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class WoocommerceCallResult<T> {
  /// Creates a call result.
  const WoocommerceCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final WoocommerceResult? result;
}

/// Wraps a WooCommerce REST call in a CLIENT span. [operation] is one
/// of `products.list`, `products.get`, `products.create`,
/// `products.update`, `products.delete`, `products.batch`,
/// `orders.list`, `orders.get`, `orders.create`, `orders.update`,
/// `orders.note.create`, `orders.refund.create`, `customers.list`,
/// `customers.get`, `coupons.list`, `reports.totals`, `webhooks.list`,
/// `webhooks.create`, `taxes.list`, `system_status`.
Future<T> tracedWoocommerce<T>({
  required String operation,
  required Future<WoocommerceCallResult<T>> Function() invoke,
  String? apiVersion,
}) async {
  if (woocommerceInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'woocommerce',
    'rpc.method': operation,
    'woocommerce.operation': operation,
  };
  if (apiVersion != null) m['woocommerce.api_version'] = apiVersion;

  final span = _tracer().startSpan(
    'woocommerce $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'woocommerce.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.totalCount != null) {
        extras.add(OTelAPI.attributeInt(
          'woocommerce.total',
          r.result!.totalCount!,
        ));
      }
      if (r.result!.totalPages != null) {
        extras.add(OTelAPI.attributeInt(
          'woocommerce.total_pages',
          r.result!.totalPages!,
        ));
      }
      if (r.result!.page != null) {
        extras.add(OTelAPI.attributeInt('woocommerce.page', r.result!.page!));
      }
      if (r.result!.perPage != null) {
        extras.add(OTelAPI.attributeInt(
          'woocommerce.per_page',
          r.result!.perPage!,
        ));
      }
      if (r.result!.resource != null) {
        extras.add(OTelAPI.attributeString(
          'woocommerce.resource',
          r.result!.resource!,
        ));
      }
      if (r.result!.orderStatus != null) {
        extras.add(OTelAPI.attributeString(
          'woocommerce.order.status',
          r.result!.orderStatus!,
        ));
        if (r.result!.orderStatus == 'failed') {
          span.setStatus(
            SpanStatusCode.Error,
            'WooCommerce order failed',
          );
        }
      }
      if (r.result!.paymentMethod != null) {
        extras.add(OTelAPI.attributeString(
          'woocommerce.payment_method',
          r.result!.paymentMethod!,
        ));
      }
      if (r.result!.totalAmountMinor != null) {
        extras.add(OTelAPI.attributeInt(
          'woocommerce.amount.total.minor',
          r.result!.totalAmountMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTelAPI.attributeString(
          'woocommerce.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'woocommerce.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'WooCommerce HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
