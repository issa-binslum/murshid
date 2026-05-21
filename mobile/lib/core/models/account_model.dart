enum AccountType { bank, cash, mobileWallet }

extension AccountTypeX on AccountType {
  String get apiValue {
    switch (this) {
      case AccountType.bank:
        return 'BANK';
      case AccountType.cash:
        return 'CASH';
      case AccountType.mobileWallet:
        return 'MOBILE_WALLET';
    }
  }

  String get label {
    switch (this) {
      case AccountType.bank:
        return 'Bank';
      case AccountType.cash:
        return 'Cash';
      case AccountType.mobileWallet:
        return 'Mobile Wallet';
    }
  }

  static AccountType fromApi(String v) {
    switch (v) {
      case 'BANK':
        return AccountType.bank;
      case 'MOBILE_WALLET':
        return AccountType.mobileWallet;
      default:
        return AccountType.cash;
    }
  }
}

class AccountItem {
  final String id;
  final AccountType type;
  final String accountName;
  final String? bankName;
  final String? accountNumber;
  final double openingBalance;
  final double currentBalance;

  const AccountItem({
    required this.id,
    required this.type,
    required this.accountName,
    this.bankName,
    this.accountNumber,
    required this.openingBalance,
    required this.currentBalance,
  });

  factory AccountItem.fromJson(Map<String, dynamic> j) => AccountItem(
        id: j['id'] as String,
        type: AccountTypeX.fromApi(j['type'] as String),
        accountName: j['accountName'] as String,
        bankName: j['bankName'] as String?,
        accountNumber: j['accountNumber'] as String?,
        openingBalance: double.parse(j['openingBalance'].toString()),
        currentBalance: double.parse(j['currentBalance'].toString()),
      );
}
