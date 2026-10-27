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
    clientDefault: newRowId,
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
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _paydayMeta = const VerificationMeta('payday');
  @override
  late final GeneratedColumn<bool> payday = GeneratedColumn<bool>(
    'payday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("payday" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountRole?, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<AccountRole?>($AccountsTable.$converterrolen);
  static const VerificationMeta _budgetGroupMeta = const VerificationMeta(
    'budgetGroup',
  );
  @override
  late final GeneratedColumn<String> budgetGroup = GeneratedColumn<String>(
    'budget_group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    archivedAt,
    deletedAt,
    payday,
    role,
    budgetGroup,
    note,
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
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('payday')) {
      context.handle(
        _paydayMeta,
        payday.isAcceptableOrUnknown(data['payday']!, _paydayMeta),
      );
    }
    if (data.containsKey('budget_group')) {
      context.handle(
        _budgetGroupMeta,
        budgetGroup.isAcceptableOrUnknown(
          data['budget_group']!,
          _budgetGroupMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      payday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}payday'],
      )!,
      role: $AccountsTable.$converterrolen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        ),
      ),
      budgetGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_group'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, String, String> $convertertype =
      const EnumNameConverter<AccountType>(AccountType.values);
  static JsonTypeConverter2<AccountRole, String, String> $converterrole =
      const EnumNameConverter<AccountRole>(AccountRole.values);
  static JsonTypeConverter2<AccountRole?, String?, String?> $converterrolen =
      JsonTypeConverter2.asNullable($converterrole);
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
  final int? archivedAt;

  /// Deleted with its own rows; transfers with other accounts stay.
  final int? deletedAt;

  /// Unused since v13: there's one income category, and its rows end the
  /// forecast.
  final bool payday;

  /// What the account is for on the Savings steps (rule 25): the emergency
  /// fund, or a loan that isn't consumer debt.
  final AccountRole? role;

  /// A spending category's group on the Budget page, a heading over the
  /// categories in it (v22, #100). Null: under no heading.
  final String? budgetGroup;

  /// What the person wrote about a category, shown under its name (v22).
  final String? note;
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    this.institution,
    this.mask,
    this.sidebarGroup,
    required this.sortOrder,
    this.archivedAt,
    this.deletedAt,
    required this.payday,
    this.role,
    this.budgetGroup,
    this.note,
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
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['payday'] = Variable<bool>(payday);
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(
        $AccountsTable.$converterrolen.toSql(role),
      );
    }
    if (!nullToAbsent || budgetGroup != null) {
      map['budget_group'] = Variable<String>(budgetGroup);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
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
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      payday: Value(payday),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      budgetGroup: budgetGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetGroup),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
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
      archivedAt: serializer.fromJson<int?>(json['archivedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      payday: serializer.fromJson<bool>(json['payday']),
      role: $AccountsTable.$converterrolen.fromJson(
        serializer.fromJson<String?>(json['role']),
      ),
      budgetGroup: serializer.fromJson<String?>(json['budgetGroup']),
      note: serializer.fromJson<String?>(json['note']),
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
      'archivedAt': serializer.toJson<int?>(archivedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'payday': serializer.toJson<bool>(payday),
      'role': serializer.toJson<String?>(
        $AccountsTable.$converterrolen.toJson(role),
      ),
      'budgetGroup': serializer.toJson<String?>(budgetGroup),
      'note': serializer.toJson<String?>(note),
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
    Value<int?> archivedAt = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    bool? payday,
    Value<AccountRole?> role = const Value.absent(),
    Value<String?> budgetGroup = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    currency: currency ?? this.currency,
    institution: institution.present ? institution.value : this.institution,
    mask: mask.present ? mask.value : this.mask,
    sidebarGroup: sidebarGroup.present ? sidebarGroup.value : this.sidebarGroup,
    sortOrder: sortOrder ?? this.sortOrder,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    payday: payday ?? this.payday,
    role: role.present ? role.value : this.role,
    budgetGroup: budgetGroup.present ? budgetGroup.value : this.budgetGroup,
    note: note.present ? note.value : this.note,
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
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      payday: data.payday.present ? data.payday.value : this.payday,
      role: data.role.present ? data.role.value : this.role,
      budgetGroup: data.budgetGroup.present
          ? data.budgetGroup.value
          : this.budgetGroup,
      note: data.note.present ? data.note.value : this.note,
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
          ..write('sortOrder: $sortOrder, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('payday: $payday, ')
          ..write('role: $role, ')
          ..write('budgetGroup: $budgetGroup, ')
          ..write('note: $note')
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
    archivedAt,
    deletedAt,
    payday,
    role,
    budgetGroup,
    note,
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
          other.sortOrder == this.sortOrder &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.payday == this.payday &&
          other.role == this.role &&
          other.budgetGroup == this.budgetGroup &&
          other.note == this.note);
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
  final Value<int?> archivedAt;
  final Value<int?> deletedAt;
  final Value<bool> payday;
  final Value<AccountRole?> role;
  final Value<String?> budgetGroup;
  final Value<String?> note;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.institution = const Value.absent(),
    this.mask = const Value.absent(),
    this.sidebarGroup = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.payday = const Value.absent(),
    this.role = const Value.absent(),
    this.budgetGroup = const Value.absent(),
    this.note = const Value.absent(),
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
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.payday = const Value.absent(),
    this.role = const Value.absent(),
    this.budgetGroup = const Value.absent(),
    this.note = const Value.absent(),
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
    Expression<int>? archivedAt,
    Expression<int>? deletedAt,
    Expression<bool>? payday,
    Expression<String>? role,
    Expression<String>? budgetGroup,
    Expression<String>? note,
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
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (payday != null) 'payday': payday,
      if (role != null) 'role': role,
      if (budgetGroup != null) 'budget_group': budgetGroup,
      if (note != null) 'note': note,
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
    Value<int?>? archivedAt,
    Value<int?>? deletedAt,
    Value<bool>? payday,
    Value<AccountRole?>? role,
    Value<String?>? budgetGroup,
    Value<String?>? note,
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
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      payday: payday ?? this.payday,
      role: role ?? this.role,
      budgetGroup: budgetGroup ?? this.budgetGroup,
      note: note ?? this.note,
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
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (payday.present) {
      map['payday'] = Variable<bool>(payday.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $AccountsTable.$converterrolen.toSql(role.value),
      );
    }
    if (budgetGroup.present) {
      map['budget_group'] = Variable<String>(budgetGroup.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
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
          ..write('sortOrder: $sortOrder, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('payday: $payday, ')
          ..write('role: $role, ')
          ..write('budgetGroup: $budgetGroup, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $PaySchedulesTable extends PaySchedules
    with TableInfo<$PaySchedulesTable, PayScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaySchedulesTable(this.attachedDatabase, [this._alias]);
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
    clientDefault: newRowId,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
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
  static const VerificationMeta _payeeMeta = const VerificationMeta('payee');
  @override
  late final GeneratedColumn<String> payee = GeneratedColumn<String>(
    'payee',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _amount2MinorMeta = const VerificationMeta(
    'amount2Minor',
  );
  @override
  late final GeneratedColumn<int> amount2Minor = GeneratedColumn<int>(
    'amount2_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variesMeta = const VerificationMeta('varies');
  @override
  late final GeneratedColumn<bool> varies = GeneratedColumn<bool>(
    'varies',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("varies" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PayRule, String> rule =
      GeneratedColumn<String>(
        'rule',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PayRule>($PaySchedulesTable.$converterrule);
  static const VerificationMeta _day1Meta = const VerificationMeta('day1');
  @override
  late final GeneratedColumn<int> day1 = GeneratedColumn<int>(
    'day1',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(25),
  );
  static const VerificationMeta _day2Meta = const VerificationMeta('day2');
  @override
  late final GeneratedColumn<int> day2 = GeneratedColumn<int>(
    'day2',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _weeksMeta = const VerificationMeta('weeks');
  @override
  late final GeneratedColumn<int> weeks = GeneratedColumn<int>(
    'weeks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _anchorMeta = const VerificationMeta('anchor');
  @override
  late final GeneratedColumn<String> anchor = GeneratedColumn<String>(
    'anchor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weekendBeforeMeta = const VerificationMeta(
    'weekendBefore',
  );
  @override
  late final GeneratedColumn<bool> weekendBefore = GeneratedColumn<bool>(
    'weekend_before',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("weekend_before" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _weekendKeepMeta = const VerificationMeta(
    'weekendKeep',
  );
  @override
  late final GeneratedColumn<bool> weekendKeep = GeneratedColumn<bool>(
    'weekend_keep',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("weekend_keep" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _definesPeriodMeta = const VerificationMeta(
    'definesPeriod',
  );
  @override
  late final GeneratedColumn<bool> definesPeriod = GeneratedColumn<bool>(
    'defines_period',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("defines_period" IN (0, 1))',
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
    categoryId,
    accountId,
    payee,
    name,
    amountMinor,
    amount2Minor,
    varies,
    rule,
    day1,
    day2,
    weeks,
    anchor,
    weekendBefore,
    weekendKeep,
    definesPeriod,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pay_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayScheduleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('payee')) {
      context.handle(
        _payeeMeta,
        payee.isAcceptableOrUnknown(data['payee']!, _payeeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
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
    if (data.containsKey('amount2_minor')) {
      context.handle(
        _amount2MinorMeta,
        amount2Minor.isAcceptableOrUnknown(
          data['amount2_minor']!,
          _amount2MinorMeta,
        ),
      );
    }
    if (data.containsKey('varies')) {
      context.handle(
        _variesMeta,
        varies.isAcceptableOrUnknown(data['varies']!, _variesMeta),
      );
    }
    if (data.containsKey('day1')) {
      context.handle(
        _day1Meta,
        day1.isAcceptableOrUnknown(data['day1']!, _day1Meta),
      );
    }
    if (data.containsKey('day2')) {
      context.handle(
        _day2Meta,
        day2.isAcceptableOrUnknown(data['day2']!, _day2Meta),
      );
    }
    if (data.containsKey('weeks')) {
      context.handle(
        _weeksMeta,
        weeks.isAcceptableOrUnknown(data['weeks']!, _weeksMeta),
      );
    }
    if (data.containsKey('anchor')) {
      context.handle(
        _anchorMeta,
        anchor.isAcceptableOrUnknown(data['anchor']!, _anchorMeta),
      );
    }
    if (data.containsKey('weekend_before')) {
      context.handle(
        _weekendBeforeMeta,
        weekendBefore.isAcceptableOrUnknown(
          data['weekend_before']!,
          _weekendBeforeMeta,
        ),
      );
    }
    if (data.containsKey('weekend_keep')) {
      context.handle(
        _weekendKeepMeta,
        weekendKeep.isAcceptableOrUnknown(
          data['weekend_keep']!,
          _weekendKeepMeta,
        ),
      );
    }
    if (data.containsKey('defines_period')) {
      context.handle(
        _definesPeriodMeta,
        definesPeriod.isAcceptableOrUnknown(
          data['defines_period']!,
          _definesPeriodMeta,
        ),
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
  PayScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayScheduleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      payee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      amount2Minor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount2_minor'],
      ),
      varies: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}varies'],
      )!,
      rule: $PaySchedulesTable.$converterrule.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rule'],
        )!,
      ),
      day1: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day1'],
      )!,
      day2: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day2'],
      )!,
      weeks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weeks'],
      )!,
      anchor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anchor'],
      ),
      weekendBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}weekend_before'],
      )!,
      weekendKeep: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}weekend_keep'],
      )!,
      definesPeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}defines_period'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PaySchedulesTable createAlias(String alias) {
    return $PaySchedulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PayRule, String, String> $converterrule =
      const EnumNameConverter<PayRule>(PayRule.values);
}

class PayScheduleRow extends DataClass implements Insertable<PayScheduleRow> {
  final int id;
  final int categoryId;
  final int accountId;
  final String? payee;

  /// What the user calls this pay, to tell two earners' apart (v17).
  final String? name;

  /// Positive; with [varies], the least it's likely to be.
  final int amountMinor;

  /// Twice a month: what comes on [day2] when it differs (an advance, then
  /// the rest). Null: the same both days.
  final int? amount2Minor;
  final bool varies;
  final PayRule rule;
  final int day1;
  final int day2;
  final int weeks;
  final String? anchor;
  final bool weekendBefore;

  /// A weekend payday stays on its day, whatever [weekendBefore] says (v9).
  final bool weekendKeep;

  /// The Budget page is viewed by this schedule's pay periods (at most one
  /// is). Since v17 a view only: each set amount's own period is in its
  /// plan ([CategoryPlans.payScheduleId]).
  final bool definesPeriod;
  final int createdAt;
  final int? deletedAt;
  const PayScheduleRow({
    required this.id,
    required this.categoryId,
    required this.accountId,
    this.payee,
    this.name,
    required this.amountMinor,
    this.amount2Minor,
    required this.varies,
    required this.rule,
    required this.day1,
    required this.day2,
    required this.weeks,
    this.anchor,
    required this.weekendBefore,
    required this.weekendKeep,
    required this.definesPeriod,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category_id'] = Variable<int>(categoryId);
    map['account_id'] = Variable<int>(accountId);
    if (!nullToAbsent || payee != null) {
      map['payee'] = Variable<String>(payee);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    if (!nullToAbsent || amount2Minor != null) {
      map['amount2_minor'] = Variable<int>(amount2Minor);
    }
    map['varies'] = Variable<bool>(varies);
    {
      map['rule'] = Variable<String>(
        $PaySchedulesTable.$converterrule.toSql(rule),
      );
    }
    map['day1'] = Variable<int>(day1);
    map['day2'] = Variable<int>(day2);
    map['weeks'] = Variable<int>(weeks);
    if (!nullToAbsent || anchor != null) {
      map['anchor'] = Variable<String>(anchor);
    }
    map['weekend_before'] = Variable<bool>(weekendBefore);
    map['weekend_keep'] = Variable<bool>(weekendKeep);
    map['defines_period'] = Variable<bool>(definesPeriod);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  PaySchedulesCompanion toCompanion(bool nullToAbsent) {
    return PaySchedulesCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      accountId: Value(accountId),
      payee: payee == null && nullToAbsent
          ? const Value.absent()
          : Value(payee),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      amountMinor: Value(amountMinor),
      amount2Minor: amount2Minor == null && nullToAbsent
          ? const Value.absent()
          : Value(amount2Minor),
      varies: Value(varies),
      rule: Value(rule),
      day1: Value(day1),
      day2: Value(day2),
      weeks: Value(weeks),
      anchor: anchor == null && nullToAbsent
          ? const Value.absent()
          : Value(anchor),
      weekendBefore: Value(weekendBefore),
      weekendKeep: Value(weekendKeep),
      definesPeriod: Value(definesPeriod),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PayScheduleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayScheduleRow(
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      accountId: serializer.fromJson<int>(json['accountId']),
      payee: serializer.fromJson<String?>(json['payee']),
      name: serializer.fromJson<String?>(json['name']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      amount2Minor: serializer.fromJson<int?>(json['amount2Minor']),
      varies: serializer.fromJson<bool>(json['varies']),
      rule: $PaySchedulesTable.$converterrule.fromJson(
        serializer.fromJson<String>(json['rule']),
      ),
      day1: serializer.fromJson<int>(json['day1']),
      day2: serializer.fromJson<int>(json['day2']),
      weeks: serializer.fromJson<int>(json['weeks']),
      anchor: serializer.fromJson<String?>(json['anchor']),
      weekendBefore: serializer.fromJson<bool>(json['weekendBefore']),
      weekendKeep: serializer.fromJson<bool>(json['weekendKeep']),
      definesPeriod: serializer.fromJson<bool>(json['definesPeriod']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int>(categoryId),
      'accountId': serializer.toJson<int>(accountId),
      'payee': serializer.toJson<String?>(payee),
      'name': serializer.toJson<String?>(name),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'amount2Minor': serializer.toJson<int?>(amount2Minor),
      'varies': serializer.toJson<bool>(varies),
      'rule': serializer.toJson<String>(
        $PaySchedulesTable.$converterrule.toJson(rule),
      ),
      'day1': serializer.toJson<int>(day1),
      'day2': serializer.toJson<int>(day2),
      'weeks': serializer.toJson<int>(weeks),
      'anchor': serializer.toJson<String?>(anchor),
      'weekendBefore': serializer.toJson<bool>(weekendBefore),
      'weekendKeep': serializer.toJson<bool>(weekendKeep),
      'definesPeriod': serializer.toJson<bool>(definesPeriod),
      'createdAt': serializer.toJson<int>(createdAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  PayScheduleRow copyWith({
    int? id,
    int? categoryId,
    int? accountId,
    Value<String?> payee = const Value.absent(),
    Value<String?> name = const Value.absent(),
    int? amountMinor,
    Value<int?> amount2Minor = const Value.absent(),
    bool? varies,
    PayRule? rule,
    int? day1,
    int? day2,
    int? weeks,
    Value<String?> anchor = const Value.absent(),
    bool? weekendBefore,
    bool? weekendKeep,
    bool? definesPeriod,
    int? createdAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => PayScheduleRow(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    accountId: accountId ?? this.accountId,
    payee: payee.present ? payee.value : this.payee,
    name: name.present ? name.value : this.name,
    amountMinor: amountMinor ?? this.amountMinor,
    amount2Minor: amount2Minor.present ? amount2Minor.value : this.amount2Minor,
    varies: varies ?? this.varies,
    rule: rule ?? this.rule,
    day1: day1 ?? this.day1,
    day2: day2 ?? this.day2,
    weeks: weeks ?? this.weeks,
    anchor: anchor.present ? anchor.value : this.anchor,
    weekendBefore: weekendBefore ?? this.weekendBefore,
    weekendKeep: weekendKeep ?? this.weekendKeep,
    definesPeriod: definesPeriod ?? this.definesPeriod,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PayScheduleRow copyWithCompanion(PaySchedulesCompanion data) {
    return PayScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      payee: data.payee.present ? data.payee.value : this.payee,
      name: data.name.present ? data.name.value : this.name,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      amount2Minor: data.amount2Minor.present
          ? data.amount2Minor.value
          : this.amount2Minor,
      varies: data.varies.present ? data.varies.value : this.varies,
      rule: data.rule.present ? data.rule.value : this.rule,
      day1: data.day1.present ? data.day1.value : this.day1,
      day2: data.day2.present ? data.day2.value : this.day2,
      weeks: data.weeks.present ? data.weeks.value : this.weeks,
      anchor: data.anchor.present ? data.anchor.value : this.anchor,
      weekendBefore: data.weekendBefore.present
          ? data.weekendBefore.value
          : this.weekendBefore,
      weekendKeep: data.weekendKeep.present
          ? data.weekendKeep.value
          : this.weekendKeep,
      definesPeriod: data.definesPeriod.present
          ? data.definesPeriod.value
          : this.definesPeriod,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayScheduleRow(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('payee: $payee, ')
          ..write('name: $name, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('amount2Minor: $amount2Minor, ')
          ..write('varies: $varies, ')
          ..write('rule: $rule, ')
          ..write('day1: $day1, ')
          ..write('day2: $day2, ')
          ..write('weeks: $weeks, ')
          ..write('anchor: $anchor, ')
          ..write('weekendBefore: $weekendBefore, ')
          ..write('weekendKeep: $weekendKeep, ')
          ..write('definesPeriod: $definesPeriod, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    accountId,
    payee,
    name,
    amountMinor,
    amount2Minor,
    varies,
    rule,
    day1,
    day2,
    weeks,
    anchor,
    weekendBefore,
    weekendKeep,
    definesPeriod,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayScheduleRow &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.payee == this.payee &&
          other.name == this.name &&
          other.amountMinor == this.amountMinor &&
          other.amount2Minor == this.amount2Minor &&
          other.varies == this.varies &&
          other.rule == this.rule &&
          other.day1 == this.day1 &&
          other.day2 == this.day2 &&
          other.weeks == this.weeks &&
          other.anchor == this.anchor &&
          other.weekendBefore == this.weekendBefore &&
          other.weekendKeep == this.weekendKeep &&
          other.definesPeriod == this.definesPeriod &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class PaySchedulesCompanion extends UpdateCompanion<PayScheduleRow> {
  final Value<int> id;
  final Value<int> categoryId;
  final Value<int> accountId;
  final Value<String?> payee;
  final Value<String?> name;
  final Value<int> amountMinor;
  final Value<int?> amount2Minor;
  final Value<bool> varies;
  final Value<PayRule> rule;
  final Value<int> day1;
  final Value<int> day2;
  final Value<int> weeks;
  final Value<String?> anchor;
  final Value<bool> weekendBefore;
  final Value<bool> weekendKeep;
  final Value<bool> definesPeriod;
  final Value<int> createdAt;
  final Value<int?> deletedAt;
  const PaySchedulesCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.payee = const Value.absent(),
    this.name = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.amount2Minor = const Value.absent(),
    this.varies = const Value.absent(),
    this.rule = const Value.absent(),
    this.day1 = const Value.absent(),
    this.day2 = const Value.absent(),
    this.weeks = const Value.absent(),
    this.anchor = const Value.absent(),
    this.weekendBefore = const Value.absent(),
    this.weekendKeep = const Value.absent(),
    this.definesPeriod = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PaySchedulesCompanion.insert({
    this.id = const Value.absent(),
    required int categoryId,
    required int accountId,
    this.payee = const Value.absent(),
    this.name = const Value.absent(),
    required int amountMinor,
    this.amount2Minor = const Value.absent(),
    this.varies = const Value.absent(),
    required PayRule rule,
    this.day1 = const Value.absent(),
    this.day2 = const Value.absent(),
    this.weeks = const Value.absent(),
    this.anchor = const Value.absent(),
    this.weekendBefore = const Value.absent(),
    this.weekendKeep = const Value.absent(),
    this.definesPeriod = const Value.absent(),
    required int createdAt,
    this.deletedAt = const Value.absent(),
  }) : categoryId = Value(categoryId),
       accountId = Value(accountId),
       amountMinor = Value(amountMinor),
       rule = Value(rule),
       createdAt = Value(createdAt);
  static Insertable<PayScheduleRow> custom({
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<int>? accountId,
    Expression<String>? payee,
    Expression<String>? name,
    Expression<int>? amountMinor,
    Expression<int>? amount2Minor,
    Expression<bool>? varies,
    Expression<String>? rule,
    Expression<int>? day1,
    Expression<int>? day2,
    Expression<int>? weeks,
    Expression<String>? anchor,
    Expression<bool>? weekendBefore,
    Expression<bool>? weekendKeep,
    Expression<bool>? definesPeriod,
    Expression<int>? createdAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (payee != null) 'payee': payee,
      if (name != null) 'name': name,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (amount2Minor != null) 'amount2_minor': amount2Minor,
      if (varies != null) 'varies': varies,
      if (rule != null) 'rule': rule,
      if (day1 != null) 'day1': day1,
      if (day2 != null) 'day2': day2,
      if (weeks != null) 'weeks': weeks,
      if (anchor != null) 'anchor': anchor,
      if (weekendBefore != null) 'weekend_before': weekendBefore,
      if (weekendKeep != null) 'weekend_keep': weekendKeep,
      if (definesPeriod != null) 'defines_period': definesPeriod,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PaySchedulesCompanion copyWith({
    Value<int>? id,
    Value<int>? categoryId,
    Value<int>? accountId,
    Value<String?>? payee,
    Value<String?>? name,
    Value<int>? amountMinor,
    Value<int?>? amount2Minor,
    Value<bool>? varies,
    Value<PayRule>? rule,
    Value<int>? day1,
    Value<int>? day2,
    Value<int>? weeks,
    Value<String?>? anchor,
    Value<bool>? weekendBefore,
    Value<bool>? weekendKeep,
    Value<bool>? definesPeriod,
    Value<int>? createdAt,
    Value<int?>? deletedAt,
  }) {
    return PaySchedulesCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      payee: payee ?? this.payee,
      name: name ?? this.name,
      amountMinor: amountMinor ?? this.amountMinor,
      amount2Minor: amount2Minor ?? this.amount2Minor,
      varies: varies ?? this.varies,
      rule: rule ?? this.rule,
      day1: day1 ?? this.day1,
      day2: day2 ?? this.day2,
      weeks: weeks ?? this.weeks,
      anchor: anchor ?? this.anchor,
      weekendBefore: weekendBefore ?? this.weekendBefore,
      weekendKeep: weekendKeep ?? this.weekendKeep,
      definesPeriod: definesPeriod ?? this.definesPeriod,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (payee.present) {
      map['payee'] = Variable<String>(payee.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (amount2Minor.present) {
      map['amount2_minor'] = Variable<int>(amount2Minor.value);
    }
    if (varies.present) {
      map['varies'] = Variable<bool>(varies.value);
    }
    if (rule.present) {
      map['rule'] = Variable<String>(
        $PaySchedulesTable.$converterrule.toSql(rule.value),
      );
    }
    if (day1.present) {
      map['day1'] = Variable<int>(day1.value);
    }
    if (day2.present) {
      map['day2'] = Variable<int>(day2.value);
    }
    if (weeks.present) {
      map['weeks'] = Variable<int>(weeks.value);
    }
    if (anchor.present) {
      map['anchor'] = Variable<String>(anchor.value);
    }
    if (weekendBefore.present) {
      map['weekend_before'] = Variable<bool>(weekendBefore.value);
    }
    if (weekendKeep.present) {
      map['weekend_keep'] = Variable<bool>(weekendKeep.value);
    }
    if (definesPeriod.present) {
      map['defines_period'] = Variable<bool>(definesPeriod.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaySchedulesCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('payee: $payee, ')
          ..write('name: $name, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('amount2Minor: $amount2Minor, ')
          ..write('varies: $varies, ')
          ..write('rule: $rule, ')
          ..write('day1: $day1, ')
          ..write('day2: $day2, ')
          ..write('weeks: $weeks, ')
          ..write('anchor: $anchor, ')
          ..write('weekendBefore: $weekendBefore, ')
          ..write('weekendKeep: $weekendKeep, ')
          ..write('definesPeriod: $definesPeriod, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
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
    clientDefault: newRowId,
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
    clientDefault: newRowId,
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
  static const VerificationMeta _payScheduleIdMeta = const VerificationMeta(
    'payScheduleId',
  );
  @override
  late final GeneratedColumn<int> payScheduleId = GeneratedColumn<int>(
    'pay_schedule_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pay_schedules (id)',
    ),
  );
  static const VerificationMeta _planCategoryIdMeta = const VerificationMeta(
    'planCategoryId',
  );
  @override
  late final GeneratedColumn<int> planCategoryId = GeneratedColumn<int>(
    'plan_category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _madeHowMeta = const VerificationMeta(
    'madeHow',
  );
  @override
  late final GeneratedColumn<String> madeHow = GeneratedColumn<String>(
    'made_how',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _madeOnMeta = const VerificationMeta('madeOn');
  @override
  late final GeneratedColumn<String> madeOn = GeneratedColumn<String>(
    'made_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    payScheduleId,
    planCategoryId,
    madeHow,
    madeOn,
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
    if (data.containsKey('pay_schedule_id')) {
      context.handle(
        _payScheduleIdMeta,
        payScheduleId.isAcceptableOrUnknown(
          data['pay_schedule_id']!,
          _payScheduleIdMeta,
        ),
      );
    }
    if (data.containsKey('plan_category_id')) {
      context.handle(
        _planCategoryIdMeta,
        planCategoryId.isAcceptableOrUnknown(
          data['plan_category_id']!,
          _planCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('made_how')) {
      context.handle(
        _madeHowMeta,
        madeHow.isAcceptableOrUnknown(data['made_how']!, _madeHowMeta),
      );
    }
    if (data.containsKey('made_on')) {
      context.handle(
        _madeOnMeta,
        madeOn.isAcceptableOrUnknown(data['made_on']!, _madeOnMeta),
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
      payScheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pay_schedule_id'],
      ),
      planCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_category_id'],
      ),
      madeHow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}made_how'],
      ),
      madeOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}made_on'],
      ),
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

  /// Unused since v8: the key is on each account's entry.
  final String? importKey;
  final bool scheduled;

  /// A payday a pay schedule scheduled.
  final int? payScheduleId;

  /// A bill a category's plan scheduled (rule 27), by the category.
  final int? planCategoryId;

  /// How the row came to be, one of [MadeHow]'s words, and the id of the
  /// computer it was typed or imported on, or of the phone. Both null for
  /// a row from before v21, which nobody knows. Never changed afterwards,
  /// and no part of what two computers compare (ADR 0005, "Where a row came
  /// from").
  final String? madeHow;
  final String? madeOn;
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
    this.payScheduleId,
    this.planCategoryId,
    this.madeHow,
    this.madeOn,
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
    if (!nullToAbsent || payScheduleId != null) {
      map['pay_schedule_id'] = Variable<int>(payScheduleId);
    }
    if (!nullToAbsent || planCategoryId != null) {
      map['plan_category_id'] = Variable<int>(planCategoryId);
    }
    if (!nullToAbsent || madeHow != null) {
      map['made_how'] = Variable<String>(madeHow);
    }
    if (!nullToAbsent || madeOn != null) {
      map['made_on'] = Variable<String>(madeOn);
    }
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
      payScheduleId: payScheduleId == null && nullToAbsent
          ? const Value.absent()
          : Value(payScheduleId),
      planCategoryId: planCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(planCategoryId),
      madeHow: madeHow == null && nullToAbsent
          ? const Value.absent()
          : Value(madeHow),
      madeOn: madeOn == null && nullToAbsent
          ? const Value.absent()
          : Value(madeOn),
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
      payScheduleId: serializer.fromJson<int?>(json['payScheduleId']),
      planCategoryId: serializer.fromJson<int?>(json['planCategoryId']),
      madeHow: serializer.fromJson<String?>(json['madeHow']),
      madeOn: serializer.fromJson<String?>(json['madeOn']),
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
      'payScheduleId': serializer.toJson<int?>(payScheduleId),
      'planCategoryId': serializer.toJson<int?>(planCategoryId),
      'madeHow': serializer.toJson<String?>(madeHow),
      'madeOn': serializer.toJson<String?>(madeOn),
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
    Value<int?> payScheduleId = const Value.absent(),
    Value<int?> planCategoryId = const Value.absent(),
    Value<String?> madeHow = const Value.absent(),
    Value<String?> madeOn = const Value.absent(),
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
    payScheduleId: payScheduleId.present
        ? payScheduleId.value
        : this.payScheduleId,
    planCategoryId: planCategoryId.present
        ? planCategoryId.value
        : this.planCategoryId,
    madeHow: madeHow.present ? madeHow.value : this.madeHow,
    madeOn: madeOn.present ? madeOn.value : this.madeOn,
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
      payScheduleId: data.payScheduleId.present
          ? data.payScheduleId.value
          : this.payScheduleId,
      planCategoryId: data.planCategoryId.present
          ? data.planCategoryId.value
          : this.planCategoryId,
      madeHow: data.madeHow.present ? data.madeHow.value : this.madeHow,
      madeOn: data.madeOn.present ? data.madeOn.value : this.madeOn,
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
          ..write('payScheduleId: $payScheduleId, ')
          ..write('planCategoryId: $planCategoryId, ')
          ..write('madeHow: $madeHow, ')
          ..write('madeOn: $madeOn, ')
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
    payScheduleId,
    planCategoryId,
    madeHow,
    madeOn,
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
          other.payScheduleId == this.payScheduleId &&
          other.planCategoryId == this.planCategoryId &&
          other.madeHow == this.madeHow &&
          other.madeOn == this.madeOn &&
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
  final Value<int?> payScheduleId;
  final Value<int?> planCategoryId;
  final Value<String?> madeHow;
  final Value<String?> madeOn;
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
    this.payScheduleId = const Value.absent(),
    this.planCategoryId = const Value.absent(),
    this.madeHow = const Value.absent(),
    this.madeOn = const Value.absent(),
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
    this.payScheduleId = const Value.absent(),
    this.planCategoryId = const Value.absent(),
    this.madeHow = const Value.absent(),
    this.madeOn = const Value.absent(),
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
    Expression<int>? payScheduleId,
    Expression<int>? planCategoryId,
    Expression<String>? madeHow,
    Expression<String>? madeOn,
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
      if (payScheduleId != null) 'pay_schedule_id': payScheduleId,
      if (planCategoryId != null) 'plan_category_id': planCategoryId,
      if (madeHow != null) 'made_how': madeHow,
      if (madeOn != null) 'made_on': madeOn,
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
    Value<int?>? payScheduleId,
    Value<int?>? planCategoryId,
    Value<String?>? madeHow,
    Value<String?>? madeOn,
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
      payScheduleId: payScheduleId ?? this.payScheduleId,
      planCategoryId: planCategoryId ?? this.planCategoryId,
      madeHow: madeHow ?? this.madeHow,
      madeOn: madeOn ?? this.madeOn,
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
    if (payScheduleId.present) {
      map['pay_schedule_id'] = Variable<int>(payScheduleId.value);
    }
    if (planCategoryId.present) {
      map['plan_category_id'] = Variable<int>(planCategoryId.value);
    }
    if (madeHow.present) {
      map['made_how'] = Variable<String>(madeHow.value);
    }
    if (madeOn.present) {
      map['made_on'] = Variable<String>(madeOn.value);
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
          ..write('payScheduleId: $payScheduleId, ')
          ..write('planCategoryId: $planCategoryId, ')
          ..write('madeHow: $madeHow, ')
          ..write('madeOn: $madeOn, ')
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
    clientDefault: newRowId,
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
    clientDefault: newRowId,
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
    importKey,
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
    if (data.containsKey('import_key')) {
      context.handle(
        _importKeyMeta,
        importKey.isAcceptableOrUnknown(data['import_key']!, _importKeyMeta),
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
      importKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_key'],
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

  /// The bank row this entry came from or was matched to (ADR 0002). On the
  /// entry, not the transaction, so each side of a transfer matches its own
  /// bank's file. Unique through `entries_import_key` (SQLite can't add a
  /// unique column to a table that exists).
  final String? importKey;
  const EntryRow({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.amountMinor,
    required this.currency,
    this.rate,
    required this.cleared,
    this.reconciliationId,
    this.importKey,
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
    if (!nullToAbsent || importKey != null) {
      map['import_key'] = Variable<String>(importKey);
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
      importKey: importKey == null && nullToAbsent
          ? const Value.absent()
          : Value(importKey),
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
      importKey: serializer.fromJson<String?>(json['importKey']),
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
      'importKey': serializer.toJson<String?>(importKey),
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
    Value<String?> importKey = const Value.absent(),
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
    importKey: importKey.present ? importKey.value : this.importKey,
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
      importKey: data.importKey.present ? data.importKey.value : this.importKey,
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
          ..write('reconciliationId: $reconciliationId, ')
          ..write('importKey: $importKey')
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
    importKey,
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
          other.reconciliationId == this.reconciliationId &&
          other.importKey == this.importKey);
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
  final Value<String?> importKey;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.rate = const Value.absent(),
    this.cleared = const Value.absent(),
    this.reconciliationId = const Value.absent(),
    this.importKey = const Value.absent(),
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
    this.importKey = const Value.absent(),
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
    Expression<String>? importKey,
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
      if (importKey != null) 'import_key': importKey,
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
    Value<String?>? importKey,
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
      importKey: importKey ?? this.importKey,
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
    if (importKey.present) {
      map['import_key'] = Variable<String>(importKey.value);
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
          ..write('reconciliationId: $reconciliationId, ')
          ..write('importKey: $importKey')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, PreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferenceRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class PreferenceRow extends DataClass implements Insertable<PreferenceRow> {
  final String key;
  final String value;
  const PreferenceRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory PreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferenceRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  PreferenceRow copyWith({String? key, String? value}) =>
      PreferenceRow(key: key ?? this.key, value: value ?? this.value);
  PreferenceRow copyWithCompanion(PreferencesCompanion data) {
    return PreferenceRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferenceRow &&
          other.key == this.key &&
          other.value == this.value);
}

class PreferencesCompanion extends UpdateCompanion<PreferenceRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<PreferenceRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetAmountsTable extends BudgetAmounts
    with TableInfo<$BudgetAmountsTable, BudgetAmountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetAmountsTable(this.attachedDatabase, [this._alias]);
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
    clientDefault: newRowId,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
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
  @override
  List<GeneratedColumn> get $columns => [id, categoryId, date, amountMinor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget_amounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetAmountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetAmountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetAmountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
    );
  }

  @override
  $BudgetAmountsTable createAlias(String alias) {
    return $BudgetAmountsTable(attachedDatabase, alias);
  }
}

class BudgetAmountRow extends DataClass implements Insertable<BudgetAmountRow> {
  final int id;
  final int categoryId;

  /// Calendar date as `YYYY-MM-DD`: the first day of its period.
  final String date;

  /// Negative takes money back out.
  final int amountMinor;
  const BudgetAmountRow({
    required this.id,
    required this.categoryId,
    required this.date,
    required this.amountMinor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category_id'] = Variable<int>(categoryId);
    map['date'] = Variable<String>(date);
    map['amount_minor'] = Variable<int>(amountMinor);
    return map;
  }

  BudgetAmountsCompanion toCompanion(bool nullToAbsent) {
    return BudgetAmountsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      date: Value(date),
      amountMinor: Value(amountMinor),
    );
  }

  factory BudgetAmountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetAmountRow(
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      date: serializer.fromJson<String>(json['date']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int>(categoryId),
      'date': serializer.toJson<String>(date),
      'amountMinor': serializer.toJson<int>(amountMinor),
    };
  }

  BudgetAmountRow copyWith({
    int? id,
    int? categoryId,
    String? date,
    int? amountMinor,
  }) => BudgetAmountRow(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    date: date ?? this.date,
    amountMinor: amountMinor ?? this.amountMinor,
  );
  BudgetAmountRow copyWithCompanion(BudgetAmountsCompanion data) {
    return BudgetAmountRow(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      date: data.date.present ? data.date.value : this.date,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetAmountRow(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('date: $date, ')
          ..write('amountMinor: $amountMinor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoryId, date, amountMinor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetAmountRow &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.date == this.date &&
          other.amountMinor == this.amountMinor);
}

class BudgetAmountsCompanion extends UpdateCompanion<BudgetAmountRow> {
  final Value<int> id;
  final Value<int> categoryId;
  final Value<String> date;
  final Value<int> amountMinor;
  const BudgetAmountsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.date = const Value.absent(),
    this.amountMinor = const Value.absent(),
  });
  BudgetAmountsCompanion.insert({
    this.id = const Value.absent(),
    required int categoryId,
    required String date,
    required int amountMinor,
  }) : categoryId = Value(categoryId),
       date = Value(date),
       amountMinor = Value(amountMinor);
  static Insertable<BudgetAmountRow> custom({
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<String>? date,
    Expression<int>? amountMinor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (date != null) 'date': date,
      if (amountMinor != null) 'amount_minor': amountMinor,
    });
  }

  BudgetAmountsCompanion copyWith({
    Value<int>? id,
    Value<int>? categoryId,
    Value<String>? date,
    Value<int>? amountMinor,
  }) {
    return BudgetAmountsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      amountMinor: amountMinor ?? this.amountMinor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetAmountsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('date: $date, ')
          ..write('amountMinor: $amountMinor')
          ..write(')'))
        .toString();
  }
}

class $CategoryPlansTable extends CategoryPlans
    with TableInfo<$CategoryPlansTable, CategoryPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlanKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PlanKind>($CategoryPlansTable.$converterkind);
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
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<String> start = GeneratedColumn<String>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<String> due = GeneratedColumn<String>(
    'due',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _everyMonthsMeta = const VerificationMeta(
    'everyMonths',
  );
  @override
  late final GeneratedColumn<int> everyMonths = GeneratedColumn<int>(
    'every_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _everyDaysMeta = const VerificationMeta(
    'everyDays',
  );
  @override
  late final GeneratedColumn<int> everyDays = GeneratedColumn<int>(
    'every_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _onDatesMeta = const VerificationMeta(
    'onDates',
  );
  @override
  late final GeneratedColumn<String> onDates = GeneratedColumn<String>(
    'on_dates',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payScheduleIdMeta = const VerificationMeta(
    'payScheduleId',
  );
  @override
  late final GeneratedColumn<int> payScheduleId = GeneratedColumn<int>(
    'pay_schedule_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pay_schedules (id)',
    ),
  );
  static const VerificationMeta _daysAfterPayMeta = const VerificationMeta(
    'daysAfterPay',
  );
  @override
  late final GeneratedColumn<int> daysAfterPay = GeneratedColumn<int>(
    'days_after_pay',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PayWeekend, String> weekend =
      GeneratedColumn<String>(
        'weekend',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('keep'),
      ).withConverter<PayWeekend>($CategoryPlansTable.$converterweekend);
  static const VerificationMeta _weekdaysMeta = const VerificationMeta(
    'weekdays',
  );
  @override
  late final GeneratedColumn<String> weekdays = GeneratedColumn<String>(
    'weekdays',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nthMeta = const VerificationMeta('nth');
  @override
  late final GeneratedColumn<int> nth = GeneratedColumn<int>(
    'nth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nthWeekdayMeta = const VerificationMeta(
    'nthWeekday',
  );
  @override
  late final GeneratedColumn<int> nthWeekday = GeneratedColumn<int>(
    'nth_weekday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endCountMeta = const VerificationMeta(
    'endCount',
  );
  @override
  late final GeneratedColumn<int> endCount = GeneratedColumn<int>(
    'end_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rolloverMeta = const VerificationMeta(
    'rollover',
  );
  @override
  late final GeneratedColumn<bool> rollover = GeneratedColumn<bool>(
    'rollover',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("rollover" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _upToMinorMeta = const VerificationMeta(
    'upToMinor',
  );
  @override
  late final GeneratedColumn<int> upToMinor = GeneratedColumn<int>(
    'up_to_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidFromIdMeta = const VerificationMeta(
    'paidFromId',
  );
  @override
  late final GeneratedColumn<int> paidFromId = GeneratedColumn<int>(
    'paid_from_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _onceMeta = const VerificationMeta('once');
  @override
  late final GeneratedColumn<String> once = GeneratedColumn<String>(
    'once',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    categoryId,
    kind,
    amountMinor,
    start,
    due,
    everyMonths,
    everyDays,
    onDates,
    payScheduleId,
    daysAfterPay,
    weekend,
    weekdays,
    nth,
    nthWeekday,
    endDate,
    endCount,
    rollover,
    upToMinor,
    paidFromId,
    once,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
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
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    }
    if (data.containsKey('every_months')) {
      context.handle(
        _everyMonthsMeta,
        everyMonths.isAcceptableOrUnknown(
          data['every_months']!,
          _everyMonthsMeta,
        ),
      );
    }
    if (data.containsKey('every_days')) {
      context.handle(
        _everyDaysMeta,
        everyDays.isAcceptableOrUnknown(data['every_days']!, _everyDaysMeta),
      );
    }
    if (data.containsKey('on_dates')) {
      context.handle(
        _onDatesMeta,
        onDates.isAcceptableOrUnknown(data['on_dates']!, _onDatesMeta),
      );
    }
    if (data.containsKey('pay_schedule_id')) {
      context.handle(
        _payScheduleIdMeta,
        payScheduleId.isAcceptableOrUnknown(
          data['pay_schedule_id']!,
          _payScheduleIdMeta,
        ),
      );
    }
    if (data.containsKey('days_after_pay')) {
      context.handle(
        _daysAfterPayMeta,
        daysAfterPay.isAcceptableOrUnknown(
          data['days_after_pay']!,
          _daysAfterPayMeta,
        ),
      );
    }
    if (data.containsKey('weekdays')) {
      context.handle(
        _weekdaysMeta,
        weekdays.isAcceptableOrUnknown(data['weekdays']!, _weekdaysMeta),
      );
    }
    if (data.containsKey('nth')) {
      context.handle(
        _nthMeta,
        nth.isAcceptableOrUnknown(data['nth']!, _nthMeta),
      );
    }
    if (data.containsKey('nth_weekday')) {
      context.handle(
        _nthWeekdayMeta,
        nthWeekday.isAcceptableOrUnknown(data['nth_weekday']!, _nthWeekdayMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('end_count')) {
      context.handle(
        _endCountMeta,
        endCount.isAcceptableOrUnknown(data['end_count']!, _endCountMeta),
      );
    }
    if (data.containsKey('rollover')) {
      context.handle(
        _rolloverMeta,
        rollover.isAcceptableOrUnknown(data['rollover']!, _rolloverMeta),
      );
    }
    if (data.containsKey('up_to_minor')) {
      context.handle(
        _upToMinorMeta,
        upToMinor.isAcceptableOrUnknown(data['up_to_minor']!, _upToMinorMeta),
      );
    }
    if (data.containsKey('paid_from_id')) {
      context.handle(
        _paidFromIdMeta,
        paidFromId.isAcceptableOrUnknown(
          data['paid_from_id']!,
          _paidFromIdMeta,
        ),
      );
    }
    if (data.containsKey('once')) {
      context.handle(
        _onceMeta,
        once.isAcceptableOrUnknown(data['once']!, _onceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId};
  @override
  CategoryPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryPlanRow(
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      kind: $CategoryPlansTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start'],
      )!,
      due: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due'],
      ),
      everyMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}every_months'],
      ),
      everyDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}every_days'],
      ),
      onDates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}on_dates'],
      ),
      payScheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pay_schedule_id'],
      ),
      daysAfterPay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_after_pay'],
      )!,
      weekend: $CategoryPlansTable.$converterweekend.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}weekend'],
        )!,
      ),
      weekdays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weekdays'],
      ),
      nth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nth'],
      ),
      nthWeekday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}nth_weekday'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
      endCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_count'],
      ),
      rollover: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}rollover'],
      )!,
      upToMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}up_to_minor'],
      ),
      paidFromId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_from_id'],
      ),
      once: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}once'],
      ),
    );
  }

  @override
  $CategoryPlansTable createAlias(String alias) {
    return $CategoryPlansTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PlanKind, String, String> $converterkind =
      const EnumNameConverter<PlanKind>(PlanKind.values);
  static JsonTypeConverter2<PayWeekend, String, String> $converterweekend =
      const EnumNameConverter<PayWeekend>(PayWeekend.values);
}

class CategoryPlanRow extends DataClass implements Insertable<CategoryPlanRow> {
  final int categoryId;
  final PlanKind kind;

  /// Each period's amount, or the amount wanted by the date, by [kind].
  final int amountMinor;

  /// Calendar date as `YYYY-MM-DD`: the day the plan was made.
  final String start;

  /// The date, or the first of them when it repeats.
  final String? due;

  /// It comes again every this many months; null unless by months.
  final int? everyMonths;

  /// Every this many days (7 a week); null unless by days (v15).
  final int? everyDays;

  /// On these dates each year, `MM-DD,MM-DD`; null unless so (v15).
  final String? onDates;

  /// A bill: every payday of this schedule, [daysAfterPay] days after
  /// (v15). A set amount: per this schedule's pay period, not per month
  /// (v17).
  final int? payScheduleId;
  final int daysAfterPay;

  /// A date on a weekend: before, after or keep (v15).
  final PayWeekend weekend;

  /// Every so many weeks, on these weekdays, `1,4` (Monday 1); null
  /// unless chosen (v16, Custom…).
  final String? weekdays;

  /// Every so many months: the nth weekday of the month (1–4, -1 the
  /// last) and which weekday (Monday 1); null unless chosen (v16).
  final int? nth;
  final int? nthWeekday;

  /// No bill after this date `YYYY-MM-DD`, or after this many (v16).
  final String? endDate;
  final int? endCount;

  /// Each period: what's left stays in the category.
  final bool rollover;

  /// Each period, carrying over: stop asking once it holds this much.
  final int? upToMinor;

  /// The account a dated plan's bill is paid from: it's kept scheduled
  /// there.
  final int? paidFromId;

  /// A set amount's single periods: `YYYY-MM-DD=amount,…`, by the day each
  /// starts, what that one asks for instead; 0 skips it (v22, #100).
  final String? once;
  const CategoryPlanRow({
    required this.categoryId,
    required this.kind,
    required this.amountMinor,
    required this.start,
    this.due,
    this.everyMonths,
    this.everyDays,
    this.onDates,
    this.payScheduleId,
    required this.daysAfterPay,
    required this.weekend,
    this.weekdays,
    this.nth,
    this.nthWeekday,
    this.endDate,
    this.endCount,
    required this.rollover,
    this.upToMinor,
    this.paidFromId,
    this.once,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<int>(categoryId);
    {
      map['kind'] = Variable<String>(
        $CategoryPlansTable.$converterkind.toSql(kind),
      );
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['start'] = Variable<String>(start);
    if (!nullToAbsent || due != null) {
      map['due'] = Variable<String>(due);
    }
    if (!nullToAbsent || everyMonths != null) {
      map['every_months'] = Variable<int>(everyMonths);
    }
    if (!nullToAbsent || everyDays != null) {
      map['every_days'] = Variable<int>(everyDays);
    }
    if (!nullToAbsent || onDates != null) {
      map['on_dates'] = Variable<String>(onDates);
    }
    if (!nullToAbsent || payScheduleId != null) {
      map['pay_schedule_id'] = Variable<int>(payScheduleId);
    }
    map['days_after_pay'] = Variable<int>(daysAfterPay);
    {
      map['weekend'] = Variable<String>(
        $CategoryPlansTable.$converterweekend.toSql(weekend),
      );
    }
    if (!nullToAbsent || weekdays != null) {
      map['weekdays'] = Variable<String>(weekdays);
    }
    if (!nullToAbsent || nth != null) {
      map['nth'] = Variable<int>(nth);
    }
    if (!nullToAbsent || nthWeekday != null) {
      map['nth_weekday'] = Variable<int>(nthWeekday);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    if (!nullToAbsent || endCount != null) {
      map['end_count'] = Variable<int>(endCount);
    }
    map['rollover'] = Variable<bool>(rollover);
    if (!nullToAbsent || upToMinor != null) {
      map['up_to_minor'] = Variable<int>(upToMinor);
    }
    if (!nullToAbsent || paidFromId != null) {
      map['paid_from_id'] = Variable<int>(paidFromId);
    }
    if (!nullToAbsent || once != null) {
      map['once'] = Variable<String>(once);
    }
    return map;
  }

  CategoryPlansCompanion toCompanion(bool nullToAbsent) {
    return CategoryPlansCompanion(
      categoryId: Value(categoryId),
      kind: Value(kind),
      amountMinor: Value(amountMinor),
      start: Value(start),
      due: due == null && nullToAbsent ? const Value.absent() : Value(due),
      everyMonths: everyMonths == null && nullToAbsent
          ? const Value.absent()
          : Value(everyMonths),
      everyDays: everyDays == null && nullToAbsent
          ? const Value.absent()
          : Value(everyDays),
      onDates: onDates == null && nullToAbsent
          ? const Value.absent()
          : Value(onDates),
      payScheduleId: payScheduleId == null && nullToAbsent
          ? const Value.absent()
          : Value(payScheduleId),
      daysAfterPay: Value(daysAfterPay),
      weekend: Value(weekend),
      weekdays: weekdays == null && nullToAbsent
          ? const Value.absent()
          : Value(weekdays),
      nth: nth == null && nullToAbsent ? const Value.absent() : Value(nth),
      nthWeekday: nthWeekday == null && nullToAbsent
          ? const Value.absent()
          : Value(nthWeekday),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      endCount: endCount == null && nullToAbsent
          ? const Value.absent()
          : Value(endCount),
      rollover: Value(rollover),
      upToMinor: upToMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(upToMinor),
      paidFromId: paidFromId == null && nullToAbsent
          ? const Value.absent()
          : Value(paidFromId),
      once: once == null && nullToAbsent ? const Value.absent() : Value(once),
    );
  }

  factory CategoryPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryPlanRow(
      categoryId: serializer.fromJson<int>(json['categoryId']),
      kind: $CategoryPlansTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      start: serializer.fromJson<String>(json['start']),
      due: serializer.fromJson<String?>(json['due']),
      everyMonths: serializer.fromJson<int?>(json['everyMonths']),
      everyDays: serializer.fromJson<int?>(json['everyDays']),
      onDates: serializer.fromJson<String?>(json['onDates']),
      payScheduleId: serializer.fromJson<int?>(json['payScheduleId']),
      daysAfterPay: serializer.fromJson<int>(json['daysAfterPay']),
      weekend: $CategoryPlansTable.$converterweekend.fromJson(
        serializer.fromJson<String>(json['weekend']),
      ),
      weekdays: serializer.fromJson<String?>(json['weekdays']),
      nth: serializer.fromJson<int?>(json['nth']),
      nthWeekday: serializer.fromJson<int?>(json['nthWeekday']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      endCount: serializer.fromJson<int?>(json['endCount']),
      rollover: serializer.fromJson<bool>(json['rollover']),
      upToMinor: serializer.fromJson<int?>(json['upToMinor']),
      paidFromId: serializer.fromJson<int?>(json['paidFromId']),
      once: serializer.fromJson<String?>(json['once']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<int>(categoryId),
      'kind': serializer.toJson<String>(
        $CategoryPlansTable.$converterkind.toJson(kind),
      ),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'start': serializer.toJson<String>(start),
      'due': serializer.toJson<String?>(due),
      'everyMonths': serializer.toJson<int?>(everyMonths),
      'everyDays': serializer.toJson<int?>(everyDays),
      'onDates': serializer.toJson<String?>(onDates),
      'payScheduleId': serializer.toJson<int?>(payScheduleId),
      'daysAfterPay': serializer.toJson<int>(daysAfterPay),
      'weekend': serializer.toJson<String>(
        $CategoryPlansTable.$converterweekend.toJson(weekend),
      ),
      'weekdays': serializer.toJson<String?>(weekdays),
      'nth': serializer.toJson<int?>(nth),
      'nthWeekday': serializer.toJson<int?>(nthWeekday),
      'endDate': serializer.toJson<String?>(endDate),
      'endCount': serializer.toJson<int?>(endCount),
      'rollover': serializer.toJson<bool>(rollover),
      'upToMinor': serializer.toJson<int?>(upToMinor),
      'paidFromId': serializer.toJson<int?>(paidFromId),
      'once': serializer.toJson<String?>(once),
    };
  }

  CategoryPlanRow copyWith({
    int? categoryId,
    PlanKind? kind,
    int? amountMinor,
    String? start,
    Value<String?> due = const Value.absent(),
    Value<int?> everyMonths = const Value.absent(),
    Value<int?> everyDays = const Value.absent(),
    Value<String?> onDates = const Value.absent(),
    Value<int?> payScheduleId = const Value.absent(),
    int? daysAfterPay,
    PayWeekend? weekend,
    Value<String?> weekdays = const Value.absent(),
    Value<int?> nth = const Value.absent(),
    Value<int?> nthWeekday = const Value.absent(),
    Value<String?> endDate = const Value.absent(),
    Value<int?> endCount = const Value.absent(),
    bool? rollover,
    Value<int?> upToMinor = const Value.absent(),
    Value<int?> paidFromId = const Value.absent(),
    Value<String?> once = const Value.absent(),
  }) => CategoryPlanRow(
    categoryId: categoryId ?? this.categoryId,
    kind: kind ?? this.kind,
    amountMinor: amountMinor ?? this.amountMinor,
    start: start ?? this.start,
    due: due.present ? due.value : this.due,
    everyMonths: everyMonths.present ? everyMonths.value : this.everyMonths,
    everyDays: everyDays.present ? everyDays.value : this.everyDays,
    onDates: onDates.present ? onDates.value : this.onDates,
    payScheduleId: payScheduleId.present
        ? payScheduleId.value
        : this.payScheduleId,
    daysAfterPay: daysAfterPay ?? this.daysAfterPay,
    weekend: weekend ?? this.weekend,
    weekdays: weekdays.present ? weekdays.value : this.weekdays,
    nth: nth.present ? nth.value : this.nth,
    nthWeekday: nthWeekday.present ? nthWeekday.value : this.nthWeekday,
    endDate: endDate.present ? endDate.value : this.endDate,
    endCount: endCount.present ? endCount.value : this.endCount,
    rollover: rollover ?? this.rollover,
    upToMinor: upToMinor.present ? upToMinor.value : this.upToMinor,
    paidFromId: paidFromId.present ? paidFromId.value : this.paidFromId,
    once: once.present ? once.value : this.once,
  );
  CategoryPlanRow copyWithCompanion(CategoryPlansCompanion data) {
    return CategoryPlanRow(
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      start: data.start.present ? data.start.value : this.start,
      due: data.due.present ? data.due.value : this.due,
      everyMonths: data.everyMonths.present
          ? data.everyMonths.value
          : this.everyMonths,
      everyDays: data.everyDays.present ? data.everyDays.value : this.everyDays,
      onDates: data.onDates.present ? data.onDates.value : this.onDates,
      payScheduleId: data.payScheduleId.present
          ? data.payScheduleId.value
          : this.payScheduleId,
      daysAfterPay: data.daysAfterPay.present
          ? data.daysAfterPay.value
          : this.daysAfterPay,
      weekend: data.weekend.present ? data.weekend.value : this.weekend,
      weekdays: data.weekdays.present ? data.weekdays.value : this.weekdays,
      nth: data.nth.present ? data.nth.value : this.nth,
      nthWeekday: data.nthWeekday.present
          ? data.nthWeekday.value
          : this.nthWeekday,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      endCount: data.endCount.present ? data.endCount.value : this.endCount,
      rollover: data.rollover.present ? data.rollover.value : this.rollover,
      upToMinor: data.upToMinor.present ? data.upToMinor.value : this.upToMinor,
      paidFromId: data.paidFromId.present
          ? data.paidFromId.value
          : this.paidFromId,
      once: data.once.present ? data.once.value : this.once,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryPlanRow(')
          ..write('categoryId: $categoryId, ')
          ..write('kind: $kind, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('start: $start, ')
          ..write('due: $due, ')
          ..write('everyMonths: $everyMonths, ')
          ..write('everyDays: $everyDays, ')
          ..write('onDates: $onDates, ')
          ..write('payScheduleId: $payScheduleId, ')
          ..write('daysAfterPay: $daysAfterPay, ')
          ..write('weekend: $weekend, ')
          ..write('weekdays: $weekdays, ')
          ..write('nth: $nth, ')
          ..write('nthWeekday: $nthWeekday, ')
          ..write('endDate: $endDate, ')
          ..write('endCount: $endCount, ')
          ..write('rollover: $rollover, ')
          ..write('upToMinor: $upToMinor, ')
          ..write('paidFromId: $paidFromId, ')
          ..write('once: $once')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    categoryId,
    kind,
    amountMinor,
    start,
    due,
    everyMonths,
    everyDays,
    onDates,
    payScheduleId,
    daysAfterPay,
    weekend,
    weekdays,
    nth,
    nthWeekday,
    endDate,
    endCount,
    rollover,
    upToMinor,
    paidFromId,
    once,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryPlanRow &&
          other.categoryId == this.categoryId &&
          other.kind == this.kind &&
          other.amountMinor == this.amountMinor &&
          other.start == this.start &&
          other.due == this.due &&
          other.everyMonths == this.everyMonths &&
          other.everyDays == this.everyDays &&
          other.onDates == this.onDates &&
          other.payScheduleId == this.payScheduleId &&
          other.daysAfterPay == this.daysAfterPay &&
          other.weekend == this.weekend &&
          other.weekdays == this.weekdays &&
          other.nth == this.nth &&
          other.nthWeekday == this.nthWeekday &&
          other.endDate == this.endDate &&
          other.endCount == this.endCount &&
          other.rollover == this.rollover &&
          other.upToMinor == this.upToMinor &&
          other.paidFromId == this.paidFromId &&
          other.once == this.once);
}

class CategoryPlansCompanion extends UpdateCompanion<CategoryPlanRow> {
  final Value<int> categoryId;
  final Value<PlanKind> kind;
  final Value<int> amountMinor;
  final Value<String> start;
  final Value<String?> due;
  final Value<int?> everyMonths;
  final Value<int?> everyDays;
  final Value<String?> onDates;
  final Value<int?> payScheduleId;
  final Value<int> daysAfterPay;
  final Value<PayWeekend> weekend;
  final Value<String?> weekdays;
  final Value<int?> nth;
  final Value<int?> nthWeekday;
  final Value<String?> endDate;
  final Value<int?> endCount;
  final Value<bool> rollover;
  final Value<int?> upToMinor;
  final Value<int?> paidFromId;
  final Value<String?> once;
  const CategoryPlansCompanion({
    this.categoryId = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.start = const Value.absent(),
    this.due = const Value.absent(),
    this.everyMonths = const Value.absent(),
    this.everyDays = const Value.absent(),
    this.onDates = const Value.absent(),
    this.payScheduleId = const Value.absent(),
    this.daysAfterPay = const Value.absent(),
    this.weekend = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.nth = const Value.absent(),
    this.nthWeekday = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endCount = const Value.absent(),
    this.rollover = const Value.absent(),
    this.upToMinor = const Value.absent(),
    this.paidFromId = const Value.absent(),
    this.once = const Value.absent(),
  });
  CategoryPlansCompanion.insert({
    this.categoryId = const Value.absent(),
    required PlanKind kind,
    required int amountMinor,
    required String start,
    this.due = const Value.absent(),
    this.everyMonths = const Value.absent(),
    this.everyDays = const Value.absent(),
    this.onDates = const Value.absent(),
    this.payScheduleId = const Value.absent(),
    this.daysAfterPay = const Value.absent(),
    this.weekend = const Value.absent(),
    this.weekdays = const Value.absent(),
    this.nth = const Value.absent(),
    this.nthWeekday = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endCount = const Value.absent(),
    this.rollover = const Value.absent(),
    this.upToMinor = const Value.absent(),
    this.paidFromId = const Value.absent(),
    this.once = const Value.absent(),
  }) : kind = Value(kind),
       amountMinor = Value(amountMinor),
       start = Value(start);
  static Insertable<CategoryPlanRow> custom({
    Expression<int>? categoryId,
    Expression<String>? kind,
    Expression<int>? amountMinor,
    Expression<String>? start,
    Expression<String>? due,
    Expression<int>? everyMonths,
    Expression<int>? everyDays,
    Expression<String>? onDates,
    Expression<int>? payScheduleId,
    Expression<int>? daysAfterPay,
    Expression<String>? weekend,
    Expression<String>? weekdays,
    Expression<int>? nth,
    Expression<int>? nthWeekday,
    Expression<String>? endDate,
    Expression<int>? endCount,
    Expression<bool>? rollover,
    Expression<int>? upToMinor,
    Expression<int>? paidFromId,
    Expression<String>? once,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (kind != null) 'kind': kind,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (start != null) 'start': start,
      if (due != null) 'due': due,
      if (everyMonths != null) 'every_months': everyMonths,
      if (everyDays != null) 'every_days': everyDays,
      if (onDates != null) 'on_dates': onDates,
      if (payScheduleId != null) 'pay_schedule_id': payScheduleId,
      if (daysAfterPay != null) 'days_after_pay': daysAfterPay,
      if (weekend != null) 'weekend': weekend,
      if (weekdays != null) 'weekdays': weekdays,
      if (nth != null) 'nth': nth,
      if (nthWeekday != null) 'nth_weekday': nthWeekday,
      if (endDate != null) 'end_date': endDate,
      if (endCount != null) 'end_count': endCount,
      if (rollover != null) 'rollover': rollover,
      if (upToMinor != null) 'up_to_minor': upToMinor,
      if (paidFromId != null) 'paid_from_id': paidFromId,
      if (once != null) 'once': once,
    });
  }

  CategoryPlansCompanion copyWith({
    Value<int>? categoryId,
    Value<PlanKind>? kind,
    Value<int>? amountMinor,
    Value<String>? start,
    Value<String?>? due,
    Value<int?>? everyMonths,
    Value<int?>? everyDays,
    Value<String?>? onDates,
    Value<int?>? payScheduleId,
    Value<int>? daysAfterPay,
    Value<PayWeekend>? weekend,
    Value<String?>? weekdays,
    Value<int?>? nth,
    Value<int?>? nthWeekday,
    Value<String?>? endDate,
    Value<int?>? endCount,
    Value<bool>? rollover,
    Value<int?>? upToMinor,
    Value<int?>? paidFromId,
    Value<String?>? once,
  }) {
    return CategoryPlansCompanion(
      categoryId: categoryId ?? this.categoryId,
      kind: kind ?? this.kind,
      amountMinor: amountMinor ?? this.amountMinor,
      start: start ?? this.start,
      due: due ?? this.due,
      everyMonths: everyMonths ?? this.everyMonths,
      everyDays: everyDays ?? this.everyDays,
      onDates: onDates ?? this.onDates,
      payScheduleId: payScheduleId ?? this.payScheduleId,
      daysAfterPay: daysAfterPay ?? this.daysAfterPay,
      weekend: weekend ?? this.weekend,
      weekdays: weekdays ?? this.weekdays,
      nth: nth ?? this.nth,
      nthWeekday: nthWeekday ?? this.nthWeekday,
      endDate: endDate ?? this.endDate,
      endCount: endCount ?? this.endCount,
      rollover: rollover ?? this.rollover,
      upToMinor: upToMinor ?? this.upToMinor,
      paidFromId: paidFromId ?? this.paidFromId,
      once: once ?? this.once,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CategoryPlansTable.$converterkind.toSql(kind.value),
      );
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (start.present) {
      map['start'] = Variable<String>(start.value);
    }
    if (due.present) {
      map['due'] = Variable<String>(due.value);
    }
    if (everyMonths.present) {
      map['every_months'] = Variable<int>(everyMonths.value);
    }
    if (everyDays.present) {
      map['every_days'] = Variable<int>(everyDays.value);
    }
    if (onDates.present) {
      map['on_dates'] = Variable<String>(onDates.value);
    }
    if (payScheduleId.present) {
      map['pay_schedule_id'] = Variable<int>(payScheduleId.value);
    }
    if (daysAfterPay.present) {
      map['days_after_pay'] = Variable<int>(daysAfterPay.value);
    }
    if (weekend.present) {
      map['weekend'] = Variable<String>(
        $CategoryPlansTable.$converterweekend.toSql(weekend.value),
      );
    }
    if (weekdays.present) {
      map['weekdays'] = Variable<String>(weekdays.value);
    }
    if (nth.present) {
      map['nth'] = Variable<int>(nth.value);
    }
    if (nthWeekday.present) {
      map['nth_weekday'] = Variable<int>(nthWeekday.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (endCount.present) {
      map['end_count'] = Variable<int>(endCount.value);
    }
    if (rollover.present) {
      map['rollover'] = Variable<bool>(rollover.value);
    }
    if (upToMinor.present) {
      map['up_to_minor'] = Variable<int>(upToMinor.value);
    }
    if (paidFromId.present) {
      map['paid_from_id'] = Variable<int>(paidFromId.value);
    }
    if (once.present) {
      map['once'] = Variable<String>(once.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryPlansCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('kind: $kind, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('start: $start, ')
          ..write('due: $due, ')
          ..write('everyMonths: $everyMonths, ')
          ..write('everyDays: $everyDays, ')
          ..write('onDates: $onDates, ')
          ..write('payScheduleId: $payScheduleId, ')
          ..write('daysAfterPay: $daysAfterPay, ')
          ..write('weekend: $weekend, ')
          ..write('weekdays: $weekdays, ')
          ..write('nth: $nth, ')
          ..write('nthWeekday: $nthWeekday, ')
          ..write('endDate: $endDate, ')
          ..write('endCount: $endCount, ')
          ..write('rollover: $rollover, ')
          ..write('upToMinor: $upToMinor, ')
          ..write('paidFromId: $paidFromId, ')
          ..write('once: $once')
          ..write(')'))
        .toString();
  }
}

class $CategoryAccountsOffTable extends CategoryAccountsOff
    with TableInfo<$CategoryAccountsOffTable, CategoryAccountOffRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryAccountsOffTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
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
  @override
  List<GeneratedColumn> get $columns => [categoryId, accountId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_accounts_off';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryAccountOffRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId, accountId};
  @override
  CategoryAccountOffRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryAccountOffRow(
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
    );
  }

  @override
  $CategoryAccountsOffTable createAlias(String alias) {
    return $CategoryAccountsOffTable(attachedDatabase, alias);
  }
}

class CategoryAccountOffRow extends DataClass
    implements Insertable<CategoryAccountOffRow> {
  final int categoryId;
  final int accountId;
  const CategoryAccountOffRow({
    required this.categoryId,
    required this.accountId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<int>(categoryId);
    map['account_id'] = Variable<int>(accountId);
    return map;
  }

  CategoryAccountsOffCompanion toCompanion(bool nullToAbsent) {
    return CategoryAccountsOffCompanion(
      categoryId: Value(categoryId),
      accountId: Value(accountId),
    );
  }

  factory CategoryAccountOffRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryAccountOffRow(
      categoryId: serializer.fromJson<int>(json['categoryId']),
      accountId: serializer.fromJson<int>(json['accountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<int>(categoryId),
      'accountId': serializer.toJson<int>(accountId),
    };
  }

  CategoryAccountOffRow copyWith({int? categoryId, int? accountId}) =>
      CategoryAccountOffRow(
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
      );
  CategoryAccountOffRow copyWithCompanion(CategoryAccountsOffCompanion data) {
    return CategoryAccountOffRow(
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryAccountOffRow(')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(categoryId, accountId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryAccountOffRow &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId);
}

class CategoryAccountsOffCompanion
    extends UpdateCompanion<CategoryAccountOffRow> {
  final Value<int> categoryId;
  final Value<int> accountId;
  final Value<int> rowid;
  const CategoryAccountsOffCompanion({
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryAccountsOffCompanion.insert({
    required int categoryId,
    required int accountId,
    this.rowid = const Value.absent(),
  }) : categoryId = Value(categoryId),
       accountId = Value(accountId);
  static Insertable<CategoryAccountOffRow> custom({
    Expression<int>? categoryId,
    Expression<int>? accountId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryAccountsOffCompanion copyWith({
    Value<int>? categoryId,
    Value<int>? accountId,
    Value<int>? rowid,
  }) {
    return CategoryAccountsOffCompanion(
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryAccountsOffCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryPaidFromTable extends CategoryPaidFrom
    with TableInfo<$CategoryPaidFromTable, CategoryPaidFromRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryPaidFromTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
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
  @override
  List<GeneratedColumn> get $columns => [categoryId, accountId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_paid_from';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryPaidFromRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId};
  @override
  CategoryPaidFromRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryPaidFromRow(
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
    );
  }

  @override
  $CategoryPaidFromTable createAlias(String alias) {
    return $CategoryPaidFromTable(attachedDatabase, alias);
  }
}

class CategoryPaidFromRow extends DataClass
    implements Insertable<CategoryPaidFromRow> {
  final int categoryId;
  final int accountId;
  const CategoryPaidFromRow({
    required this.categoryId,
    required this.accountId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<int>(categoryId);
    map['account_id'] = Variable<int>(accountId);
    return map;
  }

  CategoryPaidFromCompanion toCompanion(bool nullToAbsent) {
    return CategoryPaidFromCompanion(
      categoryId: Value(categoryId),
      accountId: Value(accountId),
    );
  }

  factory CategoryPaidFromRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryPaidFromRow(
      categoryId: serializer.fromJson<int>(json['categoryId']),
      accountId: serializer.fromJson<int>(json['accountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<int>(categoryId),
      'accountId': serializer.toJson<int>(accountId),
    };
  }

  CategoryPaidFromRow copyWith({int? categoryId, int? accountId}) =>
      CategoryPaidFromRow(
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
      );
  CategoryPaidFromRow copyWithCompanion(CategoryPaidFromCompanion data) {
    return CategoryPaidFromRow(
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryPaidFromRow(')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(categoryId, accountId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryPaidFromRow &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId);
}

class CategoryPaidFromCompanion extends UpdateCompanion<CategoryPaidFromRow> {
  final Value<int> categoryId;
  final Value<int> accountId;
  const CategoryPaidFromCompanion({
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
  });
  CategoryPaidFromCompanion.insert({
    this.categoryId = const Value.absent(),
    required int accountId,
  }) : accountId = Value(accountId);
  static Insertable<CategoryPaidFromRow> custom({
    Expression<int>? categoryId,
    Expression<int>? accountId,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
    });
  }

  CategoryPaidFromCompanion copyWith({
    Value<int>? categoryId,
    Value<int>? accountId,
  }) {
    return CategoryPaidFromCompanion(
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryPaidFromCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId')
          ..write(')'))
        .toString();
  }
}

class $PayeeRulesTable extends PayeeRules
    with TableInfo<$PayeeRulesTable, PayeeRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayeeRulesTable(this.attachedDatabase, [this._alias]);
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
    clientDefault: newRowId,
  );
  static const VerificationMeta _wordsMeta = const VerificationMeta('words');
  @override
  late final GeneratedColumn<String> words = GeneratedColumn<String>(
    'words',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _anywhereMeta = const VerificationMeta(
    'anywhere',
  );
  @override
  late final GeneratedColumn<bool> anywhere = GeneratedColumn<bool>(
    'anywhere',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("anywhere" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _payScheduleIdMeta = const VerificationMeta(
    'payScheduleId',
  );
  @override
  late final GeneratedColumn<int> payScheduleId = GeneratedColumn<int>(
    'pay_schedule_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pay_schedules (id)',
    ),
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
    words,
    name,
    anywhere,
    categoryId,
    payScheduleId,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payee_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayeeRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('words')) {
      context.handle(
        _wordsMeta,
        words.isAcceptableOrUnknown(data['words']!, _wordsMeta),
      );
    } else if (isInserting) {
      context.missing(_wordsMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('anywhere')) {
      context.handle(
        _anywhereMeta,
        anywhere.isAcceptableOrUnknown(data['anywhere']!, _anywhereMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('pay_schedule_id')) {
      context.handle(
        _payScheduleIdMeta,
        payScheduleId.isAcceptableOrUnknown(
          data['pay_schedule_id']!,
          _payScheduleIdMeta,
        ),
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
  PayeeRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayeeRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      words: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}words'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      anywhere: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}anywhere'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      payScheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pay_schedule_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PayeeRulesTable createAlias(String alias) {
    return $PayeeRulesTable(attachedDatabase, alias);
  }
}

class PayeeRuleRow extends DataClass implements Insertable<PayeeRuleRow> {
  final int id;

  /// What is looked for, as [payeeWords] makes it.
  final String words;

  /// The same as the person wrote it.
  final String name;

  /// Anywhere in the payee or the bank's description; else the payee has
  /// to start with [words].
  final bool anywhere;
  final int categoryId;

  /// The pay whose paycheck money in from this payee is, when it's pay.
  final int? payScheduleId;
  final int createdAt;

  /// Deleted by the person: kept so an import doesn't put the payee back
  /// where it went last ([PayeeRuleInfo.deletedBlocks]).
  final int? deletedAt;
  const PayeeRuleRow({
    required this.id,
    required this.words,
    required this.name,
    required this.anywhere,
    required this.categoryId,
    this.payScheduleId,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['words'] = Variable<String>(words);
    map['name'] = Variable<String>(name);
    map['anywhere'] = Variable<bool>(anywhere);
    map['category_id'] = Variable<int>(categoryId);
    if (!nullToAbsent || payScheduleId != null) {
      map['pay_schedule_id'] = Variable<int>(payScheduleId);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  PayeeRulesCompanion toCompanion(bool nullToAbsent) {
    return PayeeRulesCompanion(
      id: Value(id),
      words: Value(words),
      name: Value(name),
      anywhere: Value(anywhere),
      categoryId: Value(categoryId),
      payScheduleId: payScheduleId == null && nullToAbsent
          ? const Value.absent()
          : Value(payScheduleId),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PayeeRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayeeRuleRow(
      id: serializer.fromJson<int>(json['id']),
      words: serializer.fromJson<String>(json['words']),
      name: serializer.fromJson<String>(json['name']),
      anywhere: serializer.fromJson<bool>(json['anywhere']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      payScheduleId: serializer.fromJson<int?>(json['payScheduleId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'words': serializer.toJson<String>(words),
      'name': serializer.toJson<String>(name),
      'anywhere': serializer.toJson<bool>(anywhere),
      'categoryId': serializer.toJson<int>(categoryId),
      'payScheduleId': serializer.toJson<int?>(payScheduleId),
      'createdAt': serializer.toJson<int>(createdAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  PayeeRuleRow copyWith({
    int? id,
    String? words,
    String? name,
    bool? anywhere,
    int? categoryId,
    Value<int?> payScheduleId = const Value.absent(),
    int? createdAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => PayeeRuleRow(
    id: id ?? this.id,
    words: words ?? this.words,
    name: name ?? this.name,
    anywhere: anywhere ?? this.anywhere,
    categoryId: categoryId ?? this.categoryId,
    payScheduleId: payScheduleId.present
        ? payScheduleId.value
        : this.payScheduleId,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PayeeRuleRow copyWithCompanion(PayeeRulesCompanion data) {
    return PayeeRuleRow(
      id: data.id.present ? data.id.value : this.id,
      words: data.words.present ? data.words.value : this.words,
      name: data.name.present ? data.name.value : this.name,
      anywhere: data.anywhere.present ? data.anywhere.value : this.anywhere,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      payScheduleId: data.payScheduleId.present
          ? data.payScheduleId.value
          : this.payScheduleId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayeeRuleRow(')
          ..write('id: $id, ')
          ..write('words: $words, ')
          ..write('name: $name, ')
          ..write('anywhere: $anywhere, ')
          ..write('categoryId: $categoryId, ')
          ..write('payScheduleId: $payScheduleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    words,
    name,
    anywhere,
    categoryId,
    payScheduleId,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayeeRuleRow &&
          other.id == this.id &&
          other.words == this.words &&
          other.name == this.name &&
          other.anywhere == this.anywhere &&
          other.categoryId == this.categoryId &&
          other.payScheduleId == this.payScheduleId &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class PayeeRulesCompanion extends UpdateCompanion<PayeeRuleRow> {
  final Value<int> id;
  final Value<String> words;
  final Value<String> name;
  final Value<bool> anywhere;
  final Value<int> categoryId;
  final Value<int?> payScheduleId;
  final Value<int> createdAt;
  final Value<int?> deletedAt;
  const PayeeRulesCompanion({
    this.id = const Value.absent(),
    this.words = const Value.absent(),
    this.name = const Value.absent(),
    this.anywhere = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.payScheduleId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PayeeRulesCompanion.insert({
    this.id = const Value.absent(),
    required String words,
    required String name,
    this.anywhere = const Value.absent(),
    required int categoryId,
    this.payScheduleId = const Value.absent(),
    required int createdAt,
    this.deletedAt = const Value.absent(),
  }) : words = Value(words),
       name = Value(name),
       categoryId = Value(categoryId),
       createdAt = Value(createdAt);
  static Insertable<PayeeRuleRow> custom({
    Expression<int>? id,
    Expression<String>? words,
    Expression<String>? name,
    Expression<bool>? anywhere,
    Expression<int>? categoryId,
    Expression<int>? payScheduleId,
    Expression<int>? createdAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (words != null) 'words': words,
      if (name != null) 'name': name,
      if (anywhere != null) 'anywhere': anywhere,
      if (categoryId != null) 'category_id': categoryId,
      if (payScheduleId != null) 'pay_schedule_id': payScheduleId,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PayeeRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? words,
    Value<String>? name,
    Value<bool>? anywhere,
    Value<int>? categoryId,
    Value<int?>? payScheduleId,
    Value<int>? createdAt,
    Value<int?>? deletedAt,
  }) {
    return PayeeRulesCompanion(
      id: id ?? this.id,
      words: words ?? this.words,
      name: name ?? this.name,
      anywhere: anywhere ?? this.anywhere,
      categoryId: categoryId ?? this.categoryId,
      payScheduleId: payScheduleId ?? this.payScheduleId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (words.present) {
      map['words'] = Variable<String>(words.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (anywhere.present) {
      map['anywhere'] = Variable<bool>(anywhere.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (payScheduleId.present) {
      map['pay_schedule_id'] = Variable<int>(payScheduleId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayeeRulesCompanion(')
          ..write('id: $id, ')
          ..write('words: $words, ')
          ..write('name: $name, ')
          ..write('anywhere: $anywhere, ')
          ..write('categoryId: $categoryId, ')
          ..write('payScheduleId: $payScheduleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PayeeRuleAccountsTable extends PayeeRuleAccounts
    with TableInfo<$PayeeRuleAccountsTable, PayeeRuleAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayeeRuleAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<int> ruleId = GeneratedColumn<int>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES payee_rules (id)',
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
  @override
  List<GeneratedColumn> get $columns => [ruleId, accountId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payee_rule_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PayeeRuleAccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ruleId, accountId};
  @override
  PayeeRuleAccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayeeRuleAccountRow(
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rule_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
    );
  }

  @override
  $PayeeRuleAccountsTable createAlias(String alias) {
    return $PayeeRuleAccountsTable(attachedDatabase, alias);
  }
}

class PayeeRuleAccountRow extends DataClass
    implements Insertable<PayeeRuleAccountRow> {
  final int ruleId;
  final int accountId;
  const PayeeRuleAccountRow({required this.ruleId, required this.accountId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['rule_id'] = Variable<int>(ruleId);
    map['account_id'] = Variable<int>(accountId);
    return map;
  }

  PayeeRuleAccountsCompanion toCompanion(bool nullToAbsent) {
    return PayeeRuleAccountsCompanion(
      ruleId: Value(ruleId),
      accountId: Value(accountId),
    );
  }

  factory PayeeRuleAccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayeeRuleAccountRow(
      ruleId: serializer.fromJson<int>(json['ruleId']),
      accountId: serializer.fromJson<int>(json['accountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ruleId': serializer.toJson<int>(ruleId),
      'accountId': serializer.toJson<int>(accountId),
    };
  }

  PayeeRuleAccountRow copyWith({int? ruleId, int? accountId}) =>
      PayeeRuleAccountRow(
        ruleId: ruleId ?? this.ruleId,
        accountId: accountId ?? this.accountId,
      );
  PayeeRuleAccountRow copyWithCompanion(PayeeRuleAccountsCompanion data) {
    return PayeeRuleAccountRow(
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayeeRuleAccountRow(')
          ..write('ruleId: $ruleId, ')
          ..write('accountId: $accountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ruleId, accountId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayeeRuleAccountRow &&
          other.ruleId == this.ruleId &&
          other.accountId == this.accountId);
}

class PayeeRuleAccountsCompanion extends UpdateCompanion<PayeeRuleAccountRow> {
  final Value<int> ruleId;
  final Value<int> accountId;
  final Value<int> rowid;
  const PayeeRuleAccountsCompanion({
    this.ruleId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayeeRuleAccountsCompanion.insert({
    required int ruleId,
    required int accountId,
    this.rowid = const Value.absent(),
  }) : ruleId = Value(ruleId),
       accountId = Value(accountId);
  static Insertable<PayeeRuleAccountRow> custom({
    Expression<int>? ruleId,
    Expression<int>? accountId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ruleId != null) 'rule_id': ruleId,
      if (accountId != null) 'account_id': accountId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayeeRuleAccountsCompanion copyWith({
    Value<int>? ruleId,
    Value<int>? accountId,
    Value<int>? rowid,
  }) {
    return PayeeRuleAccountsCompanion(
      ruleId: ruleId ?? this.ruleId,
      accountId: accountId ?? this.accountId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ruleId.present) {
      map['rule_id'] = Variable<int>(ruleId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayeeRuleAccountsCompanion(')
          ..write('ruleId: $ruleId, ')
          ..write('accountId: $accountId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChangesTable extends Changes with TableInfo<$ChangesTable, ChangeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tblMeta = const VerificationMeta('tbl');
  @override
  late final GeneratedColumn<String> tbl = GeneratedColumn<String>(
    'tbl',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pkMeta = const VerificationMeta('pk');
  @override
  late final GeneratedColumn<String> pk = GeneratedColumn<String>(
    'pk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeMeta = const VerificationMeta('before');
  @override
  late final GeneratedColumn<String> before = GeneratedColumn<String>(
    'before',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterMeta = const VerificationMeta('after');
  @override
  late final GeneratedColumn<String> after = GeneratedColumn<String>(
    'after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atMsMeta = const VerificationMeta('atMs');
  @override
  late final GeneratedColumn<int> atMs = GeneratedColumn<int>(
    'at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _withSchemaMeta = const VerificationMeta(
    'withSchema',
  );
  @override
  late final GeneratedColumn<int> withSchema = GeneratedColumn<int>(
    'with_schema',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    tbl,
    pk,
    op,
    before,
    after,
    atMs,
    withSchema,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChangeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('tbl')) {
      context.handle(
        _tblMeta,
        tbl.isAcceptableOrUnknown(data['tbl']!, _tblMeta),
      );
    } else if (isInserting) {
      context.missing(_tblMeta);
    }
    if (data.containsKey('pk')) {
      context.handle(_pkMeta, pk.isAcceptableOrUnknown(data['pk']!, _pkMeta));
    } else if (isInserting) {
      context.missing(_pkMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('before')) {
      context.handle(
        _beforeMeta,
        before.isAcceptableOrUnknown(data['before']!, _beforeMeta),
      );
    }
    if (data.containsKey('after')) {
      context.handle(
        _afterMeta,
        after.isAcceptableOrUnknown(data['after']!, _afterMeta),
      );
    }
    if (data.containsKey('at_ms')) {
      context.handle(
        _atMsMeta,
        atMs.isAcceptableOrUnknown(data['at_ms']!, _atMsMeta),
      );
    } else if (isInserting) {
      context.missing(_atMsMeta);
    }
    if (data.containsKey('with_schema')) {
      context.handle(
        _withSchemaMeta,
        withSchema.isAcceptableOrUnknown(data['with_schema']!, _withSchemaMeta),
      );
    } else if (isInserting) {
      context.missing(_withSchemaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  ChangeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChangeRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      tbl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tbl'],
      )!,
      pk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pk'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      before: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before'],
      ),
      after: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after'],
      ),
      atMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_ms'],
      )!,
      withSchema: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}with_schema'],
      )!,
    );
  }

  @override
  $ChangesTable createAlias(String alias) {
    return $ChangesTable(attachedDatabase, alias);
  }
}

class ChangeRow extends DataClass implements Insertable<ChangeRow> {
  final int seq;

  /// The table the row is in.
  final String tbl;

  /// The row's key columns, as a JSON object.
  final String pk;

  /// `insert`, `update` or `delete`; `restore` or `erase` for a whole ledger
  /// put in or cleared here, with no rows (ADR 0005: made a batch of its own
  /// in step 5).
  final String op;

  /// The whole row before, as JSON; null for an insert.
  final String? before;

  /// The whole row after, as JSON; null for a delete.
  final String? after;

  /// When, by this computer's clock, for the screen only.
  final int atMs;

  /// The tables' version the row was written under.
  final int withSchema;
  const ChangeRow({
    required this.seq,
    required this.tbl,
    required this.pk,
    required this.op,
    this.before,
    this.after,
    required this.atMs,
    required this.withSchema,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['tbl'] = Variable<String>(tbl);
    map['pk'] = Variable<String>(pk);
    map['op'] = Variable<String>(op);
    if (!nullToAbsent || before != null) {
      map['before'] = Variable<String>(before);
    }
    if (!nullToAbsent || after != null) {
      map['after'] = Variable<String>(after);
    }
    map['at_ms'] = Variable<int>(atMs);
    map['with_schema'] = Variable<int>(withSchema);
    return map;
  }

  ChangesCompanion toCompanion(bool nullToAbsent) {
    return ChangesCompanion(
      seq: Value(seq),
      tbl: Value(tbl),
      pk: Value(pk),
      op: Value(op),
      before: before == null && nullToAbsent
          ? const Value.absent()
          : Value(before),
      after: after == null && nullToAbsent
          ? const Value.absent()
          : Value(after),
      atMs: Value(atMs),
      withSchema: Value(withSchema),
    );
  }

  factory ChangeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChangeRow(
      seq: serializer.fromJson<int>(json['seq']),
      tbl: serializer.fromJson<String>(json['tbl']),
      pk: serializer.fromJson<String>(json['pk']),
      op: serializer.fromJson<String>(json['op']),
      before: serializer.fromJson<String?>(json['before']),
      after: serializer.fromJson<String?>(json['after']),
      atMs: serializer.fromJson<int>(json['atMs']),
      withSchema: serializer.fromJson<int>(json['withSchema']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'tbl': serializer.toJson<String>(tbl),
      'pk': serializer.toJson<String>(pk),
      'op': serializer.toJson<String>(op),
      'before': serializer.toJson<String?>(before),
      'after': serializer.toJson<String?>(after),
      'atMs': serializer.toJson<int>(atMs),
      'withSchema': serializer.toJson<int>(withSchema),
    };
  }

  ChangeRow copyWith({
    int? seq,
    String? tbl,
    String? pk,
    String? op,
    Value<String?> before = const Value.absent(),
    Value<String?> after = const Value.absent(),
    int? atMs,
    int? withSchema,
  }) => ChangeRow(
    seq: seq ?? this.seq,
    tbl: tbl ?? this.tbl,
    pk: pk ?? this.pk,
    op: op ?? this.op,
    before: before.present ? before.value : this.before,
    after: after.present ? after.value : this.after,
    atMs: atMs ?? this.atMs,
    withSchema: withSchema ?? this.withSchema,
  );
  ChangeRow copyWithCompanion(ChangesCompanion data) {
    return ChangeRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      tbl: data.tbl.present ? data.tbl.value : this.tbl,
      pk: data.pk.present ? data.pk.value : this.pk,
      op: data.op.present ? data.op.value : this.op,
      before: data.before.present ? data.before.value : this.before,
      after: data.after.present ? data.after.value : this.after,
      atMs: data.atMs.present ? data.atMs.value : this.atMs,
      withSchema: data.withSchema.present
          ? data.withSchema.value
          : this.withSchema,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChangeRow(')
          ..write('seq: $seq, ')
          ..write('tbl: $tbl, ')
          ..write('pk: $pk, ')
          ..write('op: $op, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('atMs: $atMs, ')
          ..write('withSchema: $withSchema')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, tbl, pk, op, before, after, atMs, withSchema);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeRow &&
          other.seq == this.seq &&
          other.tbl == this.tbl &&
          other.pk == this.pk &&
          other.op == this.op &&
          other.before == this.before &&
          other.after == this.after &&
          other.atMs == this.atMs &&
          other.withSchema == this.withSchema);
}

class ChangesCompanion extends UpdateCompanion<ChangeRow> {
  final Value<int> seq;
  final Value<String> tbl;
  final Value<String> pk;
  final Value<String> op;
  final Value<String?> before;
  final Value<String?> after;
  final Value<int> atMs;
  final Value<int> withSchema;
  const ChangesCompanion({
    this.seq = const Value.absent(),
    this.tbl = const Value.absent(),
    this.pk = const Value.absent(),
    this.op = const Value.absent(),
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.atMs = const Value.absent(),
    this.withSchema = const Value.absent(),
  });
  ChangesCompanion.insert({
    this.seq = const Value.absent(),
    required String tbl,
    required String pk,
    required String op,
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    required int atMs,
    required int withSchema,
  }) : tbl = Value(tbl),
       pk = Value(pk),
       op = Value(op),
       atMs = Value(atMs),
       withSchema = Value(withSchema);
  static Insertable<ChangeRow> custom({
    Expression<int>? seq,
    Expression<String>? tbl,
    Expression<String>? pk,
    Expression<String>? op,
    Expression<String>? before,
    Expression<String>? after,
    Expression<int>? atMs,
    Expression<int>? withSchema,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (tbl != null) 'tbl': tbl,
      if (pk != null) 'pk': pk,
      if (op != null) 'op': op,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
      if (atMs != null) 'at_ms': atMs,
      if (withSchema != null) 'with_schema': withSchema,
    });
  }

  ChangesCompanion copyWith({
    Value<int>? seq,
    Value<String>? tbl,
    Value<String>? pk,
    Value<String>? op,
    Value<String?>? before,
    Value<String?>? after,
    Value<int>? atMs,
    Value<int>? withSchema,
  }) {
    return ChangesCompanion(
      seq: seq ?? this.seq,
      tbl: tbl ?? this.tbl,
      pk: pk ?? this.pk,
      op: op ?? this.op,
      before: before ?? this.before,
      after: after ?? this.after,
      atMs: atMs ?? this.atMs,
      withSchema: withSchema ?? this.withSchema,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (tbl.present) {
      map['tbl'] = Variable<String>(tbl.value);
    }
    if (pk.present) {
      map['pk'] = Variable<String>(pk.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (before.present) {
      map['before'] = Variable<String>(before.value);
    }
    if (after.present) {
      map['after'] = Variable<String>(after.value);
    }
    if (atMs.present) {
      map['at_ms'] = Variable<int>(atMs.value);
    }
    if (withSchema.present) {
      map['with_schema'] = Variable<int>(withSchema.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChangesCompanion(')
          ..write('seq: $seq, ')
          ..write('tbl: $tbl, ')
          ..write('pk: $pk, ')
          ..write('op: $op, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('atMs: $atMs, ')
          ..write('withSchema: $withSchema')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $PaySchedulesTable paySchedules = $PaySchedulesTable(this);
  late final $PayeesTable payees = $PayeesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $ReconciliationsTable reconciliations = $ReconciliationsTable(
    this,
  );
  late final $EntriesTable entries = $EntriesTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final $BudgetAmountsTable budgetAmounts = $BudgetAmountsTable(this);
  late final $CategoryPlansTable categoryPlans = $CategoryPlansTable(this);
  late final $CategoryAccountsOffTable categoryAccountsOff =
      $CategoryAccountsOffTable(this);
  late final $CategoryPaidFromTable categoryPaidFrom = $CategoryPaidFromTable(
    this,
  );
  late final $PayeeRulesTable payeeRules = $PayeeRulesTable(this);
  late final $PayeeRuleAccountsTable payeeRuleAccounts =
      $PayeeRuleAccountsTable(this);
  late final $ChangesTable changes = $ChangesTable(this);
  late final Index entriesImportKey = Index(
    'entries_import_key',
    'CREATE UNIQUE INDEX entries_import_key ON entries (import_key)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    paySchedules,
    payees,
    transactions,
    reconciliations,
    entries,
    preferences,
    budgetAmounts,
    categoryPlans,
    categoryAccountsOff,
    categoryPaidFrom,
    payeeRules,
    payeeRuleAccounts,
    changes,
    entriesImportKey,
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
  Value<int?> archivedAt,
  Value<int?> deletedAt,
  Value<bool> payday,
  Value<AccountRole?> role,
  Value<String?> budgetGroup,
  Value<String?> note,
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
  Value<int?> archivedAt,
  Value<int?> deletedAt,
  Value<bool> payday,
  Value<AccountRole?> role,
  Value<String?> budgetGroup,
  Value<String?> note,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRow>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'accounts__id__transactions__plan_category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.planCategoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

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

  static MultiTypedResultKey<$BudgetAmountsTable, List<BudgetAmountRow>>
  _budgetAmountsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.budgetAmounts,
    aliasName: 'accounts__id__budget_amounts__category_id',
  );

  $$BudgetAmountsTableProcessedTableManager get budgetAmountsRefs {
    final manager = $$BudgetAmountsTableTableManager(
      $_db,
      $_db.budgetAmounts,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetAmountsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PayeeRulesTable, List<PayeeRuleRow>>
  _payeeRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.payeeRules,
    aliasName: 'accounts__id__payee_rules__category_id',
  );

  $$PayeeRulesTableProcessedTableManager get payeeRulesRefs {
    final manager = $$PayeeRulesTableTableManager(
      $_db,
      $_db.payeeRules,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_payeeRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PayeeRuleAccountsTable, List<PayeeRuleAccountRow>>
  _payeeRuleAccountsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.payeeRuleAccounts,
        aliasName: 'accounts__id__payee_rule_accounts__account_id',
      );

  $$PayeeRuleAccountsTableProcessedTableManager get payeeRuleAccountsRefs {
    final manager = $$PayeeRuleAccountsTableTableManager(
      $_db,
      $_db.payeeRuleAccounts,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _payeeRuleAccountsRefsTable($_db),
    );
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

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get payday => $composableBuilder(
    column: $table.payday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountRole?, AccountRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get budgetGroup => $composableBuilder(
    column: $table.budgetGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.planCategoryId,
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

  Expression<bool> budgetAmountsRefs(
    Expression<bool> Function($$BudgetAmountsTableFilterComposer f) f,
  ) {
    final $$BudgetAmountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetAmounts,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetAmountsTableFilterComposer(
            $db: $db,
            $table: $db.budgetAmounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> payeeRulesRefs(
    Expression<bool> Function($$PayeeRulesTableFilterComposer f) f,
  ) {
    final $$PayeeRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payeeRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRulesTableFilterComposer(
            $db: $db,
            $table: $db.payeeRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> payeeRuleAccountsRefs(
    Expression<bool> Function($$PayeeRuleAccountsTableFilterComposer f) f,
  ) {
    final $$PayeeRuleAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payeeRuleAccounts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRuleAccountsTableFilterComposer(
            $db: $db,
            $table: $db.payeeRuleAccounts,
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

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get payday => $composableBuilder(
    column: $table.payday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetGroup => $composableBuilder(
    column: $table.budgetGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
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

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get payday =>
      $composableBuilder(column: $table.payday, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountRole?, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get budgetGroup => $composableBuilder(
    column: $table.budgetGroup,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.planCategoryId,
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

  Expression<T> budgetAmountsRefs<T extends Object>(
    Expression<T> Function($$BudgetAmountsTableAnnotationComposer a) f,
  ) {
    final $$BudgetAmountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetAmounts,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetAmountsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgetAmounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> payeeRulesRefs<T extends Object>(
    Expression<T> Function($$PayeeRulesTableAnnotationComposer a) f,
  ) {
    final $$PayeeRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payeeRules,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.payeeRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> payeeRuleAccountsRefs<T extends Object>(
    Expression<T> Function($$PayeeRuleAccountsTableAnnotationComposer a) f,
  ) {
    final $$PayeeRuleAccountsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.payeeRuleAccounts,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PayeeRuleAccountsTableAnnotationComposer(
                $db: $db,
                $table: $db.payeeRuleAccounts,
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
          PrefetchHooks Function({
            bool transactionsRefs,
            bool reconciliationsRefs,
            bool entriesRefs,
            bool budgetAmountsRefs,
            bool payeeRulesRefs,
            bool payeeRuleAccountsRefs,
          })
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
                Value<int?> archivedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> payday = const Value.absent(),
                Value<AccountRole?> role = const Value.absent(),
                Value<String?> budgetGroup = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                type: type,
                currency: currency,
                institution: institution,
                mask: mask,
                sidebarGroup: sidebarGroup,
                sortOrder: sortOrder,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                payday: payday,
                role: role,
                budgetGroup: budgetGroup,
                note: note,
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
                Value<int?> archivedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<bool> payday = const Value.absent(),
                Value<AccountRole?> role = const Value.absent(),
                Value<String?> budgetGroup = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                type: type,
                currency: currency,
                institution: institution,
                mask: mask,
                sidebarGroup: sidebarGroup,
                sortOrder: sortOrder,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                payday: payday,
                role: role,
                budgetGroup: budgetGroup,
                note: note,
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
              ({
                transactionsRefs = false,
                reconciliationsRefs = false,
                entriesRefs = false,
                budgetAmountsRefs = false,
                payeeRulesRefs = false,
                payeeRuleAccountsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (reconciliationsRefs) db.reconciliations,
                    if (entriesRefs) db.entries,
                    if (budgetAmountsRefs) db.budgetAmounts,
                    if (payeeRulesRefs) db.payeeRules,
                    if (payeeRuleAccountsRefs) db.payeeRuleAccounts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          TransactionRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planCategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
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
                      if (budgetAmountsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          BudgetAmountRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._budgetAmountsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetAmountsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (payeeRulesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          PayeeRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._payeeRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).payeeRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (payeeRuleAccountsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          PayeeRuleAccountRow
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._payeeRuleAccountsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).payeeRuleAccountsRefs,
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
      PrefetchHooks Function({
        bool transactionsRefs,
        bool reconciliationsRefs,
        bool entriesRefs,
        bool budgetAmountsRefs,
        bool payeeRulesRefs,
        bool payeeRuleAccountsRefs,
      })
    >;
typedef $$PaySchedulesTableCreateCompanionBuilder =
    PaySchedulesCompanion Function({
      Value<int> id,
      required int categoryId,
      required int accountId,
      Value<String?> payee,
      Value<String?> name,
      required int amountMinor,
      Value<int?> amount2Minor,
      Value<bool> varies,
      required PayRule rule,
      Value<int> day1,
      Value<int> day2,
      Value<int> weeks,
      Value<String?> anchor,
      Value<bool> weekendBefore,
      Value<bool> weekendKeep,
      Value<bool> definesPeriod,
      required int createdAt,
      Value<int?> deletedAt,
    });
typedef $$PaySchedulesTableUpdateCompanionBuilder =
    PaySchedulesCompanion Function({
      Value<int> id,
      Value<int> categoryId,
      Value<int> accountId,
      Value<String?> payee,
      Value<String?> name,
      Value<int> amountMinor,
      Value<int?> amount2Minor,
      Value<bool> varies,
      Value<PayRule> rule,
      Value<int> day1,
      Value<int> day2,
      Value<int> weeks,
      Value<String?> anchor,
      Value<bool> weekendBefore,
      Value<bool> weekendKeep,
      Value<bool> definesPeriod,
      Value<int> createdAt,
      Value<int?> deletedAt,
    });

final class $$PaySchedulesTableReferences
    extends BaseReferences<_$AppDatabase, $PaySchedulesTable, PayScheduleRow> {
  $$PaySchedulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _categoryIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('pay_schedules__category_id__accounts__id');

  $$AccountsTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('pay_schedules__account_id__accounts__id');

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

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRow>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'pay_schedules__id__transactions__pay_schedule_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.payScheduleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CategoryPlansTable, List<CategoryPlanRow>>
  _categoryPlansRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.categoryPlans,
    aliasName: 'pay_schedules__id__category_plans__pay_schedule_id',
  );

  $$CategoryPlansTableProcessedTableManager get categoryPlansRefs {
    final manager = $$CategoryPlansTableTableManager(
      $_db,
      $_db.categoryPlans,
    ).filter((f) => f.payScheduleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_categoryPlansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PayeeRulesTable, List<PayeeRuleRow>>
  _payeeRulesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.payeeRules,
    aliasName: 'pay_schedules__id__payee_rules__pay_schedule_id',
  );

  $$PayeeRulesTableProcessedTableManager get payeeRulesRefs {
    final manager = $$PayeeRulesTableTableManager(
      $_db,
      $_db.payeeRules,
    ).filter((f) => f.payScheduleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_payeeRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PaySchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $PaySchedulesTable> {
  $$PaySchedulesTableFilterComposer({
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

  ColumnFilters<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount2Minor => $composableBuilder(
    column: $table.amount2Minor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get varies => $composableBuilder(
    column: $table.varies,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PayRule, PayRule, String> get rule =>
      $composableBuilder(
        column: $table.rule,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get day1 => $composableBuilder(
    column: $table.day1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get day2 => $composableBuilder(
    column: $table.day2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weeks => $composableBuilder(
    column: $table.weeks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get anchor => $composableBuilder(
    column: $table.anchor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get weekendBefore => $composableBuilder(
    column: $table.weekendBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get weekendKeep => $composableBuilder(
    column: $table.weekendKeep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get definesPeriod => $composableBuilder(
    column: $table.definesPeriod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get categoryId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.payScheduleId,
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

  Expression<bool> categoryPlansRefs(
    Expression<bool> Function($$CategoryPlansTableFilterComposer f) f,
  ) {
    final $$CategoryPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryPlans,
      getReferencedColumn: (t) => t.payScheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryPlansTableFilterComposer(
            $db: $db,
            $table: $db.categoryPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> payeeRulesRefs(
    Expression<bool> Function($$PayeeRulesTableFilterComposer f) f,
  ) {
    final $$PayeeRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payeeRules,
      getReferencedColumn: (t) => t.payScheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRulesTableFilterComposer(
            $db: $db,
            $table: $db.payeeRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PaySchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $PaySchedulesTable> {
  $$PaySchedulesTableOrderingComposer({
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

  ColumnOrderings<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount2Minor => $composableBuilder(
    column: $table.amount2Minor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get varies => $composableBuilder(
    column: $table.varies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rule => $composableBuilder(
    column: $table.rule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get day1 => $composableBuilder(
    column: $table.day1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get day2 => $composableBuilder(
    column: $table.day2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weeks => $composableBuilder(
    column: $table.weeks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anchor => $composableBuilder(
    column: $table.anchor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get weekendBefore => $composableBuilder(
    column: $table.weekendBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get weekendKeep => $composableBuilder(
    column: $table.weekendKeep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get definesPeriod => $composableBuilder(
    column: $table.definesPeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get categoryId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

class $$PaySchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaySchedulesTable> {
  $$PaySchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payee =>
      $composableBuilder(column: $table.payee, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount2Minor => $composableBuilder(
    column: $table.amount2Minor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get varies =>
      $composableBuilder(column: $table.varies, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PayRule, String> get rule =>
      $composableBuilder(column: $table.rule, builder: (column) => column);

  GeneratedColumn<int> get day1 =>
      $composableBuilder(column: $table.day1, builder: (column) => column);

  GeneratedColumn<int> get day2 =>
      $composableBuilder(column: $table.day2, builder: (column) => column);

  GeneratedColumn<int> get weeks =>
      $composableBuilder(column: $table.weeks, builder: (column) => column);

  GeneratedColumn<String> get anchor =>
      $composableBuilder(column: $table.anchor, builder: (column) => column);

  GeneratedColumn<bool> get weekendBefore => $composableBuilder(
    column: $table.weekendBefore,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get weekendKeep => $composableBuilder(
    column: $table.weekendKeep,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get definesPeriod => $composableBuilder(
    column: $table.definesPeriod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get categoryId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.payScheduleId,
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

  Expression<T> categoryPlansRefs<T extends Object>(
    Expression<T> Function($$CategoryPlansTableAnnotationComposer a) f,
  ) {
    final $$CategoryPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryPlans,
      getReferencedColumn: (t) => t.payScheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> payeeRulesRefs<T extends Object>(
    Expression<T> Function($$PayeeRulesTableAnnotationComposer a) f,
  ) {
    final $$PayeeRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payeeRules,
      getReferencedColumn: (t) => t.payScheduleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.payeeRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PaySchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaySchedulesTable,
          PayScheduleRow,
          $$PaySchedulesTableFilterComposer,
          $$PaySchedulesTableOrderingComposer,
          $$PaySchedulesTableAnnotationComposer,
          $$PaySchedulesTableCreateCompanionBuilder,
          $$PaySchedulesTableUpdateCompanionBuilder,
          (PayScheduleRow, $$PaySchedulesTableReferences),
          PayScheduleRow,
          PrefetchHooks Function({
            bool categoryId,
            bool accountId,
            bool transactionsRefs,
            bool categoryPlansRefs,
            bool payeeRulesRefs,
          })
        > {
  $$PaySchedulesTableTableManager(_$AppDatabase db, $PaySchedulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaySchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaySchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaySchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<int?> amount2Minor = const Value.absent(),
                Value<bool> varies = const Value.absent(),
                Value<PayRule> rule = const Value.absent(),
                Value<int> day1 = const Value.absent(),
                Value<int> day2 = const Value.absent(),
                Value<int> weeks = const Value.absent(),
                Value<String?> anchor = const Value.absent(),
                Value<bool> weekendBefore = const Value.absent(),
                Value<bool> weekendKeep = const Value.absent(),
                Value<bool> definesPeriod = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => PaySchedulesCompanion(
                id: id,
                categoryId: categoryId,
                accountId: accountId,
                payee: payee,
                name: name,
                amountMinor: amountMinor,
                amount2Minor: amount2Minor,
                varies: varies,
                rule: rule,
                day1: day1,
                day2: day2,
                weeks: weeks,
                anchor: anchor,
                weekendBefore: weekendBefore,
                weekendKeep: weekendKeep,
                definesPeriod: definesPeriod,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int categoryId,
                required int accountId,
                Value<String?> payee = const Value.absent(),
                Value<String?> name = const Value.absent(),
                required int amountMinor,
                Value<int?> amount2Minor = const Value.absent(),
                Value<bool> varies = const Value.absent(),
                required PayRule rule,
                Value<int> day1 = const Value.absent(),
                Value<int> day2 = const Value.absent(),
                Value<int> weeks = const Value.absent(),
                Value<String?> anchor = const Value.absent(),
                Value<bool> weekendBefore = const Value.absent(),
                Value<bool> weekendKeep = const Value.absent(),
                Value<bool> definesPeriod = const Value.absent(),
                required int createdAt,
                Value<int?> deletedAt = const Value.absent(),
              }) => PaySchedulesCompanion.insert(
                id: id,
                categoryId: categoryId,
                accountId: accountId,
                payee: payee,
                name: name,
                amountMinor: amountMinor,
                amount2Minor: amount2Minor,
                varies: varies,
                rule: rule,
                day1: day1,
                day2: day2,
                weeks: weeks,
                anchor: anchor,
                weekendBefore: weekendBefore,
                weekendKeep: weekendKeep,
                definesPeriod: definesPeriod,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PaySchedulesTable, PayScheduleRow>(table),
                  $$PaySchedulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                accountId = false,
                transactionsRefs = false,
                categoryPlansRefs = false,
                payeeRulesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                    if (categoryPlansRefs) db.categoryPlans,
                    if (payeeRulesRefs) db.payeeRules,
                  ],
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
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$PaySchedulesTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$PaySchedulesTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (accountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountId,
                            referencedTable: $$PaySchedulesTableReferences
                                ._accountIdTable(db),
                            referencedColumn: $$PaySchedulesTableReferences
                                ._accountIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          PayScheduleRow,
                          $PaySchedulesTable,
                          TransactionRow
                        >(
                          currentTable: table,
                          referencedTable: $$PaySchedulesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PaySchedulesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.payScheduleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (categoryPlansRefs)
                        await $_getPrefetchedData<
                          PayScheduleRow,
                          $PaySchedulesTable,
                          CategoryPlanRow
                        >(
                          currentTable: table,
                          referencedTable: $$PaySchedulesTableReferences
                              ._categoryPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PaySchedulesTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryPlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.payScheduleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (payeeRulesRefs)
                        await $_getPrefetchedData<
                          PayScheduleRow,
                          $PaySchedulesTable,
                          PayeeRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$PaySchedulesTableReferences
                              ._payeeRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PaySchedulesTableReferences(
                                db,
                                table,
                                p0,
                              ).payeeRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.payScheduleId == item.id,
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

typedef $$PaySchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaySchedulesTable,
      PayScheduleRow,
      $$PaySchedulesTableFilterComposer,
      $$PaySchedulesTableOrderingComposer,
      $$PaySchedulesTableAnnotationComposer,
      $$PaySchedulesTableCreateCompanionBuilder,
      $$PaySchedulesTableUpdateCompanionBuilder,
      (PayScheduleRow, $$PaySchedulesTableReferences),
      PayScheduleRow,
      PrefetchHooks Function({
        bool categoryId,
        bool accountId,
        bool transactionsRefs,
        bool categoryPlansRefs,
        bool payeeRulesRefs,
      })
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
      Value<int?> payScheduleId,
      Value<int?> planCategoryId,
      Value<String?> madeHow,
      Value<String?> madeOn,
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
      Value<int?> payScheduleId,
      Value<int?> planCategoryId,
      Value<String?> madeHow,
      Value<String?> madeOn,
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

  static $PaySchedulesTable _payScheduleIdTable(_$AppDatabase db) => db
      .paySchedules
      .createAlias('transactions__pay_schedule_id__pay_schedules__id');

  $$PaySchedulesTableProcessedTableManager? get payScheduleId {
    final $_column = $_itemColumn<int>('pay_schedule_id');
    if ($_column == null) return null;
    final manager = $$PaySchedulesTableTableManager(
      $_db,
      $_db.paySchedules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payScheduleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _planCategoryIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('transactions__plan_category_id__accounts__id');

  $$AccountsTableProcessedTableManager? get planCategoryId {
    final $_column = $_itemColumn<int>('plan_category_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planCategoryIdTable($_db));
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

  ColumnFilters<String> get madeHow => $composableBuilder(
    column: $table.madeHow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get madeOn => $composableBuilder(
    column: $table.madeOn,
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

  $$PaySchedulesTableFilterComposer get payScheduleId {
    final $$PaySchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableFilterComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get planCategoryId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planCategoryId,
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

  ColumnOrderings<String> get madeHow => $composableBuilder(
    column: $table.madeHow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get madeOn => $composableBuilder(
    column: $table.madeOn,
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

  $$PaySchedulesTableOrderingComposer get payScheduleId {
    final $$PaySchedulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableOrderingComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get planCategoryId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planCategoryId,
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

  GeneratedColumn<String> get madeHow =>
      $composableBuilder(column: $table.madeHow, builder: (column) => column);

  GeneratedColumn<String> get madeOn =>
      $composableBuilder(column: $table.madeOn, builder: (column) => column);

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

  $$PaySchedulesTableAnnotationComposer get payScheduleId {
    final $$PaySchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get planCategoryId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planCategoryId,
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
          PrefetchHooks Function({
            bool payeeId,
            bool payScheduleId,
            bool planCategoryId,
            bool entriesRefs,
          })
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
                Value<int?> payScheduleId = const Value.absent(),
                Value<int?> planCategoryId = const Value.absent(),
                Value<String?> madeHow = const Value.absent(),
                Value<String?> madeOn = const Value.absent(),
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
                payScheduleId: payScheduleId,
                planCategoryId: planCategoryId,
                madeHow: madeHow,
                madeOn: madeOn,
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
                Value<int?> payScheduleId = const Value.absent(),
                Value<int?> planCategoryId = const Value.absent(),
                Value<String?> madeHow = const Value.absent(),
                Value<String?> madeOn = const Value.absent(),
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
                payScheduleId: payScheduleId,
                planCategoryId: planCategoryId,
                madeHow: madeHow,
                madeOn: madeOn,
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
          prefetchHooksCallback:
              ({
                payeeId = false,
                payScheduleId = false,
                planCategoryId = false,
                entriesRefs = false,
              }) {
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
                        if (payScheduleId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.payScheduleId,
                            referencedTable: $$TransactionsTableReferences
                                ._payScheduleIdTable(db),
                            referencedColumn: $$TransactionsTableReferences
                                ._payScheduleIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (planCategoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.planCategoryId,
                            referencedTable: $$TransactionsTableReferences
                                ._planCategoryIdTable(db),
                            referencedColumn: $$TransactionsTableReferences
                                ._planCategoryIdTable(db)
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
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
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
      PrefetchHooks Function({
        bool payeeId,
        bool payScheduleId,
        bool planCategoryId,
        bool entriesRefs,
      })
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
  Value<String?> importKey,
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
  Value<String?> importKey,
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

  ColumnFilters<String> get importKey => $composableBuilder(
    column: $table.importKey,
    builder: (column) => ColumnFilters(column),
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

  ColumnOrderings<String> get importKey => $composableBuilder(
    column: $table.importKey,
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

  GeneratedColumn<String> get importKey =>
      $composableBuilder(column: $table.importKey, builder: (column) => column);

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
                Value<String?> importKey = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                transactionId: transactionId,
                accountId: accountId,
                amountMinor: amountMinor,
                currency: currency,
                rate: rate,
                cleared: cleared,
                reconciliationId: reconciliationId,
                importKey: importKey,
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
                Value<String?> importKey = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                transactionId: transactionId,
                accountId: accountId,
                amountMinor: amountMinor,
                currency: currency,
                rate: rate,
                cleared: cleared,
                reconciliationId: reconciliationId,
                importKey: importKey,
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
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferencesTable,
          PreferenceRow,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            PreferenceRow,
            BaseReferences<_$AppDatabase, $PreferencesTable, PreferenceRow>,
          ),
          PreferenceRow,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$AppDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferencesTable, PreferenceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PreferencesTable,
                    PreferenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferencesTable,
      PreferenceRow,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        PreferenceRow,
        BaseReferences<_$AppDatabase, $PreferencesTable, PreferenceRow>,
      ),
      PreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$BudgetAmountsTableCreateCompanionBuilder =
    BudgetAmountsCompanion Function({
      Value<int> id,
      required int categoryId,
      required String date,
      required int amountMinor,
    });
typedef $$BudgetAmountsTableUpdateCompanionBuilder =
    BudgetAmountsCompanion Function({
      Value<int> id,
      Value<int> categoryId,
      Value<String> date,
      Value<int> amountMinor,
    });

final class $$BudgetAmountsTableReferences
    extends
        BaseReferences<_$AppDatabase, $BudgetAmountsTable, BudgetAmountRow> {
  $$BudgetAmountsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _categoryIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('budget_amounts__category_id__accounts__id');

  $$AccountsTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetAmountsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetAmountsTable> {
  $$BudgetAmountsTableFilterComposer({
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

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get categoryId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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
}

class $$BudgetAmountsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetAmountsTable> {
  $$BudgetAmountsTableOrderingComposer({
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

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get categoryId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

class $$BudgetAmountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetAmountsTable> {
  $$BudgetAmountsTableAnnotationComposer({
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

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get categoryId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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
}

class $$BudgetAmountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetAmountsTable,
          BudgetAmountRow,
          $$BudgetAmountsTableFilterComposer,
          $$BudgetAmountsTableOrderingComposer,
          $$BudgetAmountsTableAnnotationComposer,
          $$BudgetAmountsTableCreateCompanionBuilder,
          $$BudgetAmountsTableUpdateCompanionBuilder,
          (BudgetAmountRow, $$BudgetAmountsTableReferences),
          BudgetAmountRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$BudgetAmountsTableTableManager(_$AppDatabase db, $BudgetAmountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetAmountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetAmountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetAmountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
              }) => BudgetAmountsCompanion(
                id: id,
                categoryId: categoryId,
                date: date,
                amountMinor: amountMinor,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int categoryId,
                required String date,
                required int amountMinor,
              }) => BudgetAmountsCompanion.insert(
                id: id,
                categoryId: categoryId,
                date: date,
                amountMinor: amountMinor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetAmountsTable, BudgetAmountRow>(table),
                  $$BudgetAmountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
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
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$BudgetAmountsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$BudgetAmountsTableReferences
                            ._categoryIdTable(db)
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

typedef $$BudgetAmountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetAmountsTable,
      BudgetAmountRow,
      $$BudgetAmountsTableFilterComposer,
      $$BudgetAmountsTableOrderingComposer,
      $$BudgetAmountsTableAnnotationComposer,
      $$BudgetAmountsTableCreateCompanionBuilder,
      $$BudgetAmountsTableUpdateCompanionBuilder,
      (BudgetAmountRow, $$BudgetAmountsTableReferences),
      BudgetAmountRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$CategoryPlansTableCreateCompanionBuilder =
    CategoryPlansCompanion Function({
      Value<int> categoryId,
      required PlanKind kind,
      required int amountMinor,
      required String start,
      Value<String?> due,
      Value<int?> everyMonths,
      Value<int?> everyDays,
      Value<String?> onDates,
      Value<int?> payScheduleId,
      Value<int> daysAfterPay,
      Value<PayWeekend> weekend,
      Value<String?> weekdays,
      Value<int?> nth,
      Value<int?> nthWeekday,
      Value<String?> endDate,
      Value<int?> endCount,
      Value<bool> rollover,
      Value<int?> upToMinor,
      Value<int?> paidFromId,
      Value<String?> once,
    });
typedef $$CategoryPlansTableUpdateCompanionBuilder =
    CategoryPlansCompanion Function({
      Value<int> categoryId,
      Value<PlanKind> kind,
      Value<int> amountMinor,
      Value<String> start,
      Value<String?> due,
      Value<int?> everyMonths,
      Value<int?> everyDays,
      Value<String?> onDates,
      Value<int?> payScheduleId,
      Value<int> daysAfterPay,
      Value<PayWeekend> weekend,
      Value<String?> weekdays,
      Value<int?> nth,
      Value<int?> nthWeekday,
      Value<String?> endDate,
      Value<int?> endCount,
      Value<bool> rollover,
      Value<int?> upToMinor,
      Value<int?> paidFromId,
      Value<String?> once,
    });

final class $$CategoryPlansTableReferences
    extends
        BaseReferences<_$AppDatabase, $CategoryPlansTable, CategoryPlanRow> {
  $$CategoryPlansTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _categoryIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('category_plans__category_id__accounts__id');

  $$AccountsTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PaySchedulesTable _payScheduleIdTable(_$AppDatabase db) => db
      .paySchedules
      .createAlias('category_plans__pay_schedule_id__pay_schedules__id');

  $$PaySchedulesTableProcessedTableManager? get payScheduleId {
    final $_column = $_itemColumn<int>('pay_schedule_id');
    if ($_column == null) return null;
    final manager = $$PaySchedulesTableTableManager(
      $_db,
      $_db.paySchedules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payScheduleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _paidFromIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('category_plans__paid_from_id__accounts__id');

  $$AccountsTableProcessedTableManager? get paidFromId {
    final $_column = $_itemColumn<int>('paid_from_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_paidFromIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoryPlansTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryPlansTable> {
  $$CategoryPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<PlanKind, PlanKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get everyMonths => $composableBuilder(
    column: $table.everyMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get everyDays => $composableBuilder(
    column: $table.everyDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get onDates => $composableBuilder(
    column: $table.onDates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get daysAfterPay => $composableBuilder(
    column: $table.daysAfterPay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PayWeekend, PayWeekend, String> get weekend =>
      $composableBuilder(
        column: $table.weekend,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nth => $composableBuilder(
    column: $table.nth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nthWeekday => $composableBuilder(
    column: $table.nthWeekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endCount => $composableBuilder(
    column: $table.endCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rollover => $composableBuilder(
    column: $table.rollover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upToMinor => $composableBuilder(
    column: $table.upToMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get once => $composableBuilder(
    column: $table.once,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get categoryId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

  $$PaySchedulesTableFilterComposer get payScheduleId {
    final $$PaySchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableFilterComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get paidFromId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paidFromId,
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
}

class $$CategoryPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryPlansTable> {
  $$CategoryPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get everyMonths => $composableBuilder(
    column: $table.everyMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get everyDays => $composableBuilder(
    column: $table.everyDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get onDates => $composableBuilder(
    column: $table.onDates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get daysAfterPay => $composableBuilder(
    column: $table.daysAfterPay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekend => $composableBuilder(
    column: $table.weekend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekdays => $composableBuilder(
    column: $table.weekdays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nth => $composableBuilder(
    column: $table.nth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nthWeekday => $composableBuilder(
    column: $table.nthWeekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endCount => $composableBuilder(
    column: $table.endCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rollover => $composableBuilder(
    column: $table.rollover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upToMinor => $composableBuilder(
    column: $table.upToMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get once => $composableBuilder(
    column: $table.once,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get categoryId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

  $$PaySchedulesTableOrderingComposer get payScheduleId {
    final $$PaySchedulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableOrderingComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get paidFromId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paidFromId,
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

class $$CategoryPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryPlansTable> {
  $$CategoryPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<PlanKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<String> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<int> get everyMonths => $composableBuilder(
    column: $table.everyMonths,
    builder: (column) => column,
  );

  GeneratedColumn<int> get everyDays =>
      $composableBuilder(column: $table.everyDays, builder: (column) => column);

  GeneratedColumn<String> get onDates =>
      $composableBuilder(column: $table.onDates, builder: (column) => column);

  GeneratedColumn<int> get daysAfterPay => $composableBuilder(
    column: $table.daysAfterPay,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PayWeekend, String> get weekend =>
      $composableBuilder(column: $table.weekend, builder: (column) => column);

  GeneratedColumn<String> get weekdays =>
      $composableBuilder(column: $table.weekdays, builder: (column) => column);

  GeneratedColumn<int> get nth =>
      $composableBuilder(column: $table.nth, builder: (column) => column);

  GeneratedColumn<int> get nthWeekday => $composableBuilder(
    column: $table.nthWeekday,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get endCount =>
      $composableBuilder(column: $table.endCount, builder: (column) => column);

  GeneratedColumn<bool> get rollover =>
      $composableBuilder(column: $table.rollover, builder: (column) => column);

  GeneratedColumn<int> get upToMinor =>
      $composableBuilder(column: $table.upToMinor, builder: (column) => column);

  GeneratedColumn<String> get once =>
      $composableBuilder(column: $table.once, builder: (column) => column);

  $$AccountsTableAnnotationComposer get categoryId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

  $$PaySchedulesTableAnnotationComposer get payScheduleId {
    final $$PaySchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get paidFromId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paidFromId,
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
}

class $$CategoryPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryPlansTable,
          CategoryPlanRow,
          $$CategoryPlansTableFilterComposer,
          $$CategoryPlansTableOrderingComposer,
          $$CategoryPlansTableAnnotationComposer,
          $$CategoryPlansTableCreateCompanionBuilder,
          $$CategoryPlansTableUpdateCompanionBuilder,
          (CategoryPlanRow, $$CategoryPlansTableReferences),
          CategoryPlanRow,
          PrefetchHooks Function({
            bool categoryId,
            bool payScheduleId,
            bool paidFromId,
          })
        > {
  $$CategoryPlansTableTableManager(_$AppDatabase db, $CategoryPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> categoryId = const Value.absent(),
                Value<PlanKind> kind = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> start = const Value.absent(),
                Value<String?> due = const Value.absent(),
                Value<int?> everyMonths = const Value.absent(),
                Value<int?> everyDays = const Value.absent(),
                Value<String?> onDates = const Value.absent(),
                Value<int?> payScheduleId = const Value.absent(),
                Value<int> daysAfterPay = const Value.absent(),
                Value<PayWeekend> weekend = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<int?> nth = const Value.absent(),
                Value<int?> nthWeekday = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<int?> endCount = const Value.absent(),
                Value<bool> rollover = const Value.absent(),
                Value<int?> upToMinor = const Value.absent(),
                Value<int?> paidFromId = const Value.absent(),
                Value<String?> once = const Value.absent(),
              }) => CategoryPlansCompanion(
                categoryId: categoryId,
                kind: kind,
                amountMinor: amountMinor,
                start: start,
                due: due,
                everyMonths: everyMonths,
                everyDays: everyDays,
                onDates: onDates,
                payScheduleId: payScheduleId,
                daysAfterPay: daysAfterPay,
                weekend: weekend,
                weekdays: weekdays,
                nth: nth,
                nthWeekday: nthWeekday,
                endDate: endDate,
                endCount: endCount,
                rollover: rollover,
                upToMinor: upToMinor,
                paidFromId: paidFromId,
                once: once,
              ),
          createCompanionCallback:
              ({
                Value<int> categoryId = const Value.absent(),
                required PlanKind kind,
                required int amountMinor,
                required String start,
                Value<String?> due = const Value.absent(),
                Value<int?> everyMonths = const Value.absent(),
                Value<int?> everyDays = const Value.absent(),
                Value<String?> onDates = const Value.absent(),
                Value<int?> payScheduleId = const Value.absent(),
                Value<int> daysAfterPay = const Value.absent(),
                Value<PayWeekend> weekend = const Value.absent(),
                Value<String?> weekdays = const Value.absent(),
                Value<int?> nth = const Value.absent(),
                Value<int?> nthWeekday = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<int?> endCount = const Value.absent(),
                Value<bool> rollover = const Value.absent(),
                Value<int?> upToMinor = const Value.absent(),
                Value<int?> paidFromId = const Value.absent(),
                Value<String?> once = const Value.absent(),
              }) => CategoryPlansCompanion.insert(
                categoryId: categoryId,
                kind: kind,
                amountMinor: amountMinor,
                start: start,
                due: due,
                everyMonths: everyMonths,
                everyDays: everyDays,
                onDates: onDates,
                payScheduleId: payScheduleId,
                daysAfterPay: daysAfterPay,
                weekend: weekend,
                weekdays: weekdays,
                nth: nth,
                nthWeekday: nthWeekday,
                endDate: endDate,
                endCount: endCount,
                rollover: rollover,
                upToMinor: upToMinor,
                paidFromId: paidFromId,
                once: once,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryPlansTable, CategoryPlanRow>(table),
                  $$CategoryPlansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                payScheduleId = false,
                paidFromId = false,
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
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$CategoryPlansTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$CategoryPlansTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (payScheduleId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.payScheduleId,
                            referencedTable: $$CategoryPlansTableReferences
                                ._payScheduleIdTable(db),
                            referencedColumn: $$CategoryPlansTableReferences
                                ._payScheduleIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (paidFromId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.paidFromId,
                            referencedTable: $$CategoryPlansTableReferences
                                ._paidFromIdTable(db),
                            referencedColumn: $$CategoryPlansTableReferences
                                ._paidFromIdTable(db)
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

typedef $$CategoryPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryPlansTable,
      CategoryPlanRow,
      $$CategoryPlansTableFilterComposer,
      $$CategoryPlansTableOrderingComposer,
      $$CategoryPlansTableAnnotationComposer,
      $$CategoryPlansTableCreateCompanionBuilder,
      $$CategoryPlansTableUpdateCompanionBuilder,
      (CategoryPlanRow, $$CategoryPlansTableReferences),
      CategoryPlanRow,
      PrefetchHooks Function({
        bool categoryId,
        bool payScheduleId,
        bool paidFromId,
      })
    >;
typedef $$CategoryAccountsOffTableCreateCompanionBuilder =
    CategoryAccountsOffCompanion Function({
      required int categoryId,
      required int accountId,
      Value<int> rowid,
    });
typedef $$CategoryAccountsOffTableUpdateCompanionBuilder =
    CategoryAccountsOffCompanion Function({
      Value<int> categoryId,
      Value<int> accountId,
      Value<int> rowid,
    });

final class $$CategoryAccountsOffTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CategoryAccountsOffTable,
          CategoryAccountOffRow
        > {
  $$CategoryAccountsOffTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _categoryIdTable(_$AppDatabase db) => db.accounts
      .createAlias('category_accounts_off__category_id__accounts__id');

  $$AccountsTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountIdTable(_$AppDatabase db) => db.accounts
      .createAlias('category_accounts_off__account_id__accounts__id');

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
}

class $$CategoryAccountsOffTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryAccountsOffTable> {
  $$CategoryAccountsOffTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$AccountsTableFilterComposer get categoryId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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
}

class $$CategoryAccountsOffTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryAccountsOffTable> {
  $$CategoryAccountsOffTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$AccountsTableOrderingComposer get categoryId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

class $$CategoryAccountsOffTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryAccountsOffTable> {
  $$CategoryAccountsOffTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$AccountsTableAnnotationComposer get categoryId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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
}

class $$CategoryAccountsOffTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryAccountsOffTable,
          CategoryAccountOffRow,
          $$CategoryAccountsOffTableFilterComposer,
          $$CategoryAccountsOffTableOrderingComposer,
          $$CategoryAccountsOffTableAnnotationComposer,
          $$CategoryAccountsOffTableCreateCompanionBuilder,
          $$CategoryAccountsOffTableUpdateCompanionBuilder,
          (CategoryAccountOffRow, $$CategoryAccountsOffTableReferences),
          CategoryAccountOffRow,
          PrefetchHooks Function({bool categoryId, bool accountId})
        > {
  $$CategoryAccountsOffTableTableManager(
    _$AppDatabase db,
    $CategoryAccountsOffTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryAccountsOffTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryAccountsOffTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CategoryAccountsOffTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> categoryId = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryAccountsOffCompanion(
                categoryId: categoryId,
                accountId: accountId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int categoryId,
                required int accountId,
                Value<int> rowid = const Value.absent(),
              }) => CategoryAccountsOffCompanion.insert(
                categoryId: categoryId,
                accountId: accountId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryAccountsOffTable, CategoryAccountOffRow>(
                    table,
                  ),
                  $$CategoryAccountsOffTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, accountId = false}) {
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
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$CategoryAccountsOffTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$CategoryAccountsOffTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$CategoryAccountsOffTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$CategoryAccountsOffTableReferences
                            ._accountIdTable(db)
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

typedef $$CategoryAccountsOffTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryAccountsOffTable,
      CategoryAccountOffRow,
      $$CategoryAccountsOffTableFilterComposer,
      $$CategoryAccountsOffTableOrderingComposer,
      $$CategoryAccountsOffTableAnnotationComposer,
      $$CategoryAccountsOffTableCreateCompanionBuilder,
      $$CategoryAccountsOffTableUpdateCompanionBuilder,
      (CategoryAccountOffRow, $$CategoryAccountsOffTableReferences),
      CategoryAccountOffRow,
      PrefetchHooks Function({bool categoryId, bool accountId})
    >;
typedef $$CategoryPaidFromTableCreateCompanionBuilder =
    CategoryPaidFromCompanion Function({
      Value<int> categoryId,
      required int accountId,
    });
typedef $$CategoryPaidFromTableUpdateCompanionBuilder =
    CategoryPaidFromCompanion Function({
      Value<int> categoryId,
      Value<int> accountId,
    });

final class $$CategoryPaidFromTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CategoryPaidFromTable,
          CategoryPaidFromRow
        > {
  $$CategoryPaidFromTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _categoryIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('category_paid_from__category_id__accounts__id');

  $$AccountsTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('category_paid_from__account_id__accounts__id');

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
}

class $$CategoryPaidFromTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryPaidFromTable> {
  $$CategoryPaidFromTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$AccountsTableFilterComposer get categoryId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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
}

class $$CategoryPaidFromTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryPaidFromTable> {
  $$CategoryPaidFromTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$AccountsTableOrderingComposer get categoryId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

class $$CategoryPaidFromTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryPaidFromTable> {
  $$CategoryPaidFromTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$AccountsTableAnnotationComposer get categoryId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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
}

class $$CategoryPaidFromTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryPaidFromTable,
          CategoryPaidFromRow,
          $$CategoryPaidFromTableFilterComposer,
          $$CategoryPaidFromTableOrderingComposer,
          $$CategoryPaidFromTableAnnotationComposer,
          $$CategoryPaidFromTableCreateCompanionBuilder,
          $$CategoryPaidFromTableUpdateCompanionBuilder,
          (CategoryPaidFromRow, $$CategoryPaidFromTableReferences),
          CategoryPaidFromRow,
          PrefetchHooks Function({bool categoryId, bool accountId})
        > {
  $$CategoryPaidFromTableTableManager(
    _$AppDatabase db,
    $CategoryPaidFromTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryPaidFromTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryPaidFromTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryPaidFromTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> categoryId = const Value.absent(),
                Value<int> accountId = const Value.absent(),
              }) => CategoryPaidFromCompanion(
                categoryId: categoryId,
                accountId: accountId,
              ),
          createCompanionCallback:
              ({
                Value<int> categoryId = const Value.absent(),
                required int accountId,
              }) => CategoryPaidFromCompanion.insert(
                categoryId: categoryId,
                accountId: accountId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryPaidFromTable, CategoryPaidFromRow>(
                    table,
                  ),
                  $$CategoryPaidFromTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, accountId = false}) {
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
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$CategoryPaidFromTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$CategoryPaidFromTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$CategoryPaidFromTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$CategoryPaidFromTableReferences
                            ._accountIdTable(db)
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

typedef $$CategoryPaidFromTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryPaidFromTable,
      CategoryPaidFromRow,
      $$CategoryPaidFromTableFilterComposer,
      $$CategoryPaidFromTableOrderingComposer,
      $$CategoryPaidFromTableAnnotationComposer,
      $$CategoryPaidFromTableCreateCompanionBuilder,
      $$CategoryPaidFromTableUpdateCompanionBuilder,
      (CategoryPaidFromRow, $$CategoryPaidFromTableReferences),
      CategoryPaidFromRow,
      PrefetchHooks Function({bool categoryId, bool accountId})
    >;
typedef $$PayeeRulesTableCreateCompanionBuilder = PayeeRulesCompanion Function({
  Value<int> id,
  required String words,
  required String name,
  Value<bool> anywhere,
  required int categoryId,
  Value<int?> payScheduleId,
  required int createdAt,
  Value<int?> deletedAt,
});
typedef $$PayeeRulesTableUpdateCompanionBuilder = PayeeRulesCompanion Function({
  Value<int> id,
  Value<String> words,
  Value<String> name,
  Value<bool> anywhere,
  Value<int> categoryId,
  Value<int?> payScheduleId,
  Value<int> createdAt,
  Value<int?> deletedAt,
});

final class $$PayeeRulesTableReferences
    extends BaseReferences<_$AppDatabase, $PayeeRulesTable, PayeeRuleRow> {
  $$PayeeRulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _categoryIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('payee_rules__category_id__accounts__id');

  $$AccountsTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PaySchedulesTable _payScheduleIdTable(_$AppDatabase db) => db
      .paySchedules
      .createAlias('payee_rules__pay_schedule_id__pay_schedules__id');

  $$PaySchedulesTableProcessedTableManager? get payScheduleId {
    final $_column = $_itemColumn<int>('pay_schedule_id');
    if ($_column == null) return null;
    final manager = $$PaySchedulesTableTableManager(
      $_db,
      $_db.paySchedules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_payScheduleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PayeeRuleAccountsTable, List<PayeeRuleAccountRow>>
  _payeeRuleAccountsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.payeeRuleAccounts,
        aliasName: 'payee_rules__id__payee_rule_accounts__rule_id',
      );

  $$PayeeRuleAccountsTableProcessedTableManager get payeeRuleAccountsRefs {
    final manager = $$PayeeRuleAccountsTableTableManager(
      $_db,
      $_db.payeeRuleAccounts,
    ).filter((f) => f.ruleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _payeeRuleAccountsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PayeeRulesTableFilterComposer
    extends Composer<_$AppDatabase, $PayeeRulesTable> {
  $$PayeeRulesTableFilterComposer({
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

  ColumnFilters<String> get words => $composableBuilder(
    column: $table.words,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get anywhere => $composableBuilder(
    column: $table.anywhere,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get categoryId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

  $$PaySchedulesTableFilterComposer get payScheduleId {
    final $$PaySchedulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableFilterComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> payeeRuleAccountsRefs(
    Expression<bool> Function($$PayeeRuleAccountsTableFilterComposer f) f,
  ) {
    final $$PayeeRuleAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payeeRuleAccounts,
      getReferencedColumn: (t) => t.ruleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRuleAccountsTableFilterComposer(
            $db: $db,
            $table: $db.payeeRuleAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PayeeRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $PayeeRulesTable> {
  $$PayeeRulesTableOrderingComposer({
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

  ColumnOrderings<String> get words => $composableBuilder(
    column: $table.words,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get anywhere => $composableBuilder(
    column: $table.anywhere,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get categoryId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

  $$PaySchedulesTableOrderingComposer get payScheduleId {
    final $$PaySchedulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableOrderingComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PayeeRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayeeRulesTable> {
  $$PayeeRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get words =>
      $composableBuilder(column: $table.words, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get anywhere =>
      $composableBuilder(column: $table.anywhere, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get categoryId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
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

  $$PaySchedulesTableAnnotationComposer get payScheduleId {
    final $$PaySchedulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.payScheduleId,
      referencedTable: $db.paySchedules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaySchedulesTableAnnotationComposer(
            $db: $db,
            $table: $db.paySchedules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> payeeRuleAccountsRefs<T extends Object>(
    Expression<T> Function($$PayeeRuleAccountsTableAnnotationComposer a) f,
  ) {
    final $$PayeeRuleAccountsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.payeeRuleAccounts,
          getReferencedColumn: (t) => t.ruleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PayeeRuleAccountsTableAnnotationComposer(
                $db: $db,
                $table: $db.payeeRuleAccounts,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PayeeRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayeeRulesTable,
          PayeeRuleRow,
          $$PayeeRulesTableFilterComposer,
          $$PayeeRulesTableOrderingComposer,
          $$PayeeRulesTableAnnotationComposer,
          $$PayeeRulesTableCreateCompanionBuilder,
          $$PayeeRulesTableUpdateCompanionBuilder,
          (PayeeRuleRow, $$PayeeRulesTableReferences),
          PayeeRuleRow,
          PrefetchHooks Function({
            bool categoryId,
            bool payScheduleId,
            bool payeeRuleAccountsRefs,
          })
        > {
  $$PayeeRulesTableTableManager(_$AppDatabase db, $PayeeRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayeeRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayeeRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayeeRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> words = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> anywhere = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<int?> payScheduleId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
              }) => PayeeRulesCompanion(
                id: id,
                words: words,
                name: name,
                anywhere: anywhere,
                categoryId: categoryId,
                payScheduleId: payScheduleId,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String words,
                required String name,
                Value<bool> anywhere = const Value.absent(),
                required int categoryId,
                Value<int?> payScheduleId = const Value.absent(),
                required int createdAt,
                Value<int?> deletedAt = const Value.absent(),
              }) => PayeeRulesCompanion.insert(
                id: id,
                words: words,
                name: name,
                anywhere: anywhere,
                categoryId: categoryId,
                payScheduleId: payScheduleId,
                createdAt: createdAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayeeRulesTable, PayeeRuleRow>(table),
                  $$PayeeRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                payScheduleId = false,
                payeeRuleAccountsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (payeeRuleAccountsRefs) db.payeeRuleAccounts,
                  ],
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
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$PayeeRulesTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$PayeeRulesTableReferences
                                ._categoryIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (payScheduleId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.payScheduleId,
                            referencedTable: $$PayeeRulesTableReferences
                                ._payScheduleIdTable(db),
                            referencedColumn: $$PayeeRulesTableReferences
                                ._payScheduleIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (payeeRuleAccountsRefs)
                        await $_getPrefetchedData<
                          PayeeRuleRow,
                          $PayeeRulesTable,
                          PayeeRuleAccountRow
                        >(
                          currentTable: table,
                          referencedTable: $$PayeeRulesTableReferences
                              ._payeeRuleAccountsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PayeeRulesTableReferences(
                                db,
                                table,
                                p0,
                              ).payeeRuleAccountsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ruleId == item.id,
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

typedef $$PayeeRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayeeRulesTable,
      PayeeRuleRow,
      $$PayeeRulesTableFilterComposer,
      $$PayeeRulesTableOrderingComposer,
      $$PayeeRulesTableAnnotationComposer,
      $$PayeeRulesTableCreateCompanionBuilder,
      $$PayeeRulesTableUpdateCompanionBuilder,
      (PayeeRuleRow, $$PayeeRulesTableReferences),
      PayeeRuleRow,
      PrefetchHooks Function({
        bool categoryId,
        bool payScheduleId,
        bool payeeRuleAccountsRefs,
      })
    >;
typedef $$PayeeRuleAccountsTableCreateCompanionBuilder =
    PayeeRuleAccountsCompanion Function({
      required int ruleId,
      required int accountId,
      Value<int> rowid,
    });
typedef $$PayeeRuleAccountsTableUpdateCompanionBuilder =
    PayeeRuleAccountsCompanion Function({
      Value<int> ruleId,
      Value<int> accountId,
      Value<int> rowid,
    });

final class $$PayeeRuleAccountsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PayeeRuleAccountsTable,
          PayeeRuleAccountRow
        > {
  $$PayeeRuleAccountsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PayeeRulesTable _ruleIdTable(_$AppDatabase db) => db.payeeRules
      .createAlias('payee_rule_accounts__rule_id__payee_rules__id');

  $$PayeeRulesTableProcessedTableManager get ruleId {
    final $_column = $_itemColumn<int>('rule_id')!;

    final manager = $$PayeeRulesTableTableManager(
      $_db,
      $_db.payeeRules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ruleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('payee_rule_accounts__account_id__accounts__id');

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
}

class $$PayeeRuleAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $PayeeRuleAccountsTable> {
  $$PayeeRuleAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PayeeRulesTableFilterComposer get ruleId {
    final $$PayeeRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.payeeRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRulesTableFilterComposer(
            $db: $db,
            $table: $db.payeeRules,
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
}

class $$PayeeRuleAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $PayeeRuleAccountsTable> {
  $$PayeeRuleAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PayeeRulesTableOrderingComposer get ruleId {
    final $$PayeeRulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.payeeRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRulesTableOrderingComposer(
            $db: $db,
            $table: $db.payeeRules,
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
}

class $$PayeeRuleAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayeeRuleAccountsTable> {
  $$PayeeRuleAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$PayeeRulesTableAnnotationComposer get ruleId {
    final $$PayeeRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ruleId,
      referencedTable: $db.payeeRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PayeeRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.payeeRules,
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
}

class $$PayeeRuleAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PayeeRuleAccountsTable,
          PayeeRuleAccountRow,
          $$PayeeRuleAccountsTableFilterComposer,
          $$PayeeRuleAccountsTableOrderingComposer,
          $$PayeeRuleAccountsTableAnnotationComposer,
          $$PayeeRuleAccountsTableCreateCompanionBuilder,
          $$PayeeRuleAccountsTableUpdateCompanionBuilder,
          (PayeeRuleAccountRow, $$PayeeRuleAccountsTableReferences),
          PayeeRuleAccountRow,
          PrefetchHooks Function({bool ruleId, bool accountId})
        > {
  $$PayeeRuleAccountsTableTableManager(
    _$AppDatabase db,
    $PayeeRuleAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayeeRuleAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayeeRuleAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayeeRuleAccountsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> ruleId = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PayeeRuleAccountsCompanion(
                ruleId: ruleId,
                accountId: accountId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int ruleId,
                required int accountId,
                Value<int> rowid = const Value.absent(),
              }) => PayeeRuleAccountsCompanion.insert(
                ruleId: ruleId,
                accountId: accountId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PayeeRuleAccountsTable, PayeeRuleAccountRow>(
                    table,
                  ),
                  $$PayeeRuleAccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ruleId = false, accountId = false}) {
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
                    if (ruleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.ruleId,
                        referencedTable: $$PayeeRuleAccountsTableReferences
                            ._ruleIdTable(db),
                        referencedColumn: $$PayeeRuleAccountsTableReferences
                            ._ruleIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$PayeeRuleAccountsTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$PayeeRuleAccountsTableReferences
                            ._accountIdTable(db)
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

typedef $$PayeeRuleAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PayeeRuleAccountsTable,
      PayeeRuleAccountRow,
      $$PayeeRuleAccountsTableFilterComposer,
      $$PayeeRuleAccountsTableOrderingComposer,
      $$PayeeRuleAccountsTableAnnotationComposer,
      $$PayeeRuleAccountsTableCreateCompanionBuilder,
      $$PayeeRuleAccountsTableUpdateCompanionBuilder,
      (PayeeRuleAccountRow, $$PayeeRuleAccountsTableReferences),
      PayeeRuleAccountRow,
      PrefetchHooks Function({bool ruleId, bool accountId})
    >;
typedef $$ChangesTableCreateCompanionBuilder = ChangesCompanion Function({
  Value<int> seq,
  required String tbl,
  required String pk,
  required String op,
  Value<String?> before,
  Value<String?> after,
  required int atMs,
  required int withSchema,
});
typedef $$ChangesTableUpdateCompanionBuilder = ChangesCompanion Function({
  Value<int> seq,
  Value<String> tbl,
  Value<String> pk,
  Value<String> op,
  Value<String?> before,
  Value<String?> after,
  Value<int> atMs,
  Value<int> withSchema,
});

class $$ChangesTableFilterComposer
    extends Composer<_$AppDatabase, $ChangesTable> {
  $$ChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tbl => $composableBuilder(
    column: $table.tbl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get before => $composableBuilder(
    column: $table.before,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get after => $composableBuilder(
    column: $table.after,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get withSchema => $composableBuilder(
    column: $table.withSchema,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChangesTable> {
  $$ChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tbl => $composableBuilder(
    column: $table.tbl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pk => $composableBuilder(
    column: $table.pk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get before => $composableBuilder(
    column: $table.before,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get after => $composableBuilder(
    column: $table.after,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get withSchema => $composableBuilder(
    column: $table.withSchema,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChangesTable> {
  $$ChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get tbl =>
      $composableBuilder(column: $table.tbl, builder: (column) => column);

  GeneratedColumn<String> get pk =>
      $composableBuilder(column: $table.pk, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get before =>
      $composableBuilder(column: $table.before, builder: (column) => column);

  GeneratedColumn<String> get after =>
      $composableBuilder(column: $table.after, builder: (column) => column);

  GeneratedColumn<int> get atMs =>
      $composableBuilder(column: $table.atMs, builder: (column) => column);

  GeneratedColumn<int> get withSchema => $composableBuilder(
    column: $table.withSchema,
    builder: (column) => column,
  );
}

class $$ChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChangesTable,
          ChangeRow,
          $$ChangesTableFilterComposer,
          $$ChangesTableOrderingComposer,
          $$ChangesTableAnnotationComposer,
          $$ChangesTableCreateCompanionBuilder,
          $$ChangesTableUpdateCompanionBuilder,
          (ChangeRow, BaseReferences<_$AppDatabase, $ChangesTable, ChangeRow>),
          ChangeRow,
          PrefetchHooks Function()
        > {
  $$ChangesTableTableManager(_$AppDatabase db, $ChangesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> tbl = const Value.absent(),
                Value<String> pk = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String?> before = const Value.absent(),
                Value<String?> after = const Value.absent(),
                Value<int> atMs = const Value.absent(),
                Value<int> withSchema = const Value.absent(),
              }) => ChangesCompanion(
                seq: seq,
                tbl: tbl,
                pk: pk,
                op: op,
                before: before,
                after: after,
                atMs: atMs,
                withSchema: withSchema,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String tbl,
                required String pk,
                required String op,
                Value<String?> before = const Value.absent(),
                Value<String?> after = const Value.absent(),
                required int atMs,
                required int withSchema,
              }) => ChangesCompanion.insert(
                seq: seq,
                tbl: tbl,
                pk: pk,
                op: op,
                before: before,
                after: after,
                atMs: atMs,
                withSchema: withSchema,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChangesTable, ChangeRow>(table),
                  BaseReferences<_$AppDatabase, $ChangesTable, ChangeRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChangesTable,
      ChangeRow,
      $$ChangesTableFilterComposer,
      $$ChangesTableOrderingComposer,
      $$ChangesTableAnnotationComposer,
      $$ChangesTableCreateCompanionBuilder,
      $$ChangesTableUpdateCompanionBuilder,
      (ChangeRow, BaseReferences<_$AppDatabase, $ChangesTable, ChangeRow>),
      ChangeRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$PaySchedulesTableTableManager get paySchedules =>
      $$PaySchedulesTableTableManager(_db, _db.paySchedules);
  $$PayeesTableTableManager get payees =>
      $$PayeesTableTableManager(_db, _db.payees);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$ReconciliationsTableTableManager get reconciliations =>
      $$ReconciliationsTableTableManager(_db, _db.reconciliations);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
  $$BudgetAmountsTableTableManager get budgetAmounts =>
      $$BudgetAmountsTableTableManager(_db, _db.budgetAmounts);
  $$CategoryPlansTableTableManager get categoryPlans =>
      $$CategoryPlansTableTableManager(_db, _db.categoryPlans);
  $$CategoryAccountsOffTableTableManager get categoryAccountsOff =>
      $$CategoryAccountsOffTableTableManager(_db, _db.categoryAccountsOff);
  $$CategoryPaidFromTableTableManager get categoryPaidFrom =>
      $$CategoryPaidFromTableTableManager(_db, _db.categoryPaidFrom);
  $$PayeeRulesTableTableManager get payeeRules =>
      $$PayeeRulesTableTableManager(_db, _db.payeeRules);
  $$PayeeRuleAccountsTableTableManager get payeeRuleAccounts =>
      $$PayeeRuleAccountsTableTableManager(_db, _db.payeeRuleAccounts);
  $$ChangesTableTableManager get changes =>
      $$ChangesTableTableManager(_db, _db.changes);
}
