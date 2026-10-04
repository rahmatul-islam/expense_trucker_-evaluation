import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'expense_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // USERS TABLE
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT,
            password TEXT
          )
        ''');

        // EXPENSE TABLE
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            amount INTEGER,
            type TEXT
          )
        ''');
      },
    );
  }

  // ---------------- SIGNUP ----------------
  Future<int> signup(String email, String password) async {
    final database = await db;

    return await database.insert('users', {
      'email': email,
      'password': password,
    });
  }

  // ---------------- LOGIN ----------------
  Future<bool> login(String email, String password) async {
    final database = await db;

    final result = await database.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    return result.isNotEmpty;
  }

  // ---------------- ADD EXPENSE ----------------
  Future<int> addExpense(String title, int amount, String type) async {
    final database = await db;

    return await database.insert('expenses', {
      'title': title,
      'amount': amount,
      'type': type,
    });
  }

  // ---------------- GET EXPENSES ----------------
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final database = await db;

    return await database.query(
      'expenses',
      orderBy: 'id DESC',
    );
  }

  // ---------------- DELETE (optional) ----------------
  Future<int> deleteExpense(int id) async {
    final database = await db;

    return await database.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}