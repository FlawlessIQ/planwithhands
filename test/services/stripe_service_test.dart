import 'package:flutter_test/flutter_test.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StripeService', () {
    test('startCheckout returns session URL from backend', () async {
      // Arrange: mock invoker to return a URL
      StripeService.configureTestOverrides(
        invoke: (name, data) async {
          expect(name, 'createCheckoutSession');
          expect(data['orgId'], 'org_123');
          expect(data['email'], 'user@example.com');
          expect(data['priceId'], kStripePriceMonthly);
          expect(data['quantity'], 3);
          return {'url': 'https://checkout.stripe.com/test_session'};
        },
      );

      // Act
      final url = await StripeService.startCheckout(
        orgId: 'org_123',
        email: 'user@example.com',
        priceId: kStripePriceMonthly,
        quantity: 3,
      );

      // Assert
      expect(url, 'https://checkout.stripe.com/test_session');
    });

    test('startCheckoutAndLaunch launches the returned URL', () async {
      Uri? launched;
      StripeService.configureTestOverrides(
        invoke: (name, data) async => {'url': 'https://example.com/checkout'},
        launch: (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
          launched = url;
          // Verify correct mode is requested
          expect(mode, LaunchMode.externalApplication);
          return true;
        },
      );

      await StripeService.startCheckoutAndLaunch(
        orgId: 'o1',
        email: 'a@b.com',
        priceId: kStripePriceMonthly,
        quantity: 2,
      );

      expect(launched, isNotNull);
      expect(launched.toString(), 'https://example.com/checkout');
    });

    test('updateSubscriptionQuantity invokes backend with expected payload', () async {
      Map<String, dynamic>? lastPayload;
      String? lastName;
      StripeService.configureTestOverrides(
        invoke: (name, data) async {
          lastName = name;
          lastPayload = data;
          return {'ok': true};
        },
      );

      await StripeService.updateSubscriptionQuantity(orgId: 'org_xyz', subscriptionId: 'sub_123', newQuantity: 7);

      expect(lastName, 'updateSubscription');
      expect(lastPayload, isNotNull);
      expect(lastPayload!['orgId'], 'org_xyz');
      expect(lastPayload!['subscriptionId'], 'sub_123');
      expect(lastPayload!['newQuantity'], 7);
    });
  });
}
