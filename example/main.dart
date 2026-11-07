// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_woocommerce/otel_woocommerce.dart';

/// Traces WooCommerce calls with OpenTelemetry.
///
/// `otel_woocommerce` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each WooCommerce call in
/// [tracedWoocommerce]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'woocommerce-example');

  // Wraps a WooCommerce REST call in a CLIENT span.
  final woocommerceId = await tracedWoocommerce<String>(
    operation: 'products.create',
    apiVersion: '1',
    invoke: () async {
      // Make the WooCommerce call here, then report what it returned.
      const id = 'woocommerce_8f3a2c';
      return const WoocommerceCallResult(
          value: id,
          result: WoocommerceResult(
              itemCount: 3,
              totalCount: 3,
              totalPages: 1,
              page: 1,
              perPage: 1,
              resource: 'products',
              orderStatus: 'pending',
              paymentMethod: 'stripe',
              totalAmountMinor: 1999,
              currency: 'usd',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedWoocommerce products.create returned $woocommerceId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutWoocommerceInstrumentationAsync.
  await runWithoutWoocommerceInstrumentationAsync(
    () => tracedWoocommerce<String>(
      operation: 'products.create',
      apiVersion: '1',
      invoke: () async {
        const id = 'woocommerce_8f3a2c';
        return const WoocommerceCallResult(
            value: id,
            result: WoocommerceResult(
                itemCount: 3,
                totalCount: 3,
                totalPages: 1,
                page: 1,
                perPage: 1,
                resource: 'products',
                orderStatus: 'pending',
                paymentMethod: 'stripe',
                totalAmountMinor: 1999,
                currency: 'usd',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
