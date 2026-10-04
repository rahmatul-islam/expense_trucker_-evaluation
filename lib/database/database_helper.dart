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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT,
            password TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            amount INTEGER,
            type TEXT,
            category TEXT,
            date TEXT,
            account TEXT,
            is_recurring INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE budgets(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT,
            limit_amount INTEGER,
            month TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE expenses ADD COLUMN category TEXT");
          await db.execute("ALTER TABLE expenses ADD COLUMN date TEXT");
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE expenses ADD COLUMN account TEXT DEFAULT 'Cash'",
          );
          await db.execute(
            "ALTER TABLE expenses ADD COLUMN is_recurring INTEGER DEFAULT 0",
          );
          await db.execute('''
            CREATE TABLE budgets(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category TEXT,
              limit_amount INTEGER,
              month TEXT
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE settings(
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        }
      },
    );
  }

  // ---------------- AUTH ----------------
  Future<int> signup(String email, String password) async {
    final database = await db;
    return await database.insert('users', {
      'email': email,
      'password': password,
    });
  }

  Future<bool> login(String email, String password) async {
    final database = await db;
    final result = await database.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return result.isNotEmpty;
  }

  // ---------------- EXPENSES ----------------
  Future<int> addExpense(
      String title,
      int amount,
      String type,
      String category,
      String date, {
        String account = 'Cash',
        int isRecurring = 0,
      }) async {
    final database = await db;
    return await database.insert('expenses', {
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date,
      'account': account,
      'is_recurring': isRecurring,
    });
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final database = await db;
    return await database.query('expenses', orderBy: 'date DESC, id DESC');
  }

  Future<int> updateExpense(
      int id,
      String title,
      int amount,
      String type,
      String category,
      String date, {
        String account = 'Cash',
        int isRecurring = 0,
      }) async {
    final database = await db;
    return await database.update(
      'expenses',
      {
        'title': title,
        'amount': amount,
        'type': type,
        'category': category,
        'date': date,
        'account': account,
        'is_recurring': isRecurring,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final database = await db;
    return await database.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- BUDGETS ----------------
  Future<int> setBudget(String category, int limit, String month) async {
    final database = await db;
    // Check if budget exists for this category and month
    final existing = await database.query(
      'budgets',
      where: 'category = ? AND month = ?',
      whereArgs: [category, month],
    );
    if (existing.isNotEmpty) {
      return await database.update(
        'budgets',
        {'limit_amount': limit},
        where: 'id = ?',
        whereArgs: [existing[0]['id']],
      );
    }
    return await database.insert('budgets', {
      'category': category,
      'limit_amount': limit,
      'month': month,
    });
  }

  Future<List<Map<String, dynamic>>> getBudgets(String month) async {
    final database = await db;
    return await database.query(
      'budgets',
      where: 'month = ?',
      whereArgs: [month],
    );
  }

  // ---------------- STATS ----------------
  Future<List<Map<String, dynamic>>> getCategoryStats(String type) async {
    final database = await db;
    return await database.rawQuery(
      '''
      SELECT category, SUM(amount) as total 
      FROM expenses 
      WHERE type = ? 
      GROUP BY category
    ''',
      [type],
    );
  }

  Future<List<Map<String, dynamic>>> getDailyStats(
      String type,
      int days,
      ) async {
    final database = await db;
    final dateLimit = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    return await database.rawQuery(
      '''
      SELECT date(date) as day, SUM(amount) as total 
      FROM expenses 
      WHERE type = ? AND date >= ?
      GROUP BY day
      ORDER BY day ASC
    ''',
      [type, dateLimit],
    );
  }

  Future<List<Map<String, dynamic>>> getAccountBalances() async {
    final database = await db;
    return await database.rawQuery('''
      SELECT account, 
      SUM(CASE WHEN type = 'Income' THEN amount ELSE -amount END) as balance
      FROM expenses 
      GROUP BY account
    ''');
  }

  // ---------------- SETTINGS ----------------
  Future<String> getSetting(String key, String defaultValue) async {
    final database = await db;
    final result = await database.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return defaultValue;
  }

  Future<int> setSetting(String key, String value) async {
    final database = await db;
    return await database.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------- RESET DATABASE ----------------
  Future<void> resetDatabase() async {
    final database = await db;
    await database.delete('expenses');
    await database.delete('budgets');
  }
}
