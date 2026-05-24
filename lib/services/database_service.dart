import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import '../models/chat.dart';
import '../models/message.dart';

part 'database_service.g.dart';

class MessageStatusConverter extends TypeConverter<MessageStatus, String> {
  const MessageStatusConverter();

  @override
  MessageStatus fromSql(String fromDb) {
    return MessageStatus.fromString(fromDb);
  }

  @override
  String toSql(MessageStatus value) {
    return value.name;
  }
}

@DataClassName('ChatEntity')
class ChatsTable extends Table {
  TextColumn get id => text()();
  TextColumn get receiverId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get about => text()();
  TextColumn get avatarUrl => text()();
  TextColumn get lastMessage => text()();
  TextColumn get lastMessageType => text()();
  TextColumn get lastMessageStatus =>
      text().map(const MessageStatusConverter())();
  TextColumn get lastMessageFileUrl => text().nullable()();
  DateTimeColumn get time => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MessageEntity')
class MessagesTable extends Table {
  TextColumn get messageId => text()();
  TextColumn get clientUuid => text()();
  TextColumn get chatId => text()();
  TextColumn get senderId => text()();
  TextColumn get receiverId => text().nullable()();
  TextColumn get encryptedText => text().named('text')();
  TextColumn get messageType => text()();
  TextColumn get status => text().map(const MessageStatusConverter())();
  TextColumn get fileUrl => text().nullable()();
  TextColumn get localFilePath => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get fileName => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get fileType => text().nullable()();
  RealColumn get duration => real().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get replyToMessageId => text().nullable()();
  TextColumn get replyToText => text().nullable()();
  TextColumn get replyToType => text().nullable()();
  TextColumn get replyToFileUrl => text().nullable()();
  TextColumn get replyToThumbnailUrl => text().nullable()();
  TextColumn get replyToFileName => text().nullable()();
  TextColumn get reactionsJson => text().nullable()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeletedForMe =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isForwarded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {messageId};
}

@DriftDatabase(tables: [ChatsTable, MessagesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(messagesTable);
      }
    },
  );

  // Fetch all chats ordered by time descending (newest activity first)
  Future<List<ChatEntity>> getLocalChats() {
    return (select(chatsTable)..orderBy([
          (t) => OrderingTerm(expression: t.time, mode: OrderingMode.desc),
        ]))
        .get();
  }

  // Save multiple chats (upsert)
  Future<void> saveChats(List<ChatEntity> entities) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(chatsTable, entities);
    });
  }

  // Update/insert single chat
  Future<void> updateLocalChat(ChatEntity entity) async {
    await into(chatsTable).insertOnConflictUpdate(entity);
  }

  Stream<List<Message>> watchMessages(String chatId) {
    return (select(messagesTable)
          ..where((t) => t.chatId.equals(chatId))
          ..where((t) => t.isDeletedForMe.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map(
          (entities) => entities.map((entity) => entity.toDomain()).toList(),
        );
  }

  Future<List<Message>> getCachedMessages(String chatId) async {
    final entities =
        await (select(messagesTable)
              ..where((t) => t.chatId.equals(chatId))
              ..where((t) => t.isDeletedForMe.equals(false))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return entities.map((entity) => entity.toDomain()).toList();
  }

  Future<void> upsertMessages(String chatId, List<Message> messages) async {
    await transaction(() async {
      for (final message in messages) {
        await _upsertMessage(message.copyWith(chatId: chatId));
      }
    });
  }

  Future<void> upsertMessage(Message message) async {
    await transaction(() async {
      await _upsertMessage(message);
    });
  }

  Future<void> _upsertMessage(Message message) async {
    if (message.clientUuid.isNotEmpty && message.clientUuid != message.id) {
      await (delete(messagesTable)..where(
            (t) =>
                t.clientUuid.equals(message.clientUuid) &
                t.messageId.equals(message.id).not(),
          ))
          .go();
    }
    await into(messagesTable).insertOnConflictUpdate(message.toEntity());
  }

  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status,
  ) async {
    await (update(
      messagesTable,
    )..where((t) => t.messageId.equals(messageId))).write(
      MessagesTableCompanion(
        status: Value(status),
        deliveredAt:
            status == MessageStatus.delivered || status == MessageStatus.read
            ? Value(DateTime.now())
            : const Value.absent(),
        readAt: status == MessageStatus.read
            ? Value(DateTime.now())
            : const Value.absent(),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markMessagesRead(String chatId) async {
    await (update(messagesTable)..where((t) => t.chatId.equals(chatId))).write(
      MessagesTableCompanion(
        status: const Value(MessageStatus.read),
        readAt: Value(DateTime.now()),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteMessagesForChat(String chatId) async {
    await (delete(messagesTable)..where((t) => t.chatId.equals(chatId))).go();
  }

  Future<void> clearMessages() async {
    await delete(messagesTable).go();
  }

  // Purge all cache data (e.g. on logout)
  Future<void> clearDatabase() async {
    await clearMessages();
    await delete(chatsTable).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_cache.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(file);
  });
}

extension ChatEntityMapper on ChatEntity {
  Chat toDomain() {
    return Chat(
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
    );
  }
}

extension ChatMapper on Chat {
  ChatEntity toEntity() {
    return ChatEntity(
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
    );
  }
}

extension MessageEntityMapper on MessageEntity {
  Message toDomain() {
    return Message(
      id: messageId,
      clientUuid: clientUuid,
      text: encryptedText,
      senderId: senderId,
      time: createdAt,
      isMe: isMe,
      chatId: chatId,
      fileUrl: fileUrl,
      type: messageType,
      deliveryState: status,
      replyToId: replyToMessageId,
      replyToText: replyToText,
      replyToType: replyToType,
      replyToFileUrl: replyToFileUrl,
      replyToThumbnailUrl: replyToThumbnailUrl,
      replyToFileName: replyToFileName,
      deliveredAt: deliveredAt,
      readAt: readAt,
      editedAt: updatedAt,
      isDeletedForEveryone: isDeleted,
      isDeletedForMe: isDeletedForMe,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      duration: duration,
      thumbnailUrl: thumbnailUrl,
      width: width,
      height: height,
      reactions: _decodeReactions(reactionsJson),
      isForwarded: isForwarded,
    );
  }
}

extension MessageMapper on Message {
  MessageEntity toEntity({String? receiverId, String? localFilePath}) {
    final now = DateTime.now();
    return MessageEntity(
      messageId: id,
      clientUuid: clientUuid,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      encryptedText: text,
      messageType: type,
      status: deliveryState,
      fileUrl: fileUrl,
      localFilePath: localFilePath,
      thumbnailUrl: thumbnailUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      duration: duration,
      width: width,
      height: height,
      replyToMessageId: replyToId,
      replyToText: replyToText,
      replyToType: replyToType,
      replyToFileUrl: replyToFileUrl,
      replyToThumbnailUrl: replyToThumbnailUrl,
      replyToFileName: replyToFileName,
      reactionsJson: _encodeReactions(reactions),
      isMe: isMe,
      isEdited: editedAt != null,
      isDeleted: isDeletedForEveryone,
      isDeletedForMe: isDeletedForMe,
      isForwarded: isForwarded,
      createdAt: time,
      updatedAt: editedAt,
      deliveredAt: deliveredAt,
      readAt: readAt,
      syncedAt: now,
    );
  }
}

String? _encodeReactions(Map<String, List<String>> reactions) {
  if (reactions.isEmpty) return null;
  return jsonEncode(reactions);
}

Map<String, List<String>> _decodeReactions(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const {};
  final decoded = jsonDecode(encoded);
  if (decoded is! Map) return const {};
  return decoded.map(
    (key, value) => MapEntry(
      key.toString(),
      value is List
          ? value.map((item) => item.toString()).toList()
          : <String>[],
    ),
  );
}
