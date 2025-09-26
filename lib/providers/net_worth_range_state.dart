import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetWorthRange { lastThreeMonths, lastSixMonths, lastYear }

extension NetWorthRangeLabel on NetWorthRange {
	String get label {
		switch (this) {
			case NetWorthRange.lastThreeMonths:
				return '3M';
			case NetWorthRange.lastSixMonths:
				return '6M';
			case NetWorthRange.lastYear:
				return '1Y';
		}
	}
}

final netWorthRangeProvider = StateProvider<NetWorthRange>(
	(ref) => NetWorthRange.lastThreeMonths,
);
