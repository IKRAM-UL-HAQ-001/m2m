// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_service.dart';

// ignore_for_file: type=lint
class $ChatsTableTable extends ChatsTable
    with TableInfo<$ChatsTableTable, ChatEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiverIdMeta = const VerificationMeta(
    'receiverId',
  );
  @override
  late final GeneratedColumn<String> receiverId = GeneratedColumn<String>(
    'receiver_id',
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aboutMeta = const VerificationMeta('about');
  @override
  late final GeneratedColumn<String> about = GeneratedColumn<String>(
    'about',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageMeta = const VerificationMeta(
    'lastMessage',
  );
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
    'last_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageTypeMeta = const VerificationMeta(
    'lastMessageType',
  );
  @override
  late final GeneratedColumn<String> lastMessageType = GeneratedColumn<String>(
    'last_message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageStatus, String>
  lastMessageStatus = GeneratedColumn<String>(
    'last_message_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MessageStatus>($ChatsTableTable.$converterlastMessageStatus);
  static const VerificationMeta _lastMessageFileUrlMeta =
      const VerificationMeta('lastMessageFileUrl');
  @override
  late final GeneratedColumn<String> lastMessageFileUrl =
      GeneratedColumn<String>(
        'last_message_file_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isOnlineMeta = const VerificationMeta(
    'isOnline',
  );
  @override
  late final GeneratedColumn<bool> isOnline = GeneratedColumn<bool>(
    'is_online',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_online" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    receiverId,
    name,
    phone,
    about,
    avatarUrl,
    lastMessage,
    lastMessageType,
    lastMessageStatus,
    lastMessageFileUrl,
    time,
    unreadCount,
    isOnline,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chats_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('receiver_id')) {
      context.handle(
        _receiverIdMeta,
        receiverId.isAcceptableOrUnknown(data['receiver_id']!, _receiverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiverIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('about')) {
      context.handle(
        _aboutMeta,
        about.isAcceptableOrUnknown(data['about']!, _aboutMeta),
      );
    } else if (isInserting) {
      context.missing(_aboutMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_avatarUrlMeta);
    }
    if (data.containsKey('last_message')) {
      context.handle(
        _lastMessageMeta,
        lastMessage.isAcceptableOrUnknown(
          data['last_message']!,
          _lastMessageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastMessageMeta);
    }
    if (data.containsKey('last_message_type')) {
      context.handle(
        _lastMessageTypeMeta,
        lastMessageType.isAcceptableOrUnknown(
          data['last_message_type']!,
          _lastMessageTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastMessageTypeMeta);
    }
    if (data.containsKey('last_message_file_url')) {
      context.handle(
        _lastMessageFileUrlMeta,
        lastMessageFileUrl.isAcceptableOrUnknown(
          data['last_message_file_url']!,
          _lastMessageFileUrlMeta,
        ),
      );
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('is_online')) {
      context.handle(
        _isOnlineMeta,
        isOnline.isAcceptableOrUnknown(data['is_online']!, _isOnlineMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      receiverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receiver_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      about: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}about'],
      )!,
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      )!,
      lastMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message'],
      )!,
      lastMessageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_type'],
      )!,
      lastMessageStatus: $ChatsTableTable.$converterlastMessageStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}last_message_status'],
        )!,
      ),
      lastMessageFileUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_file_url'],
      ),
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}time'],
      )!,
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      isOnline: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_online'],
      )!,
    );
  }

  @override
  $ChatsTableTable createAlias(String alias) {
    return $ChatsTableTable(attachedDatabase, alias);
  }

  static TypeConverter<MessageStatus, String> $converterlastMessageStatus =
      const MessageStatusConverter();
}

class ChatEntity extends DataClass implements Insertable<ChatEntity> {
  final String id;
  final String receiverId;
  final String name;
  final String phone;
  final String about;
  final String avatarUrl;
  final String lastMessage;
  final String lastMessageType;
  final MessageStatus lastMessageStatus;
  final String? lastMessageFileUrl;
  final DateTime time;
  final int unreadCount;
  final bool isOnline;
  const ChatEntity({
    required this.id,
    required this.receiverId,
    required this.name,
    required this.phone,
    required this.about,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageStatus,
    this.lastMessageFileUrl,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['receiver_id'] = Variable<String>(receiverId);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    map['about'] = Variable<String>(about);
    map['avatar_url'] = Variable<String>(avatarUrl);
    map['last_message'] = Variable<String>(lastMessage);
    map['last_message_type'] = Variable<String>(lastMessageType);
    {
      map['last_message_status'] = Variable<String>(
        $ChatsTableTable.$converterlastMessageStatus.toSql(lastMessageStatus),
      );
    }
    if (!nullToAbsent || lastMessageFileUrl != null) {
      map['last_message_file_url'] = Variable<String>(lastMessageFileUrl);
    }
    map['time'] = Variable<DateTime>(time);
    map['unread_count'] = Variable<int>(unreadCount);
    map['is_online'] = Variable<bool>(isOnline);
    return map;
  }

  ChatsTableCompanion toCompanion(bool nullToAbsent) {
    return ChatsTableCompanion(
      id: Value(id),
      receiverId: Value(receiverId),
      name: Value(name),
      phone: Value(phone),
      about: Value(about),
      avatarUrl: Value(avatarUrl),
      lastMessage: Value(lastMessage),
      lastMessageType: Value(lastMessageType),
      lastMessageStatus: Value(lastMessageStatus),
      lastMessageFileUrl: lastMessageFileUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageFileUrl),
      time: Value(time),
      unreadCount: Value(unreadCount),
      isOnline: Value(isOnline),
    );
  }

  factory ChatEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatEntity(
      id: serializer.fromJson<String>(json['id']),
      receiverId: serializer.fromJson<String>(json['receiverId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      about: serializer.fromJson<String>(json['about']),
      avatarUrl: serializer.fromJson<String>(json['avatarUrl']),
      lastMessage: serializer.fromJson<String>(json['lastMessage']),
      lastMessageType: serializer.fromJson<String>(json['lastMessageType']),
      lastMessageStatus: serializer.fromJson<MessageStatus>(
        json['lastMessageStatus'],
      ),
      lastMessageFileUrl: serializer.fromJson<String?>(
        json['lastMessageFileUrl'],
      ),
      time: serializer.fromJson<DateTime>(json['time']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      isOnline: serializer.fromJson<bool>(json['isOnline']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'receiverId': serializer.toJson<String>(receiverId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'about': serializer.toJson<String>(about),
      'avatarUrl': serializer.toJson<String>(avatarUrl),
      'lastMessage': serializer.toJson<String>(lastMessage),
      'lastMessageType': serializer.toJson<String>(lastMessageType),
      'lastMessageStatus': serializer.toJson<MessageStatus>(lastMessageStatus),
      'lastMessageFileUrl': serializer.toJson<String?>(lastMessageFileUrl),
      'time': serializer.toJson<DateTime>(time),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'isOnline': serializer.toJson<bool>(isOnline),
    };
  }

  ChatEntity copyWith({
    String? id,
    String? receiverId,
    String? name,
    String? phone,
    String? about,
    String? avatarUrl,
    String? lastMessage,
    String? lastMessageType,
    MessageStatus? lastMessageStatus,
    Value<String?> lastMessageFileUrl = const Value.absent(),
    DateTime? time,
    int? unreadCount,
    bool? isOnline,
  }) => ChatEntity(
    id: id ?? this.id,
    receiverId: receiverId ?? this.receiverId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    about: about ?? this.about,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageType: lastMessageType ?? this.lastMessageType,
    lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
    lastMessageFileUrl: lastMessageFileUrl.present
        ? lastMessageFileUrl.value
        : this.lastMessageFileUrl,
    time: time ?? this.time,
    unreadCount: unreadCount ?? this.unreadCount,
    isOnline: isOnline ?? this.isOnline,
  );
  ChatEntity copyWithCompanion(ChatsTableCompanion data) {
    return ChatEntity(
      id: data.id.present ? data.id.value : this.id,
      receiverId: data.receiverId.present
          ? data.receiverId.value
          : this.receiverId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      about: data.about.present ? data.about.value : this.about,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      lastMessage: data.lastMessage.present
          ? data.lastMessage.value
          : this.lastMessage,
      lastMessageType: data.lastMessageType.present
          ? data.lastMessageType.value
          : this.lastMessageType,
      lastMessageStatus: data.lastMessageStatus.present
          ? data.lastMessageStatus.value
          : this.lastMessageStatus,
      lastMessageFileUrl: data.lastMessageFileUrl.present
          ? data.lastMessageFileUrl.value
          : this.lastMessageFileUrl,
      time: data.time.present ? data.time.value : this.time,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      isOnline: data.isOnline.present ? data.isOnline.value : this.isOnline,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatEntity(')
          ..write('id: $id, ')
          ..write('receiverId: $receiverId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('about: $about, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('lastMessageStatus: $lastMessageStatus, ')
          ..write('lastMessageFileUrl: $lastMessageFileUrl, ')
          ..write('time: $time, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isOnline: $isOnline')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    receiverId,
    name,
    phone,
    about,
    avatarUrl,
    lastMessage,
    lastMessageType,
    lastMessageStatus,
    lastMessageFileUrl,
    time,
    unreadCount,
    isOnline,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatEntity &&
          other.id == this.id &&
          other.receiverId == this.receiverId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.about == this.about &&
          other.avatarUrl == this.avatarUrl &&
          other.lastMessage == this.lastMessage &&
          other.lastMessageType == this.lastMessageType &&
          other.lastMessageStatus == this.lastMessageStatus &&
          other.lastMessageFileUrl == this.lastMessageFileUrl &&
          other.time == this.time &&
          other.unreadCount == this.unreadCount &&
          other.isOnline == this.isOnline);
}

class ChatsTableCompanion extends UpdateCompanion<ChatEntity> {
  final Value<String> id;
  final Value<String> receiverId;
  final Value<String> name;
  final Value<String> phone;
  final Value<String> about;
  final Value<String> avatarUrl;
  final Value<String> lastMessage;
  final Value<String> lastMessageType;
  final Value<MessageStatus> lastMessageStatus;
  final Value<String?> lastMessageFileUrl;
  final Value<DateTime> time;
  final Value<int> unreadCount;
  final Value<bool> isOnline;
  final Value<int> rowid;
  const ChatsTableCompanion({
    this.id = const Value.absent(),
    this.receiverId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.about = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.lastMessageStatus = const Value.absent(),
    this.lastMessageFileUrl = const Value.absent(),
    this.time = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatsTableCompanion.insert({
    required String id,
    required String receiverId,
    required String name,
    required String phone,
    required String about,
    required String avatarUrl,
    required String lastMessage,
    required String lastMessageType,
    required MessageStatus lastMessageStatus,
    this.lastMessageFileUrl = const Value.absent(),
    required DateTime time,
    this.unreadCount = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       receiverId = Value(receiverId),
       name = Value(name),
       phone = Value(phone),
       about = Value(about),
       avatarUrl = Value(avatarUrl),
       lastMessage = Value(lastMessage),
       lastMessageType = Value(lastMessageType),
       lastMessageStatus = Value(lastMessageStatus),
       time = Value(time);
  static Insertable<ChatEntity> custom({
    Expression<String>? id,
    Expression<String>? receiverId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? about,
    Expression<String>? avatarUrl,
    Expression<String>? lastMessage,
    Expression<String>? lastMessageType,
    Expression<String>? lastMessageStatus,
    Expression<String>? lastMessageFileUrl,
    Expression<DateTime>? time,
    Expression<int>? unreadCount,
    Expression<bool>? isOnline,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (receiverId != null) 'receiver_id': receiverId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (about != null) 'about': about,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastMessageType != null) 'last_message_type': lastMessageType,
      if (lastMessageStatus != null) 'last_message_status': lastMessageStatus,
      if (lastMessageFileUrl != null)
        'last_message_file_url': lastMessageFileUrl,
      if (time != null) 'time': time,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (isOnline != null) 'is_online': isOnline,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? receiverId,
    Value<String>? name,
    Value<String>? phone,
    Value<String>? about,
    Value<String>? avatarUrl,
    Value<String>? lastMessage,
    Value<String>? lastMessageType,
    Value<MessageStatus>? lastMessageStatus,
    Value<String?>? lastMessageFileUrl,
    Value<DateTime>? time,
    Value<int>? unreadCount,
    Value<bool>? isOnline,
    Value<int>? rowid,
  }) {
    return ChatsTableCompanion(
      id: id ?? this.id,
      receiverId: receiverId ?? this.receiverId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      about: about ?? this.about,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      lastMessageFileUrl: lastMessageFileUrl ?? this.lastMessageFileUrl,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (receiverId.present) {
      map['receiver_id'] = Variable<String>(receiverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (about.present) {
      map['about'] = Variable<String>(about.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (lastMessageType.present) {
      map['last_message_type'] = Variable<String>(lastMessageType.value);
    }
    if (lastMessageStatus.present) {
      map['last_message_status'] = Variable<String>(
        $ChatsTableTable.$converterlastMessageStatus.toSql(
          lastMessageStatus.value,
        ),
      );
    }
    if (lastMessageFileUrl.present) {
      map['last_message_file_url'] = Variable<String>(lastMessageFileUrl.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (isOnline.present) {
      map['is_online'] = Variable<bool>(isOnline.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatsTableCompanion(')
          ..write('id: $id, ')
          ..write('receiverId: $receiverId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('about: $about, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('lastMessageStatus: $lastMessageStatus, ')
          ..write('lastMessageFileUrl: $lastMessageFileUrl, ')
          ..write('time: $time, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isOnline: $isOnline, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChatsTableTable chatsTable = $ChatsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [chatsTable];
}

typedef $$ChatsTableTableCreateCompanionBuilder =
    ChatsTableCompanion Function({
      required String id,
      required String receiverId,
      required String name,
      required String phone,
      required String about,
      required String avatarUrl,
      required String lastMessage,
      required String lastMessageType,
      required MessageStatus lastMessageStatus,
      Value<String?> lastMessageFileUrl,
      required DateTime time,
      Value<int> unreadCount,
      Value<bool> isOnline,
      Value<int> rowid,
    });
typedef $$ChatsTableTableUpdateCompanionBuilder =
    ChatsTableCompanion Function({
      Value<String> id,
      Value<String> receiverId,
      Value<String> name,
      Value<String> phone,
      Value<String> about,
      Value<String> avatarUrl,
      Value<String> lastMessage,
      Value<String> lastMessageType,
      Value<MessageStatus> lastMessageStatus,
      Value<String?> lastMessageFileUrl,
      Value<DateTime> time,
      Value<int> unreadCount,
      Value<bool> isOnline,
      Value<int> rowid,
    });

class $$ChatsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChatsTableTable> {
  $$ChatsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get about => $composableBuilder(
    column: $table.about,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageStatus, MessageStatus, String>
  get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get lastMessageFileUrl => $composableBuilder(
    column: $table.lastMessageFileUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOnline => $composableBuilder(
    column: $table.isOnline,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatsTableTable> {
  $$ChatsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get about => $composableBuilder(
    column: $table.about,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageFileUrl => $composableBuilder(
    column: $table.lastMessageFileUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOnline => $composableBuilder(
    column: $table.isOnline,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatsTableTable> {
  $$ChatsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get about =>
      $composableBuilder(column: $table.about, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MessageStatus, String>
  get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageFileUrl => $composableBuilder(
    column: $table.lastMessageFileUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isOnline =>
      $composableBuilder(column: $table.isOnline, builder: (column) => column);
}

class $$ChatsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatsTableTable,
          ChatEntity,
          $$ChatsTableTableFilterComposer,
          $$ChatsTableTableOrderingComposer,
          $$ChatsTableTableAnnotationComposer,
          $$ChatsTableTableCreateCompanionBuilder,
          $$ChatsTableTableUpdateCompanionBuilder,
          (
            ChatEntity,
            BaseReferences<_$AppDatabase, $ChatsTableTable, ChatEntity>,
          ),
          ChatEntity,
          PrefetchHooks Function()
        > {
  $$ChatsTableTableTableManager(_$AppDatabase db, $ChatsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> receiverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> about = const Value.absent(),
                Value<String> avatarUrl = const Value.absent(),
                Value<String> lastMessage = const Value.absent(),
                Value<String> lastMessageType = const Value.absent(),
                Value<MessageStatus> lastMessageStatus = const Value.absent(),
                Value<String?> lastMessageFileUrl = const Value.absent(),
                Value<DateTime> time = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> isOnline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatsTableCompanion(
                id: id,
                receiverId: receiverId,
                name: name,
                phone: phone,
                about: about,
                avatarUrl: avatarUrl,
                lastMessage: lastMessage,
                lastMessageType: lastMessageType,
                lastMessageStatus: lastMessageStatus,
                lastMessageFileUrl: lastMessageFileUrl,
                time: time,
                unreadCount: unreadCount,
                isOnline: isOnline,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String receiverId,
                required String name,
                required String phone,
                required String about,
                required String avatarUrl,
                required String lastMessage,
                required String lastMessageType,
                required MessageStatus lastMessageStatus,
                Value<String?> lastMessageFileUrl = const Value.absent(),
                required DateTime time,
                Value<int> unreadCount = const Value.absent(),
                Value<bool> isOnline = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatsTableCompanion.insert(
                id: id,
                receiverId: receiverId,
                name: name,
                phone: phone,
                about: about,
                avatarUrl: avatarUrl,
                lastMessage: lastMessage,
                lastMessageType: lastMessageType,
                lastMessageStatus: lastMessageStatus,
                lastMessageFileUrl: lastMessageFileUrl,
                time: time,
                unreadCount: unreadCount,
                isOnline: isOnline,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatsTableTable,
      ChatEntity,
      $$ChatsTableTableFilterComposer,
      $$ChatsTableTableOrderingComposer,
      $$ChatsTableTableAnnotationComposer,
      $$ChatsTableTableCreateCompanionBuilder,
      $$ChatsTableTableUpdateCompanionBuilder,
      (ChatEntity, BaseReferences<_$AppDatabase, $ChatsTableTable, ChatEntity>),
      ChatEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatsTableTableTableManager get chatsTable =>
      $$ChatsTableTableTableManager(_db, _db.chatsTable);
}
