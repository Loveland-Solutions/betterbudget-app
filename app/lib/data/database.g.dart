// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AccountType>($AccountsTable.$convertertype);
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('MNT'),
  );
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maskMeta = const VerificationMeta('mask');
  @override
  late final GeneratedColumn<String> mask = GeneratedColumn<String>(
    'mask',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sidebarGroupMeta = const VerificationMeta(
    'sidebarGroup',
  );
  @override
  late final GeneratedColumn<String> sidebarGroup = GeneratedColumn<String>(
    'sidebar_group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    currency,
    institution,
    mask,
    sidebarGroup,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    }
    if (data.containsKey('mask')) {
      context.handle(
        _maskMeta,
        mask.isAcceptableOrUnknown(data['mask']!, _maskMeta),
      );
    }
    if (data.containsKey('sidebar_group')) {
      context.handle(
        _sidebarGroupMeta,
        sidebarGroup.isAcceptableOrUnknown(
          data['sidebar_group']!,
          _sidebarGroupMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: $AccountsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      ),
      mask: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mask'],
      ),
      sidebarGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sidebar_group'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, String, String> $convertertype =
      const EnumNameConverter<AccountType>(AccountType.values);
}

class Account extends DataClass implements Insertable<Account> {
  final int id;
  final String name;
  final AccountType type;
  final String currency;
  final String? institution;
  final String? mask;
  final String? sidebarGroup;
  final int sortOrder;
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    this.institution,
    this.mask,
    this.sidebarGroup,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<String>($AccountsTable.$convertertype.toSql(type));
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || institution != null) {
      map['institution'] = Variable<String>(institution);
    }
    if (!nullToAbsent || mask != null) {
      map['mask'] = Variable<String>(mask);
    }
    if (!nullToAbsent || sidebarGroup != null) {
      map['sidebar_group'] = Variable<String>(sidebarGroup);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      currency: Value(currency),
      institution: institution == null && nullToAbsent
          ? const Value.absent()
          : Value(institution),
      mask: mask == null && nullToAbsent ? const Value.absent() : Value(mask),
      sidebarGroup: sidebarGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(sidebarGroup),
      sortOrder: Value(sortOrder),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: $AccountsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      currency: serializer.fromJson<String>(json['currency']),
      institution: serializer.fromJson<String?>(json['institution']),
      mask: serializer.fromJson<String?>(json['mask']),
      sidebarGroup: serializer.fromJson<String?>(json['sidebarGroup']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(
        $AccountsTable.$convertertype.toJson(type),
      ),
      'currency': serializer.toJson<String>(currency),
      'institution': serializer.toJson<String?>(institution),
      'mask': serializer.toJson<String?>(mask),
      'sidebarGroup': serializer.toJson<String?>(sidebarGroup),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    String? currency,
    Value<String?> institution = const Value.absent(),
    Value<String?> mask = const Value.absent(),
    Value<String?> sidebarGroup = const Value.absent(),
    int? sortOrder,
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    currency: currency ?? this.currency,
    institution: institution.present ? institution.value : this.institution,
    mask: mask.present ? mask.value : this.mask,
    sidebarGroup: sidebarGroup.present ? sidebarGroup.value : this.sidebarGroup,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currency: data.currency.present ? data.currency.value : this.currency,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      mask: data.mask.present ? data.mask.value : this.mask,
      sidebarGroup: data.sidebarGroup.present
          ? data.sidebarGroup.value
          : this.sidebarGroup,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('institution: $institution, ')
          ..write('mask: $mask, ')
          ..write('sidebarGroup: $sidebarGroup, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    currency,
    institution,
    mask,
    sidebarGroup,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.currency == this.currency &&
          other.institution == this.institution &&
          other.mask == this.mask &&
          other.sidebarGroup == this.sidebarGroup &&
          other.sortOrder == this.sortOrder);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<String> name;
  final Value<AccountType> type;
  final Value<String> currency;
  final Value<String?> institution;
  final Value<String?> mask;
  final Value<String?> sidebarGroup;
  final Value<int> sortOrder;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.institution = const Value.absent(),
    this.mask = const Value.absent(),
    this.sidebarGroup = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required AccountType type,
    this.currency = const Value.absent(),
    this.institution = const Value.absent(),
    this.mask = const Value.absent(),
    this.sidebarGroup = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : name = Value(name),
       type = Value(type);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currency,
    Expression<String>? institution,
    Expression<String>? mask,
    Expression<String>? sidebarGroup,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currency != null) 'currency': currency,
      if (institution != null) 'institution': institution,
      if (mask != null) 'mask': mask,
      if (sidebarGroup != null) 'sidebar_group': sidebarGroup,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  AccountsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<AccountType>? type,
    Value<String>? currency,
    Value<String?>? institution,
    Value<String?>? mask,
    Value<String?>? sidebarGroup,
    Value<int>? sortOrder,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      institution: institution ?? this.institution,
      mask: mask ?? this.mask,
      sidebarGroup: sidebarGroup ?? this.sidebarGroup,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $AccountsTable.$convertertype.toSql(type.value),
      );
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (mask.present) {
      map['mask'] = Variable<String>(mask.value);
    }
    if (sidebarGroup.present) {
      map['sidebar_group'] = Variable<String>(sidebarGroup.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('institution: $institution, ')
          ..write('mask: $mask, ')
          ..write('sidebarGroup: $sidebarGroup, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $PayeesTable extends Payees with TableInfo<$PayeesTable, Payee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payees';
  @override
  VerificationContext validateIntegrity(
    Insertable<Payee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Payee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Payee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $PayeesTable createAlias(String alias) {
    return $PayeesTable(attachedDatabase, alias);
  }
}

class Payee extends DataClass implements Insertable<Payee> {
  final int id;
  final String name;
  const Payee({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  PayeesCompanion toCompanion(bool nullToAbsent) {
    return PayeesCompanion(id: Value(id), name: Value(name));
  }

  factory Payee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Payee(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Payee copyWith({int? id, String? name}) =>
      Payee(id: id ?? this.id, name: name ?? this.name);
  Payee copyWithCompanion(PayeesCompanion data) {
    return Payee(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Payee(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Payee && other.id == this.id && other.name == this.name);
}

class PayeesCompanion extends UpdateCompanion<Payee> {
  final Value<int> id;
  final Value<String> name;
  const PayeesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  PayeesCompanion.insert({this.id = const Value.absent(), required String name})
    : name = Value(name);
  static Insertable<Payee> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  PayeesCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return PayeesCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayeesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeIdMeta = const VerificationMeta(
    'payeeId',
  );
  @override
  late final GeneratedColumn<int> payeeId = GeneratedColumn<int>(
    'payee_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES payees (id)',
    ),
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importKeyMeta = const VerificationMeta(
    'importKey',
  );
  @override
  late final GeneratedColumn<String> importKey = GeneratedColumn<String>(
    'import_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _scheduledMeta = const VerificationMeta(
    'scheduled',
  );
  @override
  late final GeneratedColumn<bool> scheduled = GeneratedColumn<bool>(
    'scheduled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("scheduled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    payeeId,
    memo,
    importKey,
    scheduled,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('payee_id')) {
      context.handle(
        _payeeIdMeta,
        payeeId.isAcceptableOrUnknown(data['payee_id']!, _payeeIdMeta),
      );
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('import_key')) {
      context.handle(
        _importKeyMeta,
        importKey.isAcceptableOrUnknown(data['import_key']!, _importKeyMeta),
      );
    }
    if (data.containsKey('scheduled')) {
      context.handle(
        _scheduledMeta,
        scheduled.isAcceptableOrUnknown(data['scheduled']!, _scheduledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      payeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payee_id'],
      ),
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      importKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_key'],
      ),
      scheduled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}scheduled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class TransactionRow extends DataClass implements Insertable<TransactionRow> {
  final int id;

  /// Calendar date as `YYYY-MM-DD`, never a timestamp (ADR 0001).
  final String date;
  final int? payeeId;
  final String? memo;
  final String? importKey;
  final bool scheduled;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const TransactionRow({
    required this.id,
    required this.date,
    this.payeeId,
    this.memo,
    this.importKey,
    required this.scheduled,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || payeeId != null) {
      map['payee_id'] = Variable<int>(payeeId);
    }
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    if (!nullToAbsent || importKey != null) {
      map['import_key'] = Variable<String>(importKey);
    }
    map['scheduled'] = Variable<bool>(scheduled);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      date: Value(date),
      payeeId: payeeId == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeId),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      importKey: importKey == null && nullToAbsent
          ? const Value.absent()
          : Value(importKey),
      scheduled: Value(scheduled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionRow(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      payeeId: serializer.fromJson<int?>(json['payeeId']),
      memo: serializer.fromJson<String?>(json['memo']),
      importKey: serializer.fromJson<String?>(json['importKey']),
      scheduled: serializer.fromJson<bool>(json['scheduled']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'payeeId': serializer.toJson<int?>(payeeId),
      'memo': serializer.toJson<String?>(memo),
      'importKey': serializer.toJson<String?>(importKey),
      'scheduled': serializer.toJson<bool>(scheduled),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  TransactionRow copyWith({
    int? id,
    String? date,
    Value<int?> payeeId = const Value.absent(),
    Value<String?> memo = const Value.absent(),
    Value<String?> importKey = const Value.absent(),
    bool? scheduled,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => TransactionRow(
    id: id ?? this.id,
    date: date ?? this.date,
    payeeId: payeeId.present ? payeeId.value : this.payeeId,
    memo: memo.present ? memo.value : this.memo,
    importKey: importKey.present ? importKey.value : this.importKey,
    scheduled: scheduled ?? this.scheduled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TransactionRow copyWithCompanion(TransactionsCompanion data) {
    return TransactionRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      payeeId: data.payeeId.present ? data.payeeId.value : this.payeeId,
      memo: data.memo.present ? data.memo.value : this.memo,
      importKey: data.importKey.present ? data.importKey.value : this.importKey,
      scheduled: data.scheduled.present ? data.scheduled.value : this.scheduled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('payeeId: $payeeId, ')
          ..write('memo: $memo, ')
          ..write('importKey: $importKey, ')
          ..write('scheduled: $scheduled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    payeeId,
    memo,
    importKey,
    scheduled,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.payeeId == this.payeeId &&
          other.memo == this.memo &&
          other.importKey == this.importKey &&
          other.scheduled == this.scheduled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TransactionsCompanion extends UpdateCompanion<TransactionRow> {
  final Value<int> id;
  final Value<String> date;
  final Value<int?> payeeId;
  final Value<String?> memo;
  final Value<String?> importKey;
  final Value<bool> scheduled;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.payeeId = const Value.absent(),
    this.memo = const Value.absent(),
    this.importKey = const Value.absent(),
    this.scheduled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    this.payeeId = const Value.absent(),
    this.memo = const Value.absent(),
    this.importKey = const Value.absent(),
    this.scheduled = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
  }) : date = Value(date),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TransactionRow> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<int>? payeeId,
    Expression<String>? memo,
    Expression<String>? importKey,
    Expression<bool>? scheduled,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (payeeId != null) 'payee_id': payeeId,
      if (memo != null) 'memo': memo,
      if (importKey != null) 'import_key': importKey,
      if (scheduled != null) 'scheduled': scheduled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<int?>? payeeId,
    Value<String?>? memo,
    Value<String?>? importKey,
    Value<bool>? scheduled,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      payeeId: payeeId ?? this.payeeId,
      memo: memo ?? this.memo,
      importKey: importKey ?? this.importKey,
      scheduled: scheduled ?? this.scheduled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (payeeId.present) {
      map['payee_id'] = Variable<int>(payeeId.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (importKey.present) {
      map['import_key'] = Variable<String>(importKey.value);
    }
    if (scheduled.present) {
      map['scheduled'] = Variable<bool>(scheduled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('payeeId: $payeeId, ')
          ..write('memo: $memo, ')
          ..write('importKey: $importKey, ')
          ..write('scheduled: $scheduled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $ReconciliationsTable extends Reconciliations
    with TableInfo<$ReconciliationsTable, ReconciliationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReconciliationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _statementDateMeta = const VerificationMeta(
    'statementDate',
  );
  @override
  late final GeneratedColumn<String> statementDate = GeneratedColumn<String>(
    'statement_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statementBalanceMinorMeta =
      const VerificationMeta('statementBalanceMinor');
  @override
  late final GeneratedColumn<int> statementBalanceMinor = GeneratedColumn<int>(
    'statement_balance_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    statementDate,
    statementBalanceMinor,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reconciliations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReconciliationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('statement_date')) {
      context.handle(
        _statementDateMeta,
        statementDate.isAcceptableOrUnknown(
          data['statement_date']!,
          _statementDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statementDateMeta);
    }
    if (data.containsKey('statement_balance_minor')) {
      context.handle(
        _statementBalanceMinorMeta,
        statementBalanceMinor.isAcceptableOrUnknown(
          data['statement_balance_minor']!,
          _statementBalanceMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statementBalanceMinorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReconciliationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReconciliationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      statementDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statement_date'],
      )!,
      statementBalanceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}statement_balance_minor'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReconciliationsTable createAlias(String alias) {
    return $ReconciliationsTable(attachedDatabase, alias);
  }
}

class ReconciliationRow extends DataClass
    implements Insertable<ReconciliationRow> {
  final int id;
  final int accountId;
  final String statementDate;
  final int statementBalanceMinor;
  final int createdAt;
  const ReconciliationRow({
    required this.id,
    required this.accountId,
    required this.statementDate,
    required this.statementBalanceMinor,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['statement_date'] = Variable<String>(statementDate);
    map['statement_balance_minor'] = Variable<int>(statementBalanceMinor);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ReconciliationsCompanion toCompanion(bool nullToAbsent) {
    return ReconciliationsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      statementDate: Value(statementDate),
      statementBalanceMinor: Value(statementBalanceMinor),
      createdAt: Value(createdAt),
    );
  }

  factory ReconciliationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReconciliationRow(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      statementDate: serializer.fromJson<String>(json['statementDate']),
      statementBalanceMinor: serializer.fromJson<int>(
        json['statementBalanceMinor'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'statementDate': serializer.toJson<String>(statementDate),
      'statementBalanceMinor': serializer.toJson<int>(statementBalanceMinor),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ReconciliationRow copyWith({
    int? id,
    int? accountId,
    String? statementDate,
    int? statementBalanceMinor,
    int? createdAt,
  }) => ReconciliationRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    statementDate: statementDate ?? this.statementDate,
    statementBalanceMinor: statementBalanceMinor ?? this.statementBalanceMinor,
    createdAt: createdAt ?? this.createdAt,
  );
  ReconciliationRow copyWithCompanion(ReconciliationsCompanion data) {
    return ReconciliationRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      statementDate: data.statementDate.present
          ? data.statementDate.value
          : this.statementDate,
      statementBalanceMinor: data.statementBalanceMinor.present
          ? data.statementBalanceMinor.value
          : this.statementBalanceMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReconciliationRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('statementDate: $statementDate, ')
          ..write('statementBalanceMinor: $statementBalanceMinor, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    statementDate,
    statementBalanceMinor,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReconciliationRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.statementDate == this.statementDate &&
          other.statementBalanceMinor == this.statementBalanceMinor &&
          other.createdAt == this.createdAt);
}

class ReconciliationsCompanion extends UpdateCompanion<ReconciliationRow> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> statementDate;
  final Value<int> statementBalanceMinor;
  final Value<int> createdAt;
  const ReconciliationsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.statementDate = const Value.absent(),
    this.statementBalanceMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ReconciliationsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required String statementDate,
    required int statementBalanceMinor,
    required int createdAt,
  }) : accountId = Value(accountId),
       statementDate = Value(statementDate),
       statementBalanceMinor = Value(statementBalanceMinor),
       createdAt = Value(createdAt);
  static Insertable<ReconciliationRow> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? statementDate,
    Expression<int>? statementBalanceMinor,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (statementDate != null) 'statement_date': statementDate,
      if (statementBalanceMinor != null)
        'statement_balance_minor': statementBalanceMinor,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ReconciliationsCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<String>? statementDate,
    Value<int>? statementBalanceMinor,
    Value<int>? createdAt,
  }) {
    return ReconciliationsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      statementDate: statementDate ?? this.statementDate,
      statementBalanceMinor:
          statementBalanceMinor ?? this.statementBalanceMinor,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (statementDate.present) {
      map['statement_date'] = Variable<String>(statementDate.value);
    }
    if (statementBalanceMinor.present) {
      map['statement_balance_minor'] = Variable<int>(
        statementBalanceMinor.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReconciliationsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('statementDate: $statementDate, ')
          ..write('statementBalanceMinor: $statementBalanceMinor, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, EntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('MNT'),
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<String> rate = GeneratedColumn<String>(
    'rate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Cleared, int> cleared =
      GeneratedColumn<int>(
        'cleared',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<Cleared>($EntriesTable.$convertercleared);
  static const VerificationMeta _reconciliationIdMeta = const VerificationMeta(
    'reconciliationId',
  );
  @override
  late final GeneratedColumn<int> reconciliationId = GeneratedColumn<int>(
    'reconciliation_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reconciliations (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionId,
    accountId,
    amountMinor,
    currency,
    rate,
    cleared,
    reconciliationId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    }
    if (data.containsKey('reconciliation_id')) {
      context.handle(
        _reconciliationIdMeta,
        reconciliationId.isAcceptableOrUnknown(
          data['reconciliation_id']!,
          _reconciliationIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate'],
      ),
      cleared: $EntriesTable.$convertercleared.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}cleared'],
        )!,
      ),
      reconciliationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reconciliation_id'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Cleared, int, int> $convertercleared =
      const EnumIndexConverter<Cleared>(Cleared.values);
}

class EntryRow extends DataClass implements Insertable<EntryRow> {
  final int id;
  final int transactionId;
  final int accountId;
  final int amountMinor;
  final String currency;

  /// Decimal string from the statement's Ханш column; not money, not REAL.
  final String? rate;
  final Cleared cleared;

  /// The reconcile that locked this entry, so it can be taken back later.
  final int? reconciliationId;
  const EntryRow({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.amountMinor,
    required this.currency,
    this.rate,
    required this.cleared,
    this.reconciliationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transaction_id'] = Variable<int>(transactionId);
    map['account_id'] = Variable<int>(accountId);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || rate != null) {
      map['rate'] = Variable<String>(rate);
    }
    {
      map['cleared'] = Variable<int>(
        $EntriesTable.$convertercleared.toSql(cleared),
      );
    }
    if (!nullToAbsent || reconciliationId != null) {
      map['reconciliation_id'] = Variable<int>(reconciliationId);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      accountId: Value(accountId),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      rate: rate == null && nullToAbsent ? const Value.absent() : Value(rate),
      cleared: Value(cleared),
      reconciliationId: reconciliationId == null && nullToAbsent
          ? const Value.absent()
          : Value(reconciliationId),
    );
  }

  factory EntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRow(
      id: serializer.fromJson<int>(json['id']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      accountId: serializer.fromJson<int>(json['accountId']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      rate: serializer.fromJson<String?>(json['rate']),
      cleared: $EntriesTable.$convertercleared.fromJson(
        serializer.fromJson<int>(json['cleared']),
      ),
      reconciliationId: serializer.fromJson<int?>(json['reconciliationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transactionId': serializer.toJson<int>(transactionId),
      'accountId': serializer.toJson<int>(accountId),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'rate': serializer.toJson<String?>(rate),
      'cleared': serializer.toJson<int>(
        $EntriesTable.$convertercleared.toJson(cleared),
      ),
      'reconciliationId': serializer.toJson<int?>(reconciliationId),
    };
  }

  EntryRow copyWith({
    int? id,
    int? transactionId,
    int? accountId,
    int? amountMinor,
    String? currency,
    Value<String?> rate = const Value.absent(),
    Cleared? cleared,
    Value<int?> reconciliationId = const Value.absent(),
  }) => EntryRow(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    accountId: accountId ?? this.accountId,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    rate: rate.present ? rate.value : this.rate,
    cleared: cleared ?? this.cleared,
    reconciliationId: reconciliationId.present
        ? reconciliationId.value
        : this.reconciliationId,
  );
  EntryRow copyWithCompanion(EntriesCompanion data) {
    return EntryRow(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      rate: data.rate.present ? data.rate.value : this.rate,
      cleared: data.cleared.present ? data.cleared.value : this.cleared,
      reconciliationId: data.reconciliationId.present
          ? data.reconciliationId.value
          : this.reconciliationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRow(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('accountId: $accountId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('rate: $rate, ')
          ..write('cleared: $cleared, ')
          ..write('reconciliationId: $reconciliationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    accountId,
    amountMinor,
    currency,
    rate,
    cleared,
    reconciliationId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRow &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.accountId == this.accountId &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.rate == this.rate &&
          other.cleared == this.cleared &&
          other.reconciliationId == this.reconciliationId);
}

class EntriesCompanion extends UpdateCompanion<EntryRow> {
  final Value<int> id;
  final Value<int> transactionId;
  final Value<int> accountId;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<String?> rate;
  final Value<Cleared> cleared;
  final Value<int?> reconciliationId;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.rate = const Value.absent(),
    this.cleared = const Value.absent(),
    this.reconciliationId = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required int transactionId,
    required int accountId,
    required int amountMinor,
    this.currency = const Value.absent(),
    this.rate = const Value.absent(),
    required Cleared cleared,
    this.reconciliationId = const Value.absent(),
  }) : transactionId = Value(transactionId),
       accountId = Value(accountId),
       amountMinor = Value(amountMinor),
       cleared = Value(cleared);
  static Insertable<EntryRow> custom({
    Expression<int>? id,
    Expression<int>? transactionId,
    Expression<int>? accountId,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? rate,
    Expression<int>? cleared,
    Expression<int>? reconciliationId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (accountId != null) 'account_id': accountId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (rate != null) 'rate': rate,
      if (cleared != null) 'cleared': cleared,
      if (reconciliationId != null) 'reconciliation_id': reconciliationId,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? transactionId,
    Value<int>? accountId,
    Value<int>? amountMinor,
    Value<String>? currency,
    Value<String?>? rate,
    Value<Cleared>? cleared,
    Value<int?>? reconciliationId,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      rate: rate ?? this.rate,
      cleared: cleared ?? this.cleared,
      reconciliationId: reconciliationId ?? this.reconciliationId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rate.present) {
      map['rate'] = Variable<String>(rate.value);
    }
    if (cleared.present) {
      map['cleared'] = Variable<int>(
        $EntriesTable.$convertercleared.toSql(cleared.value),
      );
    }
    if (reconciliationId.present) {
      map['reconciliation_id'] = Variable<int>(reconciliationId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('accountId: $accountId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('rate: $rate, ')
          ..write('cleared: $cleared, ')
          ..write('reconciliationId: $reconciliationId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $PayeesTable payees = $PayeesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $ReconciliationsTable reconciliations = $ReconciliationsTable(
    this,
  );
  late final $EntriesTable entries = $EntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    payees,
    transactions,
    reconciliations,
    entries,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  required String name,
  required AccountType type,
  Value<String> currency,
  Value<String?> institution,
  Value<String?> mask,
  Value<String?> sidebarGroup,
  Value<int> sortOrder,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<AccountType> type,
  Value<String> currency,
  Value<String?> institution,
  Value<String?> mask,
  Value<String?> sidebarGroup,
  Value<int> sortOrder,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReconciliationsTable, List<ReconciliationRow>>
  _reconciliationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reconciliations,
    aliasName: 'accounts__id__reconciliations__account_id',
  );

  $$ReconciliationsTableProcessedTableManager get reconciliationsRefs {
    final manager = $$ReconciliationsTableTableManager(
      $_db,
      $_db.reconciliations,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _reconciliationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntriesTable, List<EntryRow>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'accounts__id__entries__account_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountType, AccountType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mask => $composableBuilder(
    column: $table.mask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sidebarGroup => $composableBuilder(
    column: $table.sidebarGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> reconciliationsRefs(
    Expression<bool> Function($$ReconciliationsTableFilterComposer f) f,
  ) {
    final $$ReconciliationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reconciliations,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReconciliationsTableFilterComposer(
            $db: $db,
            $table: $db.reconciliations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mask => $composableBuilder(
    column: $table.mask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sidebarGroup => $composableBuilder(
    column: $table.sidebarGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mask =>
      $composableBuilder(column: $table.mask, builder: (column) => column);

  GeneratedColumn<String> get sidebarGroup => $composableBuilder(
    column: $table.sidebarGroup,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> reconciliationsRefs<T extends Object>(
    Expression<T> Function($$ReconciliationsTableAnnotationComposer a) f,
  ) {
    final $$ReconciliationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reconciliations,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReconciliationsTableAnnotationComposer(
            $db: $db,
            $table: $db.reconciliations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({bool reconciliationsRefs, bool entriesRefs})
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<AccountType> type = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> institution = const Value.absent(),
                Value<String?> mask = const Value.absent(),
                Value<String?> sidebarGroup = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                type: type,
                currency: currency,
                institution: institution,
                mask: mask,
                sidebarGroup: sidebarGroup,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required AccountType type,
                Value<String> currency = const Value.absent(),
                Value<String?> institution = const Value.absent(),
                Value<String?> mask = const Value.absent(),
                Value<String?> sidebarGroup = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                type: type,
                currency: currency,
                institution: institution,
                mask: mask,
                sidebarGroup: sidebarGroup,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, Account>(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({reconciliationsRefs = false, entriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (reconciliationsRefs) db.reconciliations,
                    if (entriesRefs) db.entries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (reconciliationsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          ReconciliationRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._reconciliationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).reconciliationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (entriesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          EntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._entriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).entriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({bool reconciliationsRefs, bool entriesRefs})
    >;
typedef $$PayeesTableCreateCompanionBuilder = PayeesCompanion Function({
  Value<int> id,
  required String name,
});
typedef $$PayeesTableUpdateCompanionBuilder = PayeesCompanion Function({
  Value<int> id,
  Value<String> name,
});

final class $$PayeesTableReferences
    extends BaseReferences<_$AppDatabase, $PayeesTable, Payee> {
  $$PayeesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRow>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'payees__id__transactions__payee_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.payeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PayeesTableFilterComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.payeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayeesTableOrderingComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PayeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayeesTable> {
  $$PayeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.payeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayeesTable,
          Payee,
          $$PayeesTableFilterComposer,
          $$PayeesTableOrderingComposer,
          $$PayeesTableAnnotationComposer,
          $$PayeesTableCreateCompanionBuilder,
          $$PayeesTableUpdateCompanionBuilder,
          (Payee, $$PayeesTableReferences),
          Payee,
          PrefetchHooks Function({bool transactionsRefs})
        > {
  $$PayeesTableTableManager(_$AppDatabase db, $PayeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) => PayeesCompanion(id: id, name: name),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) => PayeesCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayeesTable, Payee>(table),
                  $$PayeesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedData<
                      Payee,
                      $PayeesTable,
                      TransactionRow
                    >(
                      currentTable: table,
                      referencedTable: $$PayeesTableReferences
                          ._transactionsRefsTable(db),
                      managerFromTypedResult: (p0) => $$PayeesTableReferences(
                        db,
                        table,
                        p0,
                      ).transactionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.payeeId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PayeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayeesTable,
      Payee,
      $$PayeesTableFilterComposer,
      $$PayeesTableOrderingComposer,
      $$PayeesTableAnnotationComposer,
      $$PayeesTableCreateCompanionBuilder,
      $$PayeesTableUpdateCompanionBuilder,
      (Payee, $$PayeesTableReferences),
      Payee,
      PrefetchHooks Function({bool transactionsRefs})
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      required String date,
      Value<int?> payeeId,
      Value<String?> memo,
      Value<String?> importKey,
      Value<bool> scheduled,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      Value<String> date,
      Value<int?> payeeId,
      Value<String?> memo,
      Value<String?> importKey,
      Value<bool> scheduled,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, TransactionRow> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PayeesTable _payeeIdTable(_$AppDatabase db) =>
      db.payees.createAlias('transactions__payee_id__payees__id');

  $$PayeesTableProcessedTableManager? get payeeId {
    final $_column = $_itemColumn<int>('payee_id');
    if ($_column == null) return null;
    final manager = $$PayeesTableTableManager(
      $_db,
      $_db.payees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EntriesTable, List<EntryRow>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'transactions__id__entries__transaction_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importKey => $composableBuilder(
    column: $table.importKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get scheduled => $composableBuilder(
    column: $table.scheduled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PayeesTableFilterComposer get payeeId {
    final $$PayeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableFilterComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importKey => $composableBuilder(
    column: $table.importKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get scheduled => $composableBuilder(
    column: $table.scheduled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PayeesTableOrderingComposer get payeeId {
    final $$PayeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableOrderingComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get importKey =>
      $composableBuilder(column: $table.importKey, builder: (column) => column);

  GeneratedColumn<bool> get scheduled =>
      $composableBuilder(column: $table.scheduled, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PayeesTableAnnotationComposer get payeeId {
    final $$PayeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payeeId,
      referencedTable: $db.payees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeesTableAnnotationComposer(
            $db: $db,
            $table: $db.payees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          TransactionRow,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (TransactionRow, $$TransactionsTableReferences),
          TransactionRow,
          PrefetchHooks Function({bool payeeId, bool entriesRefs})
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int?> payeeId = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<String?> importKey = const Value.absent(),
                Value<bool> scheduled = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                date: date,
                payeeId: payeeId,
                memo: memo,
                importKey: importKey,
                scheduled: scheduled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String date,
                Value<int?> payeeId = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<String?> importKey = const Value.absent(),
                Value<bool> scheduled = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                date: date,
                payeeId: payeeId,
                memo: memo,
                importKey: importKey,
                scheduled: scheduled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, TransactionRow>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({payeeId = false, entriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entriesRefs) db.entries],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (payeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.payeeId,
                        referencedTable: $$TransactionsTableReferences
                            ._payeeIdTable(db),
                        referencedColumn: $$TransactionsTableReferences
                            ._payeeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entriesRefs)
                    await $_getPrefetchedData<
                      TransactionRow,
                      $TransactionsTable,
                      EntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$TransactionsTableReferences
                          ._entriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TransactionsTableReferences(
                            db,
                            table,
                            p0,
                          ).entriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.transactionId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      TransactionRow,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (TransactionRow, $$TransactionsTableReferences),
      TransactionRow,
      PrefetchHooks Function({bool payeeId, bool entriesRefs})
    >;
typedef $$ReconciliationsTableCreateCompanionBuilder =
    ReconciliationsCompanion Function({
      Value<int> id,
      required int accountId,
      required String statementDate,
      required int statementBalanceMinor,
      required int createdAt,
    });
typedef $$ReconciliationsTableUpdateCompanionBuilder =
    ReconciliationsCompanion Function({
      Value<int> id,
      Value<int> accountId,
      Value<String> statementDate,
      Value<int> statementBalanceMinor,
      Value<int> createdAt,
    });

final class $$ReconciliationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReconciliationsTable,
          ReconciliationRow
        > {
  $$ReconciliationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('reconciliations__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EntriesTable, List<EntryRow>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'reconciliations__id__entries__reconciliation_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.reconciliationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReconciliationsTableFilterComposer
    extends Composer<_$AppDatabase, $ReconciliationsTable> {
  $$ReconciliationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statementDate => $composableBuilder(
    column: $table.statementDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statementBalanceMinor => $composableBuilder(
    column: $table.statementBalanceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.reconciliationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReconciliationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReconciliationsTable> {
  $$ReconciliationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statementDate => $composableBuilder(
    column: $table.statementDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statementBalanceMinor => $composableBuilder(
    column: $table.statementBalanceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReconciliationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReconciliationsTable> {
  $$ReconciliationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get statementDate => $composableBuilder(
    column: $table.statementDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statementBalanceMinor => $composableBuilder(
    column: $table.statementBalanceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.reconciliationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReconciliationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReconciliationsTable,
          ReconciliationRow,
          $$ReconciliationsTableFilterComposer,
          $$ReconciliationsTableOrderingComposer,
          $$ReconciliationsTableAnnotationComposer,
          $$ReconciliationsTableCreateCompanionBuilder,
          $$ReconciliationsTableUpdateCompanionBuilder,
          (ReconciliationRow, $$ReconciliationsTableReferences),
          ReconciliationRow,
          PrefetchHooks Function({bool accountId, bool entriesRefs})
        > {
  $$ReconciliationsTableTableManager(
    _$AppDatabase db,
    $ReconciliationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReconciliationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReconciliationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReconciliationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<String> statementDate = const Value.absent(),
                Value<int> statementBalanceMinor = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => ReconciliationsCompanion(
                id: id,
                accountId: accountId,
                statementDate: statementDate,
                statementBalanceMinor: statementBalanceMinor,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required String statementDate,
                required int statementBalanceMinor,
                required int createdAt,
              }) => ReconciliationsCompanion.insert(
                id: id,
                accountId: accountId,
                statementDate: statementDate,
                statementBalanceMinor: statementBalanceMinor,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReconciliationsTable, ReconciliationRow>(table),
                  $$ReconciliationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, entriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entriesRefs) db.entries],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$ReconciliationsTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$ReconciliationsTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entriesRefs)
                    await $_getPrefetchedData<
                      ReconciliationRow,
                      $ReconciliationsTable,
                      EntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$ReconciliationsTableReferences
                          ._entriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ReconciliationsTableReferences(
                            db,
                            table,
                            p0,
                          ).entriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.reconciliationId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ReconciliationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReconciliationsTable,
      ReconciliationRow,
      $$ReconciliationsTableFilterComposer,
      $$ReconciliationsTableOrderingComposer,
      $$ReconciliationsTableAnnotationComposer,
      $$ReconciliationsTableCreateCompanionBuilder,
      $$ReconciliationsTableUpdateCompanionBuilder,
      (ReconciliationRow, $$ReconciliationsTableReferences),
      ReconciliationRow,
      PrefetchHooks Function({bool accountId, bool entriesRefs})
    >;
typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  Value<int> id,
  required int transactionId,
  required int accountId,
  required int amountMinor,
  Value<String> currency,
  Value<String?> rate,
  required Cleared cleared,
  Value<int?> reconciliationId,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<int> id,
  Value<int> transactionId,
  Value<int> accountId,
  Value<int> amountMinor,
  Value<String> currency,
  Value<String?> rate,
  Value<Cleared> cleared,
  Value<int?> reconciliationId,
});

final class $$EntriesTableReferences
    extends BaseReferences<_$AppDatabase, $EntriesTable, EntryRow> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias('entries__transaction_id__transactions__id');

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('entries__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ReconciliationsTable _reconciliationIdTable(_$AppDatabase db) => db
      .reconciliations
      .createAlias('entries__reconciliation_id__reconciliations__id');

  $$ReconciliationsTableProcessedTableManager? get reconciliationId {
    final $_column = $_itemColumn<int>('reconciliation_id');
    if ($_column == null) return null;
    final manager = $$ReconciliationsTableTableManager(
      $_db,
      $_db.reconciliations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reconciliationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Cleared, Cleared, int> get cleared =>
      $composableBuilder(
        column: $table.cleared,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReconciliationsTableFilterComposer get reconciliationId {
    final $$ReconciliationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reconciliationId,
      referencedTable: $db.reconciliations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReconciliationsTableFilterComposer(
            $db: $db,
            $table: $db.reconciliations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cleared => $composableBuilder(
    column: $table.cleared,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReconciliationsTableOrderingComposer get reconciliationId {
    final $$ReconciliationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reconciliationId,
      referencedTable: $db.reconciliations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReconciliationsTableOrderingComposer(
            $db: $db,
            $table: $db.reconciliations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Cleared, int> get cleared =>
      $composableBuilder(column: $table.cleared, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReconciliationsTableAnnotationComposer get reconciliationId {
    final $$ReconciliationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reconciliationId,
      referencedTable: $db.reconciliations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReconciliationsTableAnnotationComposer(
            $db: $db,
            $table: $db.reconciliations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          EntryRow,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (EntryRow, $$EntriesTableReferences),
          EntryRow,
          PrefetchHooks Function({
            bool transactionId,
            bool accountId,
            bool reconciliationId,
          })
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> transactionId = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> rate = const Value.absent(),
                Value<Cleared> cleared = const Value.absent(),
                Value<int?> reconciliationId = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                transactionId: transactionId,
                accountId: accountId,
                amountMinor: amountMinor,
                currency: currency,
                rate: rate,
                cleared: cleared,
                reconciliationId: reconciliationId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int transactionId,
                required int accountId,
                required int amountMinor,
                Value<String> currency = const Value.absent(),
                Value<String?> rate = const Value.absent(),
                required Cleared cleared,
                Value<int?> reconciliationId = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                transactionId: transactionId,
                accountId: accountId,
                amountMinor: amountMinor,
                currency: currency,
                rate: rate,
                cleared: cleared,
                reconciliationId: reconciliationId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntriesTable, EntryRow>(table),
                  $$EntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                transactionId = false,
                accountId = false,
                reconciliationId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (transactionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.transactionId,
                            referencedTable: $$EntriesTableReferences
                                ._transactionIdTable(db),
                            referencedColumn: $$EntriesTableReferences
                                ._transactionIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (accountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountId,
                            referencedTable: $$EntriesTableReferences
                                ._accountIdTable(db),
                            referencedColumn: $$EntriesTableReferences
                                ._accountIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (reconciliationId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.reconciliationId,
                            referencedTable: $$EntriesTableReferences
                                ._reconciliationIdTable(db),
                            referencedColumn: $$EntriesTableReferences
                                ._reconciliationIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      EntryRow,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (EntryRow, $$EntriesTableReferences),
      EntryRow,
      PrefetchHooks Function({
        bool transactionId,
        bool accountId,
        bool reconciliationId,
      })
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$PayeesTableTableManager get payees =>
      $$PayeesTableTableManager(_db, _db.payees);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$ReconciliationsTableTableManager get reconciliations =>
      $$ReconciliationsTableTableManager(_db, _db.reconciliations);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
}
