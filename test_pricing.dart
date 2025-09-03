import 'lib/services/pricing_service.dart';

void main() {
  print('Testing PricingService:');
  print('1 location monthly: \$${PricingService.calcMonthly(1)}');
  print('2 locations monthly: \$${PricingService.calcMonthly(2)}');
  print('3 locations monthly: \$${PricingService.calcMonthly(3)}');
  print('1 location annual: \$${PricingService.calcAnnual(1)}');
  print('2 locations annual: \$${PricingService.calcAnnual(2)}');
  print('3 locations annual: \$${PricingService.calcAnnual(3)}');
  print(
    'Constants: Base Monthly: \$${PricingService.kBaseMonthly}, Additional Monthly: \$${PricingService.kAddlMonthly}',
  );
  print('Constants: Base Annual: \$${PricingService.kBaseAnnual}, Additional Annual: \$${PricingService.kAddlAnnual}');
}
