class TransactionTypes {
  const TransactionTypes._();

  static const ciro = 'ciro';
  static const masraf = 'masraf';
  static const isci = 'isci';
  static const banka = 'banka';
  static const borc = 'borc';

  static const all = [ciro, masraf, isci, banka, borc];

  static String label(String type) {
    switch (type) {
      case ciro:
        return 'Ciro';
      case masraf:
        return 'Masraf';
      case isci:
        return 'İşçi Ödemesi';
      case banka:
        return 'Bankaya Yatan';
      case borc:
        return 'Borç / Alacak';
      default:
        return type;
    }
  }
}

class AppCategories {
  const AppCategories._();

  static const ciro = 'Ciro';
  static const isci = 'İşçi Ödemesi';
  static const banka = 'Bankaya Yatan';

  static const expenseCategories = [
    'Kira',
    'Muhasebe',
    'Kredi Kartı',
    'Genel Masraf',
    'Diğer',
  ];

  static const debtGiven = 'Verilen Borç';
  static const debtPayment = 'Alınan Ödeme';

  static const debtCategories = [debtGiven, debtPayment];

  static const defaultEmployees = [
    DefaultEmployeeDefinition(name: 'Bolat', salary: 34000),
    DefaultEmployeeDefinition(name: 'Mehmet', salary: 32000),
    DefaultEmployeeDefinition(name: 'Hasan Ali', salary: 30000),
    DefaultEmployeeDefinition(name: 'Ramazan', salary: 30000),
    DefaultEmployeeDefinition(name: 'Hidayet', salary: 28000),
    DefaultEmployeeDefinition(name: 'Ekstra', salary: 0),
  ];
}

class PaymentSources {
  const PaymentSources._();

  static const cash = 'cash';
  static const personal = 'personal';
  static const bank = 'bank';

  static const all = [cash, personal, bank];

  static String label(String source) {
    switch (source) {
      case cash:
        return 'Kasadan Ödendi';
      case personal:
        return 'Şahsi Hesaptan Ödendi';
      case bank:
        return 'Bankadan Ödendi';
      default:
        return 'Kasadan Ödendi';
    }
  }
}

class DefaultEmployeeDefinition {
  const DefaultEmployeeDefinition({required this.name, required this.salary});

  final String name;
  final double salary;
}
