import sqlite3

db_path = r"C:\Users\IKRAM\.gemini\antigravity\scratch\whatsapp_clone\WhatsApp-backend\db.sqlite3"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Show current users first
cursor.execute("SELECT id, phone_number, name, is_verified FROM users_user")
users = cursor.fetchall()
print("Current users:")
for u in users:
    print(u)

# Delete all related data first
cursor.execute("DELETE FROM chat_messagereaction")
cursor.execute("DELETE FROM chat_deletedmessage")
cursor.execute("DELETE FROM chat_message")
cursor.execute("DELETE FROM chat_chat")
cursor.execute("DELETE FROM users_otp")
cursor.execute("DELETE FROM users_user")

conn.commit()
print("\nAll users and related data deleted!")

# Verify
cursor.execute("SELECT COUNT(*) FROM users_user")
print(f"Remaining users: {cursor.fetchone()[0]}")
cursor.execute("SELECT COUNT(*) FROM users_otp")
print(f"Remaining OTPs: {cursor.fetchone()[0]}")

conn.close()
