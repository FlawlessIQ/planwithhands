class PricingService {
  /// Get pricing tier information based on employee count
  static Map<String, String> getPricingTierInfo(int employeeCount) {
    if (employeeCount <= 10) {
      return {
        'price': '\$249/month',
        'range': '1–10 employees',
        'description': 'As low as \$24.90/employee',
      };
    } else if (employeeCount <= 25) {
      return {
        'price': '\$299/month',
        'range': '11–25 employees',
        'description': 'As low as \$11.96/employee',
      };
    } else if (employeeCount <= 50) {
      return {
        'price': '\$379/month',
        'range': '26–50 employees',
        'description': 'As low as \$7.58/employee',
      };
    } else if (employeeCount <= 100) {
      return {
        'price': '\$299/month',
        'range': '51–100 employees',
        'description': 'As low as \$2.99/employee',
      };
    } else {
      return {
        'price': 'Custom Pricing',
        'range': '100+ employees',
        'description': 'Contact Us',
      };
    }
  }
}
