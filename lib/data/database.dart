import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/compte.dart';
import '../models/categorie.dart';
import '../models/operation.dart';
import '../models/charge.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  factory DatabaseService() => instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'mes_depenses.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ==================== CRÉATION ====================

  Future<void> _onCreate(Database db, int version) async {
    await _creerTables(db);
    await _insererCategoriesParDefaut(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Version 1 → 2 : ajout des tables categories et operations
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          type TEXT NOT NULL,
          icone TEXT NOT NULL,
          couleur TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          compte_id INTEGER NOT NULL,
          categorie_id INTEGER,
          type TEXT NOT NULL,
          montant_centimes INTEGER NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          origine TEXT NOT NULL DEFAULT 'manuelle',
          FOREIGN KEY (compte_id) REFERENCES comptes (id) ON DELETE CASCADE,
          FOREIGN KEY (categorie_id) REFERENCES categories (id) ON DELETE SET NULL
        )
      ''');
      await _insererCategoriesParDefaut(db);
    }

    // Version 2 → 3 : ajout des tables charges et budget_config
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS charges (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          libelle TEXT NOT NULL,
          montant_centimes INTEGER NOT NULL,
          echeance TEXT,
          payee INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budget_config (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          reserve_centimes INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.insert(
        'budget_config',
        {'id': 1, 'reserve_centimes': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Version 3 → 4 : table des notifications déjà traitées (anti-doublons)
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications_traitees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reference TEXT NOT NULL,
          date_traitement TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_notif_ref
        ON notifications_traitees (reference)
      ''');
    }
  }

  Future<void> _creerTables(Database db) async {
    // Table comptes
    await db.execute('''
      CREATE TABLE comptes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        type TEXT NOT NULL,
        solde_depart_centimes INTEGER NOT NULL,
        date_debut TEXT NOT NULL,
        actif INTEGER NOT NULL DEFAULT 1,
        couleur TEXT,
        icone TEXT
      )
    ''');

    // Table categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        type TEXT NOT NULL,
        icone TEXT NOT NULL,
        couleur TEXT NOT NULL
      )
    ''');

    // Table operations
    await db.execute('''
      CREATE TABLE operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        compte_id INTEGER NOT NULL,
        categorie_id INTEGER,
        type TEXT NOT NULL,
        montant_centimes INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        origine TEXT NOT NULL DEFAULT 'manuelle',
        FOREIGN KEY (compte_id) REFERENCES comptes (id) ON DELETE CASCADE,
        FOREIGN KEY (categorie_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Table charges
    await db.execute('''
      CREATE TABLE charges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libelle TEXT NOT NULL,
        montant_centimes INTEGER NOT NULL,
        echeance TEXT,
        payee INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Table budget_config
    await db.execute('''
      CREATE TABLE budget_config (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        reserve_centimes INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Table notifications_traitees (anti-doublons)
    await db.execute('''
      CREATE TABLE notifications_traitees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference TEXT NOT NULL,
        date_traitement TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_notif_ref
      ON notifications_traitees (reference)
    ''');

    // Insérer la ligne unique de config
    await db.insert('budget_config', {'id': 1, 'reserve_centimes': 0});
  }

  Future<void> _insererCategoriesParDefaut(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    if (count != null && count > 0) return;

    for (final cat in Categorie.depensesParDefaut()) {
      await db.insert('categories', cat.toMap());
    }
    for (final cat in Categorie.revenusParDefaut()) {
      await db.insert('categories', cat.toMap());
    }
  }

  // ==================== COMPTES ====================

  Future<int> insertCompte(Compte compte) async {
    final db = await database;
    return await db.insert('comptes', compte.toMap());
  }

  Future<List<Compte>> getComptes({bool actifsSeulement = false}) async {
    final db = await database;
    final result = await db.query(
      'comptes',
      where: actifsSeulement ? 'actif = 1' : null,
      orderBy: 'id ASC',
    );
    return result.map((map) => Compte.fromMap(map)).toList();
  }

  Future<int> updateCompte(Compte compte) async {
    final db = await database;
    return await db.update(
      'comptes',
      compte.toMap(),
      where: 'id = ?',
      whereArgs: [compte.id],
    );
  }

  Future<int> deleteCompte(int id) async {
    final db = await database;
    return await db.delete(
      'comptes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== CATEGORIES ====================

  Future<List<Categorie>> getCategories({String? type}) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: type != null ? 'type = ?' : null,
      whereArgs: type != null ? [type] : null,
      orderBy: 'id ASC',
    );
    return result.map((map) => Categorie.fromMap(map)).toList();
  }

  Future<Categorie?> getCategorie(int id) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Categorie.fromMap(result.first);
  }

  // ==================== OPERATIONS ====================

  Future<int> insertOperation(Operation operation) async {
    final db = await database;
    return await db.insert('operations', operation.toMap());
  }

  Future<List<Operation>> getOperations({
    int? compteId,
    String? type,
    int? limite,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (compteId != null) {
      conditions.add('compte_id = ?');
      args.add(compteId);
    }
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }

    final result = await db.query(
      'operations',
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'date DESC',
      limit: limite,
    );
    return result.map((map) => Operation.fromMap(map)).toList();
  }

  Future<int> updateOperation(Operation operation) async {
    final db = await database;
    return await db.update(
      'operations',
      operation.toMap(),
      where: 'id = ?',
      whereArgs: [operation.id],
    );
  }

  Future<int> deleteOperation(int id) async {
    final db = await database;
    return await db.delete(
      'operations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Récupère les opérations entre 2 dates (incluses)
  Future<List<Operation>> getOperationsEntreDates(
    DateTime debut,
    DateTime fin,
  ) async {
    final db = await database;
    final result = await db.query(
      'operations',
      where: 'date >= ? AND date <= ?',
      whereArgs: [debut.toIso8601String(), fin.toIso8601String()],
      orderBy: 'date ASC',
    );
    return result.map((map) => Operation.fromMap(map)).toList();
  }

  Future<int> getSoldeCompte(int compteId) async {
    final db = await database;

    final compteResult = await db.query(
      'comptes',
      columns: ['solde_depart_centimes'],
      where: 'id = ?',
      whereArgs: [compteId],
      limit: 1,
    );
    if (compteResult.isEmpty) return 0;
    final soldeDepart = compteResult.first['solde_depart_centimes'] as int;

    final revenusResult = await db.rawQuery(
      "SELECT COALESCE(SUM(montant_centimes), 0) as total FROM operations WHERE compte_id = ? AND type = 'revenu'",
      [compteId],
    );
    final depensesResult = await db.rawQuery(
      "SELECT COALESCE(SUM(montant_centimes), 0) as total FROM operations WHERE compte_id = ? AND type = 'depense'",
      [compteId],
    );

    final revenus = revenusResult.first['total'] as int;
    final depenses = depensesResult.first['total'] as int;

    return soldeDepart + revenus - depenses;
  }

  Future<int> getSoldeTotalActif() async {
    final comptes = await getComptes(actifsSeulement: true);
    int total = 0;
    for (final c in comptes) {
      total += await getSoldeCompte(c.id!);
    }
    return total;
  }

  Future<List<Operation>> getDernieresOperations({int limite = 10}) async {
    return getOperations(limite: limite);
  }

  // ==================== CHARGES ====================

  Future<int> insertCharge(Charge charge) async {
    final db = await database;
    return await db.insert('charges', charge.toMap());
  }

  Future<List<Charge>> getCharges({bool nonPayeesSeulement = false}) async {
    final db = await database;
    final result = await db.query(
      'charges',
      where: nonPayeesSeulement ? 'payee = 0' : null,
      orderBy: 'id ASC',
    );
    return result.map((map) => Charge.fromMap(map)).toList();
  }

  Future<int> updateCharge(Charge charge) async {
    final db = await database;
    return await db.update(
      'charges',
      charge.toMap(),
      where: 'id = ?',
      whereArgs: [charge.id],
    );
  }

  Future<int> deleteCharge(int id) async {
    final db = await database;
    return await db.delete(
      'charges',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== BUDGET CONFIG ====================

  Future<int> getReserveCentimes() async {
    final db = await database;
    final result = await db.query(
      'budget_config',
      where: 'id = 1',
      limit: 1,
    );
    if (result.isEmpty) return 0;
    return result.first['reserve_centimes'] as int;
  }

  Future<void> setReserveCentimes(int centimes) async {
    final db = await database;
    await db.update(
      'budget_config',
      {'reserve_centimes': centimes},
      where: 'id = 1',
    );
  }

  // ==================== RESTE À VIVRE ====================

  Future<int> getMontantDisponible() async {
    final totalActif = await getSoldeTotalActif();
    final reserve = await getReserveCentimes();
    final charges = await getCharges(nonPayeesSeulement: true);
    final totalCharges = charges.fold(0, (sum, c) => sum + c.montantCentimes);
    return totalActif - reserve - totalCharges;
  }

  Future<Map<String, int>> getResteAVivre() async {
    final maintenant = DateTime.now();
    final dernierJourDuMois =
        DateTime(maintenant.year, maintenant.month + 1, 0).day;
    final joursRestants = dernierJourDuMois - maintenant.day + 1;

    final montantDisponible = await getMontantDisponible();

    final resteParJour = montantDisponible > 0
        ? (montantDisponible / joursRestants).floor()
        : 0;

    return {
      'montantDisponibleCentimes': montantDisponible,
      'joursRestants': joursRestants,
      'resteParJourCentimes': resteParJour,
    };
  }

  // ==================== TOTAUX DU MOIS ====================

  /// Récupère les totaux du mois courant
  /// Retourne { depensesCentimes, revenusCentimes }
  Future<Map<String, int>> getTotauxMoisCourant() async {
    final db = await database;
    final maintenant = DateTime.now();
    final debutMois = DateTime(maintenant.year, maintenant.month, 1)
        .toIso8601String();
    final finMois = DateTime(
      maintenant.year,
      maintenant.month + 1,
      0,
      23,
      59,
      59,
    ).toIso8601String();

    final depenses = await db.rawQuery(
      "SELECT COALESCE(SUM(montant_centimes), 0) as total FROM operations "
      "WHERE type = 'depense' AND date >= ? AND date <= ?",
      [debutMois, finMois],
    );
    final revenus = await db.rawQuery(
      "SELECT COALESCE(SUM(montant_centimes), 0) as total FROM operations "
      "WHERE type = 'revenu' AND date >= ? AND date <= ?",
      [debutMois, finMois],
    );

    return {
      'depensesCentimes': depenses.first['total'] as int,
      'revenusCentimes': revenus.first['total'] as int,
    };
  }

  // ==================== ANTI-DOUBLONS ====================

  /// Vérifie si une référence a déjà été traitée
  Future<bool> referenceDejaTraitee(String reference) async {
    final db = await database;
    final result = await db.query(
      'notifications_traitees',
      where: 'reference = ?',
      whereArgs: [reference],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Marque une référence comme traitée
  Future<void> marquerReferenceTraitee(String reference) async {
    final db = await database;
    await db.insert('notifications_traitees', {
      'reference': reference,
      'date_traitement': DateTime.now().toIso8601String(),
    });
  }

  /// Trouve une opération similaire récente (anti-doublon Wave)
  Future<bool> operationSimilaireRecente({
    required int compteId,
    required int montantCentimes,
    required String type,
  }) async {
    final db = await database;
    final ilYA5Secondes = DateTime.now()
        .subtract(const Duration(seconds: 5))
        .toIso8601String();
    final result = await db.query(
      'operations',
      where:
          'compte_id = ? AND montant_centimes = ? AND type = ? AND date >= ?',
      whereArgs: [compteId, montantCentimes, type, ilYA5Secondes],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}