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

class $MessagesTableTable extends MessagesTable
    with TableInfo<$MessagesTableTable, MessageEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedTextMeta = const VerificationMeta(
    'encryptedText',
  );
  @override
  late final GeneratedColumn<String> encryptedText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta(
    'messageType',
  );
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MessageStatus>($MessagesTableTable.$converterstatus);
  static const VerificationMeta _fileUrlMeta = const VerificationMeta(
    'fileUrl',
  );
  @override
  late final GeneratedColumn<String> fileUrl = GeneratedColumn<String>(
    'file_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localFilePathMeta = const VerificationMeta(
    'localFilePath',
  );
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
    'local_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileTypeMeta = const VerificationMeta(
    'fileType',
  );
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
    'file_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<double> duration = GeneratedColumn<double>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToMessageIdMeta = const VerificationMeta(
    'replyToMessageId',
  );
  @override
  late final GeneratedColumn<String> replyToMessageId = GeneratedColumn<String>(
    'reply_to_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToTextMeta = const VerificationMeta(
    'replyToText',
  );
  @override
  late final GeneratedColumn<String> replyToText = GeneratedColumn<String>(
    'reply_to_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToTypeMeta = const VerificationMeta(
    'replyToType',
  );
  @override
  late final GeneratedColumn<String> replyToType = GeneratedColumn<String>(
    'reply_to_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToFileUrlMeta = const VerificationMeta(
    'replyToFileUrl',
  );
  @override
  late final GeneratedColumn<String> replyToFileUrl = GeneratedColumn<String>(
    'reply_to_file_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToThumbnailUrlMeta =
      const VerificationMeta('replyToThumbnailUrl');
  @override
  late final GeneratedColumn<String> replyToThumbnailUrl =
      GeneratedColumn<String>(
        'reply_to_thumbnail_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _replyToFileNameMeta = const VerificationMeta(
    'replyToFileName',
  );
  @override
  late final GeneratedColumn<String> replyToFileName = GeneratedColumn<String>(
    'reply_to_file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reactionsJsonMeta = const VerificationMeta(
    'reactionsJson',
  );
  @override
  late final GeneratedColumn<String> reactionsJson = GeneratedColumn<String>(
    'reactions_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
    'is_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isEditedMeta = const VerificationMeta(
    'isEdited',
  );
  @override
  late final GeneratedColumn<bool> isEdited = GeneratedColumn<bool>(
    'is_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedForMeMeta = const VerificationMeta(
    'isDeletedForMe',
  );
  @override
  late final GeneratedColumn<bool> isDeletedForMe = GeneratedColumn<bool>(
    'is_deleted_for_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted_for_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isForwardedMeta = const VerificationMeta(
    'isForwarded',
  );
  @override
  late final GeneratedColumn<bool> isForwarded = GeneratedColumn<bool>(
    'is_forwarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_forwarded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deliveredAtMeta = const VerificationMeta(
    'deliveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
    'delivered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    clientUuid,
    chatId,
    senderId,
    receiverId,
    encryptedText,
    messageType,
    status,
    fileUrl,
    localFilePath,
    thumbnailUrl,
    fileName,
    fileSize,
    fileType,
    duration,
    width,
    height,
    replyToMessageId,
    replyToText,
    replyToType,
    replyToFileUrl,
    replyToThumbnailUrl,
    replyToFileName,
    reactionsJson,
    isMe,
    isEdited,
    isDeleted,
    isDeletedForMe,
    isForwarded,
    createdAt,
    updatedAt,
    deliveredAt,
    readAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('receiver_id')) {
      context.handle(
        _receiverIdMeta,
        receiverId.isAcceptableOrUnknown(data['receiver_id']!, _receiverIdMeta),
      );
    }
    if (data.containsKey('text')) {
      context.handle(
        _encryptedTextMeta,
        encryptedText.isAcceptableOrUnknown(data['text']!, _encryptedTextMeta),
      );
    } else if (isInserting) {
      context.missing(_encryptedTextMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
        _messageTypeMeta,
        messageType.isAcceptableOrUnknown(
          data['message_type']!,
          _messageTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('file_url')) {
      context.handle(
        _fileUrlMeta,
        fileUrl.isAcceptableOrUnknown(data['file_url']!, _fileUrlMeta),
      );
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
        _localFilePathMeta,
        localFilePath.isAcceptableOrUnknown(
          data['local_file_path']!,
          _localFilePathMeta,
        ),
      );
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('file_type')) {
      context.handle(
        _fileTypeMeta,
        fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('reply_to_message_id')) {
      context.handle(
        _replyToMessageIdMeta,
        replyToMessageId.isAcceptableOrUnknown(
          data['reply_to_message_id']!,
          _replyToMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_text')) {
      context.handle(
        _replyToTextMeta,
        replyToText.isAcceptableOrUnknown(
          data['reply_to_text']!,
          _replyToTextMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_type')) {
      context.handle(
        _replyToTypeMeta,
        replyToType.isAcceptableOrUnknown(
          data['reply_to_type']!,
          _replyToTypeMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_file_url')) {
      context.handle(
        _replyToFileUrlMeta,
        replyToFileUrl.isAcceptableOrUnknown(
          data['reply_to_file_url']!,
          _replyToFileUrlMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_thumbnail_url')) {
      context.handle(
        _replyToThumbnailUrlMeta,
        replyToThumbnailUrl.isAcceptableOrUnknown(
          data['reply_to_thumbnail_url']!,
          _replyToThumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_file_name')) {
      context.handle(
        _replyToFileNameMeta,
        replyToFileName.isAcceptableOrUnknown(
          data['reply_to_file_name']!,
          _replyToFileNameMeta,
        ),
      );
    }
    if (data.containsKey('reactions_json')) {
      context.handle(
        _reactionsJsonMeta,
        reactionsJson.isAcceptableOrUnknown(
          data['reactions_json']!,
          _reactionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_me')) {
      context.handle(
        _isMeMeta,
        isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta),
      );
    }
    if (data.containsKey('is_edited')) {
      context.handle(
        _isEditedMeta,
        isEdited.isAcceptableOrUnknown(data['is_edited']!, _isEditedMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('is_deleted_for_me')) {
      context.handle(
        _isDeletedForMeMeta,
        isDeletedForMe.isAcceptableOrUnknown(
          data['is_deleted_for_me']!,
          _isDeletedForMeMeta,
        ),
      );
    }
    if (data.containsKey('is_forwarded')) {
      context.handle(
        _isForwardedMeta,
        isForwarded.isAcceptableOrUnknown(
          data['is_forwarded']!,
          _isForwardedMeta,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
        _deliveredAtMeta,
        deliveredAt.isAcceptableOrUnknown(
          data['delivered_at']!,
          _deliveredAtMeta,
        ),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  MessageEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageEntity(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chat_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      receiverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receiver_id'],
      ),
      encryptedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      messageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_type'],
      )!,
      status: $MessagesTableTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      fileUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_url'],
      ),
      localFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_file_path'],
      ),
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      fileType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_type'],
      ),
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      replyToMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_message_id'],
      ),
      replyToText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_text'],
      ),
      replyToType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_type'],
      ),
      replyToFileUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_file_url'],
      ),
      replyToThumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_thumbnail_url'],
      ),
      replyToFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_file_name'],
      ),
      reactionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reactions_json'],
      ),
      isMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_me'],
      )!,
      isEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_edited'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      isDeletedForMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted_for_me'],
      )!,
      isForwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_forwarded'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deliveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}delivered_at'],
      ),
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $MessagesTableTable createAlias(String alias) {
    return $MessagesTableTable(attachedDatabase, alias);
  }

  static TypeConverter<MessageStatus, String> $converterstatus =
      const MessageStatusConverter();
}

class MessageEntity extends DataClass implements Insertable<MessageEntity> {
  final String messageId;
  final String clientUuid;
  final String chatId;
  final String senderId;
  final String? receiverId;
  final String encryptedText;
  final String messageType;
  final MessageStatus status;
  final String? fileUrl;
  final String? localFilePath;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  final double? duration;
  final int? width;
  final int? height;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToType;
  final String? replyToFileUrl;
  final String? replyToThumbnailUrl;
  final String? replyToFileName;
  final String? reactionsJson;
  final bool isMe;
  final bool isEdited;
  final bool isDeleted;
  final bool isDeletedForMe;
  final bool isForwarded;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime syncedAt;
  const MessageEntity({
    required this.messageId,
    required this.clientUuid,
    required this.chatId,
    required this.senderId,
    this.receiverId,
    required this.encryptedText,
    required this.messageType,
    required this.status,
    this.fileUrl,
    this.localFilePath,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.fileType,
    this.duration,
    this.width,
    this.height,
    this.replyToMessageId,
    this.replyToText,
    this.replyToType,
    this.replyToFileUrl,
    this.replyToThumbnailUrl,
    this.replyToFileName,
    this.reactionsJson,
    required this.isMe,
    required this.isEdited,
    required this.isDeleted,
    required this.isDeletedForMe,
    required this.isForwarded,
    required this.createdAt,
    this.updatedAt,
    this.deliveredAt,
    this.readAt,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['client_uuid'] = Variable<String>(clientUuid);
    map['chat_id'] = Variable<String>(chatId);
    map['sender_id'] = Variable<String>(senderId);
    if (!nullToAbsent || receiverId != null) {
      map['receiver_id'] = Variable<String>(receiverId);
    }
    map['text'] = Variable<String>(encryptedText);
    map['message_type'] = Variable<String>(messageType);
    {
      map['status'] = Variable<String>(
        $MessagesTableTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || fileUrl != null) {
      map['file_url'] = Variable<String>(fileUrl);
    }
    if (!nullToAbsent || localFilePath != null) {
      map['local_file_path'] = Variable<String>(localFilePath);
    }
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || fileType != null) {
      map['file_type'] = Variable<String>(fileType);
    }
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<double>(duration);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || replyToMessageId != null) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId);
    }
    if (!nullToAbsent || replyToText != null) {
      map['reply_to_text'] = Variable<String>(replyToText);
    }
    if (!nullToAbsent || replyToType != null) {
      map['reply_to_type'] = Variable<String>(replyToType);
    }
    if (!nullToAbsent || replyToFileUrl != null) {
      map['reply_to_file_url'] = Variable<String>(replyToFileUrl);
    }
    if (!nullToAbsent || replyToThumbnailUrl != null) {
      map['reply_to_thumbnail_url'] = Variable<String>(replyToThumbnailUrl);
    }
    if (!nullToAbsent || replyToFileName != null) {
      map['reply_to_file_name'] = Variable<String>(replyToFileName);
    }
    if (!nullToAbsent || reactionsJson != null) {
      map['reactions_json'] = Variable<String>(reactionsJson);
    }
    map['is_me'] = Variable<bool>(isMe);
    map['is_edited'] = Variable<bool>(isEdited);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['is_deleted_for_me'] = Variable<bool>(isDeletedForMe);
    map['is_forwarded'] = Variable<bool>(isForwarded);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  MessagesTableCompanion toCompanion(bool nullToAbsent) {
    return MessagesTableCompanion(
      messageId: Value(messageId),
      clientUuid: Value(clientUuid),
      chatId: Value(chatId),
      senderId: Value(senderId),
      receiverId: receiverId == null && nullToAbsent
          ? const Value.absent()
          : Value(receiverId),
      encryptedText: Value(encryptedText),
      messageType: Value(messageType),
      status: Value(status),
      fileUrl: fileUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(fileUrl),
      localFilePath: localFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localFilePath),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      fileType: fileType == null && nullToAbsent
          ? const Value.absent()
          : Value(fileType),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      replyToMessageId: replyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToMessageId),
      replyToText: replyToText == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToText),
      replyToType: replyToType == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToType),
      replyToFileUrl: replyToFileUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToFileUrl),
      replyToThumbnailUrl: replyToThumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToThumbnailUrl),
      replyToFileName: replyToFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToFileName),
      reactionsJson: reactionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reactionsJson),
      isMe: Value(isMe),
      isEdited: Value(isEdited),
      isDeleted: Value(isDeleted),
      isDeletedForMe: Value(isDeletedForMe),
      isForwarded: Value(isForwarded),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      syncedAt: Value(syncedAt),
    );
  }

  factory MessageEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageEntity(
      messageId: serializer.fromJson<String>(json['messageId']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      chatId: serializer.fromJson<String>(json['chatId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      receiverId: serializer.fromJson<String?>(json['receiverId']),
      encryptedText: serializer.fromJson<String>(json['encryptedText']),
      messageType: serializer.fromJson<String>(json['messageType']),
      status: serializer.fromJson<MessageStatus>(json['status']),
      fileUrl: serializer.fromJson<String?>(json['fileUrl']),
      localFilePath: serializer.fromJson<String?>(json['localFilePath']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      fileType: serializer.fromJson<String?>(json['fileType']),
      duration: serializer.fromJson<double?>(json['duration']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      replyToMessageId: serializer.fromJson<String?>(json['replyToMessageId']),
      replyToText: serializer.fromJson<String?>(json['replyToText']),
      replyToType: serializer.fromJson<String?>(json['replyToType']),
      replyToFileUrl: serializer.fromJson<String?>(json['replyToFileUrl']),
      replyToThumbnailUrl: serializer.fromJson<String?>(
        json['replyToThumbnailUrl'],
      ),
      replyToFileName: serializer.fromJson<String?>(json['replyToFileName']),
      reactionsJson: serializer.fromJson<String?>(json['reactionsJson']),
      isMe: serializer.fromJson<bool>(json['isMe']),
      isEdited: serializer.fromJson<bool>(json['isEdited']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      isDeletedForMe: serializer.fromJson<bool>(json['isDeletedForMe']),
      isForwarded: serializer.fromJson<bool>(json['isForwarded']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'chatId': serializer.toJson<String>(chatId),
      'senderId': serializer.toJson<String>(senderId),
      'receiverId': serializer.toJson<String?>(receiverId),
      'encryptedText': serializer.toJson<String>(encryptedText),
      'messageType': serializer.toJson<String>(messageType),
      'status': serializer.toJson<MessageStatus>(status),
      'fileUrl': serializer.toJson<String?>(fileUrl),
      'localFilePath': serializer.toJson<String?>(localFilePath),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'fileName': serializer.toJson<String?>(fileName),
      'fileSize': serializer.toJson<int?>(fileSize),
      'fileType': serializer.toJson<String?>(fileType),
      'duration': serializer.toJson<double?>(duration),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'replyToMessageId': serializer.toJson<String?>(replyToMessageId),
      'replyToText': serializer.toJson<String?>(replyToText),
      'replyToType': serializer.toJson<String?>(replyToType),
      'replyToFileUrl': serializer.toJson<String?>(replyToFileUrl),
      'replyToThumbnailUrl': serializer.toJson<String?>(replyToThumbnailUrl),
      'replyToFileName': serializer.toJson<String?>(replyToFileName),
      'reactionsJson': serializer.toJson<String?>(reactionsJson),
      'isMe': serializer.toJson<bool>(isMe),
      'isEdited': serializer.toJson<bool>(isEdited),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'isDeletedForMe': serializer.toJson<bool>(isDeletedForMe),
      'isForwarded': serializer.toJson<bool>(isForwarded),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  MessageEntity copyWith({
    String? messageId,
    String? clientUuid,
    String? chatId,
    String? senderId,
    Value<String?> receiverId = const Value.absent(),
    String? encryptedText,
    String? messageType,
    MessageStatus? status,
    Value<String?> fileUrl = const Value.absent(),
    Value<String?> localFilePath = const Value.absent(),
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<String?> fileName = const Value.absent(),
    Value<int?> fileSize = const Value.absent(),
    Value<String?> fileType = const Value.absent(),
    Value<double?> duration = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<String?> replyToMessageId = const Value.absent(),
    Value<String?> replyToText = const Value.absent(),
    Value<String?> replyToType = const Value.absent(),
    Value<String?> replyToFileUrl = const Value.absent(),
    Value<String?> replyToThumbnailUrl = const Value.absent(),
    Value<String?> replyToFileName = const Value.absent(),
    Value<String?> reactionsJson = const Value.absent(),
    bool? isMe,
    bool? isEdited,
    bool? isDeleted,
    bool? isDeletedForMe,
    bool? isForwarded,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deliveredAt = const Value.absent(),
    Value<DateTime?> readAt = const Value.absent(),
    DateTime? syncedAt,
  }) => MessageEntity(
    messageId: messageId ?? this.messageId,
    clientUuid: clientUuid ?? this.clientUuid,
    chatId: chatId ?? this.chatId,
    senderId: senderId ?? this.senderId,
    receiverId: receiverId.present ? receiverId.value : this.receiverId,
    encryptedText: encryptedText ?? this.encryptedText,
    messageType: messageType ?? this.messageType,
    status: status ?? this.status,
    fileUrl: fileUrl.present ? fileUrl.value : this.fileUrl,
    localFilePath: localFilePath.present
        ? localFilePath.value
        : this.localFilePath,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    fileName: fileName.present ? fileName.value : this.fileName,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    fileType: fileType.present ? fileType.value : this.fileType,
    duration: duration.present ? duration.value : this.duration,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    replyToMessageId: replyToMessageId.present
        ? replyToMessageId.value
        : this.replyToMessageId,
    replyToText: replyToText.present ? replyToText.value : this.replyToText,
    replyToType: replyToType.present ? replyToType.value : this.replyToType,
    replyToFileUrl: replyToFileUrl.present
        ? replyToFileUrl.value
        : this.replyToFileUrl,
    replyToThumbnailUrl: replyToThumbnailUrl.present
        ? replyToThumbnailUrl.value
        : this.replyToThumbnailUrl,
    replyToFileName: replyToFileName.present
        ? replyToFileName.value
        : this.replyToFileName,
    reactionsJson: reactionsJson.present
        ? reactionsJson.value
        : this.reactionsJson,
    isMe: isMe ?? this.isMe,
    isEdited: isEdited ?? this.isEdited,
    isDeleted: isDeleted ?? this.isDeleted,
    isDeletedForMe: isDeletedForMe ?? this.isDeletedForMe,
    isForwarded: isForwarded ?? this.isForwarded,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  MessageEntity copyWithCompanion(MessagesTableCompanion data) {
    return MessageEntity(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      receiverId: data.receiverId.present
          ? data.receiverId.value
          : this.receiverId,
      encryptedText: data.encryptedText.present
          ? data.encryptedText.value
          : this.encryptedText,
      messageType: data.messageType.present
          ? data.messageType.value
          : this.messageType,
      status: data.status.present ? data.status.value : this.status,
      fileUrl: data.fileUrl.present ? data.fileUrl.value : this.fileUrl,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      duration: data.duration.present ? data.duration.value : this.duration,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      replyToMessageId: data.replyToMessageId.present
          ? data.replyToMessageId.value
          : this.replyToMessageId,
      replyToText: data.replyToText.present
          ? data.replyToText.value
          : this.replyToText,
      replyToType: data.replyToType.present
          ? data.replyToType.value
          : this.replyToType,
      replyToFileUrl: data.replyToFileUrl.present
          ? data.replyToFileUrl.value
          : this.replyToFileUrl,
      replyToThumbnailUrl: data.replyToThumbnailUrl.present
          ? data.replyToThumbnailUrl.value
          : this.replyToThumbnailUrl,
      replyToFileName: data.replyToFileName.present
          ? data.replyToFileName.value
          : this.replyToFileName,
      reactionsJson: data.reactionsJson.present
          ? data.reactionsJson.value
          : this.reactionsJson,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
      isEdited: data.isEdited.present ? data.isEdited.value : this.isEdited,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      isDeletedForMe: data.isDeletedForMe.present
          ? data.isDeletedForMe.value
          : this.isDeletedForMe,
      isForwarded: data.isForwarded.present
          ? data.isForwarded.value
          : this.isForwarded,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deliveredAt: data.deliveredAt.present
          ? data.deliveredAt.value
          : this.deliveredAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageEntity(')
          ..write('messageId: $messageId, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('chatId: $chatId, ')
          ..write('senderId: $senderId, ')
          ..write('receiverId: $receiverId, ')
          ..write('encryptedText: $encryptedText, ')
          ..write('messageType: $messageType, ')
          ..write('status: $status, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('fileType: $fileType, ')
          ..write('duration: $duration, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('replyToText: $replyToText, ')
          ..write('replyToType: $replyToType, ')
          ..write('replyToFileUrl: $replyToFileUrl, ')
          ..write('replyToThumbnailUrl: $replyToThumbnailUrl, ')
          ..write('replyToFileName: $replyToFileName, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('isMe: $isMe, ')
          ..write('isEdited: $isEdited, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isDeletedForMe: $isDeletedForMe, ')
          ..write('isForwarded: $isForwarded, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    messageId,
    clientUuid,
    chatId,
    senderId,
    receiverId,
    encryptedText,
    messageType,
    status,
    fileUrl,
    localFilePath,
    thumbnailUrl,
    fileName,
    fileSize,
    fileType,
    duration,
    width,
    height,
    replyToMessageId,
    replyToText,
    replyToType,
    replyToFileUrl,
    replyToThumbnailUrl,
    replyToFileName,
    reactionsJson,
    isMe,
    isEdited,
    isDeleted,
    isDeletedForMe,
    isForwarded,
    createdAt,
    updatedAt,
    deliveredAt,
    readAt,
    syncedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageEntity &&
          other.messageId == this.messageId &&
          other.clientUuid == this.clientUuid &&
          other.chatId == this.chatId &&
          other.senderId == this.senderId &&
          other.receiverId == this.receiverId &&
          other.encryptedText == this.encryptedText &&
          other.messageType == this.messageType &&
          other.status == this.status &&
          other.fileUrl == this.fileUrl &&
          other.localFilePath == this.localFilePath &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.fileName == this.fileName &&
          other.fileSize == this.fileSize &&
          other.fileType == this.fileType &&
          other.duration == this.duration &&
          other.width == this.width &&
          other.height == this.height &&
          other.replyToMessageId == this.replyToMessageId &&
          other.replyToText == this.replyToText &&
          other.replyToType == this.replyToType &&
          other.replyToFileUrl == this.replyToFileUrl &&
          other.replyToThumbnailUrl == this.replyToThumbnailUrl &&
          other.replyToFileName == this.replyToFileName &&
          other.reactionsJson == this.reactionsJson &&
          other.isMe == this.isMe &&
          other.isEdited == this.isEdited &&
          other.isDeleted == this.isDeleted &&
          other.isDeletedForMe == this.isDeletedForMe &&
          other.isForwarded == this.isForwarded &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deliveredAt == this.deliveredAt &&
          other.readAt == this.readAt &&
          other.syncedAt == this.syncedAt);
}

class MessagesTableCompanion extends UpdateCompanion<MessageEntity> {
  final Value<String> messageId;
  final Value<String> clientUuid;
  final Value<String> chatId;
  final Value<String> senderId;
  final Value<String?> receiverId;
  final Value<String> encryptedText;
  final Value<String> messageType;
  final Value<MessageStatus> status;
  final Value<String?> fileUrl;
  final Value<String?> localFilePath;
  final Value<String?> thumbnailUrl;
  final Value<String?> fileName;
  final Value<int?> fileSize;
  final Value<String?> fileType;
  final Value<double?> duration;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String?> replyToMessageId;
  final Value<String?> replyToText;
  final Value<String?> replyToType;
  final Value<String?> replyToFileUrl;
  final Value<String?> replyToThumbnailUrl;
  final Value<String?> replyToFileName;
  final Value<String?> reactionsJson;
  final Value<bool> isMe;
  final Value<bool> isEdited;
  final Value<bool> isDeleted;
  final Value<bool> isDeletedForMe;
  final Value<bool> isForwarded;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deliveredAt;
  final Value<DateTime?> readAt;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const MessagesTableCompanion({
    this.messageId = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.chatId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.receiverId = const Value.absent(),
    this.encryptedText = const Value.absent(),
    this.messageType = const Value.absent(),
    this.status = const Value.absent(),
    this.fileUrl = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.fileType = const Value.absent(),
    this.duration = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.replyToText = const Value.absent(),
    this.replyToType = const Value.absent(),
    this.replyToFileUrl = const Value.absent(),
    this.replyToThumbnailUrl = const Value.absent(),
    this.replyToFileName = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.isMe = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isDeletedForMe = const Value.absent(),
    this.isForwarded = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesTableCompanion.insert({
    required String messageId,
    required String clientUuid,
    required String chatId,
    required String senderId,
    this.receiverId = const Value.absent(),
    required String encryptedText,
    required String messageType,
    required MessageStatus status,
    this.fileUrl = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.fileType = const Value.absent(),
    this.duration = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.replyToMessageId = const Value.absent(),
    this.replyToText = const Value.absent(),
    this.replyToType = const Value.absent(),
    this.replyToFileUrl = const Value.absent(),
    this.replyToThumbnailUrl = const Value.absent(),
    this.replyToFileName = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.isMe = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isDeletedForMe = const Value.absent(),
    this.isForwarded = const Value.absent(),
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    required DateTime syncedAt,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       clientUuid = Value(clientUuid),
       chatId = Value(chatId),
       senderId = Value(senderId),
       encryptedText = Value(encryptedText),
       messageType = Value(messageType),
       status = Value(status),
       createdAt = Value(createdAt),
       syncedAt = Value(syncedAt);
  static Insertable<MessageEntity> custom({
    Expression<String>? messageId,
    Expression<String>? clientUuid,
    Expression<String>? chatId,
    Expression<String>? senderId,
    Expression<String>? receiverId,
    Expression<String>? encryptedText,
    Expression<String>? messageType,
    Expression<String>? status,
    Expression<String>? fileUrl,
    Expression<String>? localFilePath,
    Expression<String>? thumbnailUrl,
    Expression<String>? fileName,
    Expression<int>? fileSize,
    Expression<String>? fileType,
    Expression<double>? duration,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? replyToMessageId,
    Expression<String>? replyToText,
    Expression<String>? replyToType,
    Expression<String>? replyToFileUrl,
    Expression<String>? replyToThumbnailUrl,
    Expression<String>? replyToFileName,
    Expression<String>? reactionsJson,
    Expression<bool>? isMe,
    Expression<bool>? isEdited,
    Expression<bool>? isDeleted,
    Expression<bool>? isDeletedForMe,
    Expression<bool>? isForwarded,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deliveredAt,
    Expression<DateTime>? readAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (chatId != null) 'chat_id': chatId,
      if (senderId != null) 'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      if (encryptedText != null) 'text': encryptedText,
      if (messageType != null) 'message_type': messageType,
      if (status != null) 'status': status,
      if (fileUrl != null) 'file_url': fileUrl,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (fileType != null) 'file_type': fileType,
      if (duration != null) 'duration': duration,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToType != null) 'reply_to_type': replyToType,
      if (replyToFileUrl != null) 'reply_to_file_url': replyToFileUrl,
      if (replyToThumbnailUrl != null)
        'reply_to_thumbnail_url': replyToThumbnailUrl,
      if (replyToFileName != null) 'reply_to_file_name': replyToFileName,
      if (reactionsJson != null) 'reactions_json': reactionsJson,
      if (isMe != null) 'is_me': isMe,
      if (isEdited != null) 'is_edited': isEdited,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (isDeletedForMe != null) 'is_deleted_for_me': isDeletedForMe,
      if (isForwarded != null) 'is_forwarded': isForwarded,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (readAt != null) 'read_at': readAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesTableCompanion copyWith({
    Value<String>? messageId,
    Value<String>? clientUuid,
    Value<String>? chatId,
    Value<String>? senderId,
    Value<String?>? receiverId,
    Value<String>? encryptedText,
    Value<String>? messageType,
    Value<MessageStatus>? status,
    Value<String?>? fileUrl,
    Value<String?>? localFilePath,
    Value<String?>? thumbnailUrl,
    Value<String?>? fileName,
    Value<int?>? fileSize,
    Value<String?>? fileType,
    Value<double?>? duration,
    Value<int?>? width,
    Value<int?>? height,
    Value<String?>? replyToMessageId,
    Value<String?>? replyToText,
    Value<String?>? replyToType,
    Value<String?>? replyToFileUrl,
    Value<String?>? replyToThumbnailUrl,
    Value<String?>? replyToFileName,
    Value<String?>? reactionsJson,
    Value<bool>? isMe,
    Value<bool>? isEdited,
    Value<bool>? isDeleted,
    Value<bool>? isDeletedForMe,
    Value<bool>? isForwarded,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deliveredAt,
    Value<DateTime?>? readAt,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return MessagesTableCompanion(
      messageId: messageId ?? this.messageId,
      clientUuid: clientUuid ?? this.clientUuid,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      encryptedText: encryptedText ?? this.encryptedText,
      messageType: messageType ?? this.messageType,
      status: status ?? this.status,
      fileUrl: fileUrl ?? this.fileUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToType: replyToType ?? this.replyToType,
      replyToFileUrl: replyToFileUrl ?? this.replyToFileUrl,
      replyToThumbnailUrl: replyToThumbnailUrl ?? this.replyToThumbnailUrl,
      replyToFileName: replyToFileName ?? this.replyToFileName,
      reactionsJson: reactionsJson ?? this.reactionsJson,
      isMe: isMe ?? this.isMe,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      isDeletedForMe: isDeletedForMe ?? this.isDeletedForMe,
      isForwarded: isForwarded ?? this.isForwarded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (receiverId.present) {
      map['receiver_id'] = Variable<String>(receiverId.value);
    }
    if (encryptedText.present) {
      map['text'] = Variable<String>(encryptedText.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MessagesTableTable.$converterstatus.toSql(status.value),
      );
    }
    if (fileUrl.present) {
      map['file_url'] = Variable<String>(fileUrl.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (duration.present) {
      map['duration'] = Variable<double>(duration.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (replyToMessageId.present) {
      map['reply_to_message_id'] = Variable<String>(replyToMessageId.value);
    }
    if (replyToText.present) {
      map['reply_to_text'] = Variable<String>(replyToText.value);
    }
    if (replyToType.present) {
      map['reply_to_type'] = Variable<String>(replyToType.value);
    }
    if (replyToFileUrl.present) {
      map['reply_to_file_url'] = Variable<String>(replyToFileUrl.value);
    }
    if (replyToThumbnailUrl.present) {
      map['reply_to_thumbnail_url'] = Variable<String>(
        replyToThumbnailUrl.value,
      );
    }
    if (replyToFileName.present) {
      map['reply_to_file_name'] = Variable<String>(replyToFileName.value);
    }
    if (reactionsJson.present) {
      map['reactions_json'] = Variable<String>(reactionsJson.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    if (isEdited.present) {
      map['is_edited'] = Variable<bool>(isEdited.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (isDeletedForMe.present) {
      map['is_deleted_for_me'] = Variable<bool>(isDeletedForMe.value);
    }
    if (isForwarded.present) {
      map['is_forwarded'] = Variable<bool>(isForwarded.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesTableCompanion(')
          ..write('messageId: $messageId, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('chatId: $chatId, ')
          ..write('senderId: $senderId, ')
          ..write('receiverId: $receiverId, ')
          ..write('encryptedText: $encryptedText, ')
          ..write('messageType: $messageType, ')
          ..write('status: $status, ')
          ..write('fileUrl: $fileUrl, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('fileName: $fileName, ')
          ..write('fileSize: $fileSize, ')
          ..write('fileType: $fileType, ')
          ..write('duration: $duration, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('replyToMessageId: $replyToMessageId, ')
          ..write('replyToText: $replyToText, ')
          ..write('replyToType: $replyToType, ')
          ..write('replyToFileUrl: $replyToFileUrl, ')
          ..write('replyToThumbnailUrl: $replyToThumbnailUrl, ')
          ..write('replyToFileName: $replyToFileName, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('isMe: $isMe, ')
          ..write('isEdited: $isEdited, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isDeletedForMe: $isDeletedForMe, ')
          ..write('isForwarded: $isForwarded, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChatsTableTable chatsTable = $ChatsTableTable(this);
  late final $MessagesTableTable messagesTable = $MessagesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatsTable,
    messagesTable,
  ];
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
typedef $$MessagesTableTableCreateCompanionBuilder =
    MessagesTableCompanion Function({
      required String messageId,
      required String clientUuid,
      required String chatId,
      required String senderId,
      Value<String?> receiverId,
      required String encryptedText,
      required String messageType,
      required MessageStatus status,
      Value<String?> fileUrl,
      Value<String?> localFilePath,
      Value<String?> thumbnailUrl,
      Value<String?> fileName,
      Value<int?> fileSize,
      Value<String?> fileType,
      Value<double?> duration,
      Value<int?> width,
      Value<int?> height,
      Value<String?> replyToMessageId,
      Value<String?> replyToText,
      Value<String?> replyToType,
      Value<String?> replyToFileUrl,
      Value<String?> replyToThumbnailUrl,
      Value<String?> replyToFileName,
      Value<String?> reactionsJson,
      Value<bool> isMe,
      Value<bool> isEdited,
      Value<bool> isDeleted,
      Value<bool> isDeletedForMe,
      Value<bool> isForwarded,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deliveredAt,
      Value<DateTime?> readAt,
      required DateTime syncedAt,
      Value<int> rowid,
    });
typedef $$MessagesTableTableUpdateCompanionBuilder =
    MessagesTableCompanion Function({
      Value<String> messageId,
      Value<String> clientUuid,
      Value<String> chatId,
      Value<String> senderId,
      Value<String?> receiverId,
      Value<String> encryptedText,
      Value<String> messageType,
      Value<MessageStatus> status,
      Value<String?> fileUrl,
      Value<String?> localFilePath,
      Value<String?> thumbnailUrl,
      Value<String?> fileName,
      Value<int?> fileSize,
      Value<String?> fileType,
      Value<double?> duration,
      Value<int?> width,
      Value<int?> height,
      Value<String?> replyToMessageId,
      Value<String?> replyToText,
      Value<String?> replyToType,
      Value<String?> replyToFileUrl,
      Value<String?> replyToThumbnailUrl,
      Value<String?> replyToFileName,
      Value<String?> reactionsJson,
      Value<bool> isMe,
      Value<bool> isEdited,
      Value<bool> isDeleted,
      Value<bool> isDeletedForMe,
      Value<bool> isForwarded,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deliveredAt,
      Value<DateTime?> readAt,
      Value<DateTime> syncedAt,
      Value<int> rowid,
    });

class $$MessagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedText => $composableBuilder(
    column: $table.encryptedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageStatus, MessageStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get fileUrl => $composableBuilder(
    column: $table.fileUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToText => $composableBuilder(
    column: $table.replyToText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToType => $composableBuilder(
    column: $table.replyToType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToFileUrl => $composableBuilder(
    column: $table.replyToFileUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToThumbnailUrl => $composableBuilder(
    column: $table.replyToThumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToFileName => $composableBuilder(
    column: $table.replyToFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeletedForMe => $composableBuilder(
    column: $table.isDeletedForMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedText => $composableBuilder(
    column: $table.encryptedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileUrl => $composableBuilder(
    column: $table.fileUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileType => $composableBuilder(
    column: $table.fileType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToText => $composableBuilder(
    column: $table.replyToText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToType => $composableBuilder(
    column: $table.replyToType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToFileUrl => $composableBuilder(
    column: $table.replyToFileUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToThumbnailUrl => $composableBuilder(
    column: $table.replyToThumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToFileName => $composableBuilder(
    column: $table.replyToFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeletedForMe => $composableBuilder(
    column: $table.isDeletedForMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get receiverId => $composableBuilder(
    column: $table.receiverId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedText => $composableBuilder(
    column: $table.encryptedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MessageStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get fileUrl =>
      $composableBuilder(column: $table.fileUrl, builder: (column) => column);

  GeneratedColumn<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get fileType =>
      $composableBuilder(column: $table.fileType, builder: (column) => column);

  GeneratedColumn<double> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get replyToMessageId => $composableBuilder(
    column: $table.replyToMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToText => $composableBuilder(
    column: $table.replyToText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToType => $composableBuilder(
    column: $table.replyToType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToFileUrl => $composableBuilder(
    column: $table.replyToFileUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToThumbnailUrl => $composableBuilder(
    column: $table.replyToThumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToFileName => $composableBuilder(
    column: $table.replyToFileName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);

  GeneratedColumn<bool> get isEdited =>
      $composableBuilder(column: $table.isEdited, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get isDeletedForMe => $composableBuilder(
    column: $table.isDeletedForMe,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$MessagesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTableTable,
          MessageEntity,
          $$MessagesTableTableFilterComposer,
          $$MessagesTableTableOrderingComposer,
          $$MessagesTableTableAnnotationComposer,
          $$MessagesTableTableCreateCompanionBuilder,
          $$MessagesTableTableUpdateCompanionBuilder,
          (
            MessageEntity,
            BaseReferences<_$AppDatabase, $MessagesTableTable, MessageEntity>,
          ),
          MessageEntity,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableTableManager(_$AppDatabase db, $MessagesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<String> chatId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String?> receiverId = const Value.absent(),
                Value<String> encryptedText = const Value.absent(),
                Value<String> messageType = const Value.absent(),
                Value<MessageStatus> status = const Value.absent(),
                Value<String?> fileUrl = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String?> fileType = const Value.absent(),
                Value<double?> duration = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> replyToMessageId = const Value.absent(),
                Value<String?> replyToText = const Value.absent(),
                Value<String?> replyToType = const Value.absent(),
                Value<String?> replyToFileUrl = const Value.absent(),
                Value<String?> replyToThumbnailUrl = const Value.absent(),
                Value<String?> replyToFileName = const Value.absent(),
                Value<String?> reactionsJson = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> isDeletedForMe = const Value.absent(),
                Value<bool> isForwarded = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesTableCompanion(
                messageId: messageId,
                clientUuid: clientUuid,
                chatId: chatId,
                senderId: senderId,
                receiverId: receiverId,
                encryptedText: encryptedText,
                messageType: messageType,
                status: status,
                fileUrl: fileUrl,
                localFilePath: localFilePath,
                thumbnailUrl: thumbnailUrl,
                fileName: fileName,
                fileSize: fileSize,
                fileType: fileType,
                duration: duration,
                width: width,
                height: height,
                replyToMessageId: replyToMessageId,
                replyToText: replyToText,
                replyToType: replyToType,
                replyToFileUrl: replyToFileUrl,
                replyToThumbnailUrl: replyToThumbnailUrl,
                replyToFileName: replyToFileName,
                reactionsJson: reactionsJson,
                isMe: isMe,
                isEdited: isEdited,
                isDeleted: isDeleted,
                isDeletedForMe: isDeletedForMe,
                isForwarded: isForwarded,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deliveredAt: deliveredAt,
                readAt: readAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String clientUuid,
                required String chatId,
                required String senderId,
                Value<String?> receiverId = const Value.absent(),
                required String encryptedText,
                required String messageType,
                required MessageStatus status,
                Value<String?> fileUrl = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String?> fileType = const Value.absent(),
                Value<double?> duration = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> replyToMessageId = const Value.absent(),
                Value<String?> replyToText = const Value.absent(),
                Value<String?> replyToType = const Value.absent(),
                Value<String?> replyToFileUrl = const Value.absent(),
                Value<String?> replyToThumbnailUrl = const Value.absent(),
                Value<String?> replyToFileName = const Value.absent(),
                Value<String?> reactionsJson = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<bool> isDeletedForMe = const Value.absent(),
                Value<bool> isForwarded = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                required DateTime syncedAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagesTableCompanion.insert(
                messageId: messageId,
                clientUuid: clientUuid,
                chatId: chatId,
                senderId: senderId,
                receiverId: receiverId,
                encryptedText: encryptedText,
                messageType: messageType,
                status: status,
                fileUrl: fileUrl,
                localFilePath: localFilePath,
                thumbnailUrl: thumbnailUrl,
                fileName: fileName,
                fileSize: fileSize,
                fileType: fileType,
                duration: duration,
                width: width,
                height: height,
                replyToMessageId: replyToMessageId,
                replyToText: replyToText,
                replyToType: replyToType,
                replyToFileUrl: replyToFileUrl,
                replyToThumbnailUrl: replyToThumbnailUrl,
                replyToFileName: replyToFileName,
                reactionsJson: reactionsJson,
                isMe: isMe,
                isEdited: isEdited,
                isDeleted: isDeleted,
                isDeletedForMe: isDeletedForMe,
                isForwarded: isForwarded,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deliveredAt: deliveredAt,
                readAt: readAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTableTable,
      MessageEntity,
      $$MessagesTableTableFilterComposer,
      $$MessagesTableTableOrderingComposer,
      $$MessagesTableTableAnnotationComposer,
      $$MessagesTableTableCreateCompanionBuilder,
      $$MessagesTableTableUpdateCompanionBuilder,
      (
        MessageEntity,
        BaseReferences<_$AppDatabase, $MessagesTableTable, MessageEntity>,
      ),
      MessageEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatsTableTableTableManager get chatsTable =>
      $$ChatsTableTableTableManager(_db, _db.chatsTable);
  $$MessagesTableTableTableManager get messagesTable =>
      $$MessagesTableTableTableManager(_db, _db.messagesTable);
}
