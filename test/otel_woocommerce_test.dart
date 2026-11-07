// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_woocommerce/otel_woocommerce.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_woocommerce-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('orders.create records status + payment + amount', () async {
    await tracedWoocommerce<String>(
      operation: 'orders.create',
      apiVersion: 'wc/v3',
      invoke: () async => const WoocommerceCallResult(
        value: 'ok',
        result: WoocommerceResult(
          resource: 'orders',
          orderStatus: 'processing',
          paymentMethod: 'stripe',
          totalAmountMinor: 9999,
          currency: 'USD',
          statusCode: 201,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('woocommerce orders.create')!);
    expect(a['woocommerce.api_version'], 'wc/v3');
    expect(a['woocommerce.resource'], 'orders');
    expect(a['woocommerce.order.status'], 'processing');
    expect(a['woocommerce.payment_method'], 'stripe');
    expect(a['woocommerce.amount.total.minor'], 9999);
  });

  test('failed order sets span error', () async {
    await tracedWoocommerce<String>(
      operation: 'orders.update',
      invoke: () async => const WoocommerceCallResult(
        value: 'ok',
        result: WoocommerceResult(orderStatus: 'failed'),
      ),
    );
    expect(
      spans.findSpanByName('woocommerce orders.update')!.status,
      SpanStatusCode.Error,
    );
  });

  test('pagination headers recorded', () async {
    await tracedWoocommerce<String>(
      operation: 'products.list',
      invoke: () async => const WoocommerceCallResult(
        value: 'ok',
        result: WoocommerceResult(
          itemCount: 20,
          totalCount: 312,
          totalPages: 16,
          page: 1,
          perPage: 20,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('woocommerce products.list')!);
    expect(a['woocommerce.total'], 312);
    expect(a['woocommerce.total_pages'], 16);
  });

  test('suppression skips spans', () async {
    await runWithoutWoocommerceInstrumentationAsync(() async {
      await tracedWoocommerce<String>(
        operation: 'products.list',
        invoke: () async => const WoocommerceCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('woocommerce '), isEmpty);
  });
}
