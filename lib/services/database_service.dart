import 'dart:io';
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
  TextColumn get lastMessageStatus => text().map(const MessageStatusConverter())();
  TextColumn get lastMessageFileUrl => text().nullable()();
  DateTimeColumn get time => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ChatsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          await m.deleteTable('chats_table');
          await m.createAll();
        },
      );

  // Fetch all chats ordered by time descending (newest activity first)
  Future<List<ChatEntity>> getLocalChats() {
    return (select(chatsTable)
          ..orderBy([(t) => OrderingTerm(expression: t.time, mode: OrderingMode.desc)]))
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

  // Purge all cache data (e.g. on logout)
  Future<void> clearDatabase() async {
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
